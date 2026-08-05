import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/features/reader/data/translation_service.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  BookData bookWithChapter() {
    final blocks = [
      const ChapterTextBlock(id: 'b1', text: 'First paragraph.'),
      const ChapterTextBlock(id: 'b2', text: 'Second paragraph.'),
    ];
    return BookData(
      id: 'book-crud-1',
      title: 'A Local Book',
      author: 'Someone',
      description: 'For CRUD tests.',
      tags: const [],
      chapters: [
        ChapterData(
          id: 'chapter-crud-1',
          title: 'Chapter 1',
          originalText: blocks.map((block) => block.text).join('\n\n'),
          sourceBlocks: blocks,
        ),
      ],
      sourceFileName: 'crud.epub',
    );
  }

  /// Counts calls so the tests can prove caching really avoids DeepL quota.
  ({TranslationService service, List<int> calls}) fakeTranslator({
    int status = 200,
    String prefix = 'TL',
  }) {
    final calls = <int>[];
    final service = TranslationService(
      endpoint: 'http://127.0.0.1:52828',
      client: MockClient((request) async {
        calls.add(1);
        if (status != 200) {
          return http.Response(
            jsonEncode({'error': 'DeepL returned $status.'}),
            status,
          );
        }
        final texts =
            (jsonDecode(request.body) as Map<String, dynamic>)['texts']
                as List<dynamic>;
        return http.Response(
          jsonEncode({
            'translations': [for (final text in texts) '$prefix:$text'],
          }),
          200,
        );
      }),
    );
    return (service: service, calls: calls);
  }

  test('Create translates once and caches the result', () async {
    final fake = fakeTranslator();
    final controller = StoryTaleController(translationService: fake.service);
    addTearDown(controller.dispose);
    final book = bookWithChapter();
    controller.addImportedBook(book);
    final chapter = book.chapters.first;

    expect(controller.hasTranslation(chapter), isFalse);

    await controller.translateChapter(chapter);

    expect(
      chapter.translatedText,
      'TL:First paragraph.\n\nTL:Second paragraph.',
    );
    expect(controller.hasTranslation(chapter), isTrue);
    expect(controller.translationStatus(chapter), TranslationStatus.idle);
    expect(fake.calls, hasLength(1));

    // Creating again must reuse the cache rather than spend more quota.
    await controller.translateChapter(chapter);
    expect(fake.calls, hasLength(1));
  });

  test('Update re-translates even when a translation is cached', () async {
    final fake = fakeTranslator();
    final controller = StoryTaleController(translationService: fake.service);
    addTearDown(controller.dispose);
    final book = bookWithChapter();
    controller.addImportedBook(book);
    final chapter = book.chapters.first;

    await controller.translateChapter(chapter);
    expect(fake.calls, hasLength(1));

    await controller.retranslateChapter(chapter);

    expect(fake.calls, hasLength(2));
    expect(controller.hasTranslation(chapter), isTrue);
  });

  test('Delete clears the cached translation', () async {
    final fake = fakeTranslator();
    final controller = StoryTaleController(translationService: fake.service);
    addTearDown(controller.dispose);
    final book = bookWithChapter();
    controller.addImportedBook(book);
    final chapter = book.chapters.first;

    await controller.translateChapter(chapter);
    expect(controller.hasTranslation(chapter), isTrue);

    controller.deleteTranslation(chapter);

    expect(chapter.translatedText, isNull);
    expect(controller.hasTranslation(chapter), isFalse);
    expect(controller.translationStatus(chapter), TranslationStatus.idle);
  });

  test(
    'a provider failure is reported and never retried automatically',
    () async {
      final fake = fakeTranslator(status: 456);
      final controller = StoryTaleController(translationService: fake.service);
      addTearDown(controller.dispose);
      final book = bookWithChapter();
      controller.addImportedBook(book);
      final chapter = book.chapters.first;

      await controller.translateChapter(chapter);

      expect(controller.translationStatus(chapter), TranslationStatus.failed);
      expect(controller.translationError(chapter), contains('456'));
      expect(controller.hasTranslation(chapter), isFalse);
      expect(fake.calls, hasLength(1));
    },
  );

  test('a cached translation survives a restart', () async {
    final fake = fakeTranslator();
    final first = StoryTaleController(translationService: fake.service);
    final book = bookWithChapter();
    first.addImportedBook(book);
    await first.translateChapter(book.chapters.first);
    first.flushPendingSaves();
    first.dispose();

    final second = StoryTaleController(translationService: fake.service);
    addTearDown(second.dispose);
    await second.restore();

    final restored = second.books.firstWhere((item) => item.id == book.id);
    expect(
      restored.chapters.first.translatedText,
      'TL:First paragraph.\n\nTL:Second paragraph.',
    );
  });

  test('updateBookDetails edits an imported book and persists it', () async {
    final fake = fakeTranslator();
    final first = StoryTaleController(translationService: fake.service);
    final book = bookWithChapter();
    first.addImportedBook(book);

    final saved = first.updateBookDetails(
      book,
      title: '  A Renamed Book  ',
      author: 'New Author',
      language: 'Filipino',
      description: 'Edited in the library.',
    );

    expect(saved, isTrue);
    expect(book.title, 'A Renamed Book');
    expect(book.author, 'New Author');
    expect(book.language, 'Filipino');
    first.flushPendingSaves();
    first.dispose();

    final second = StoryTaleController(translationService: fake.service);
    addTearDown(second.dispose);
    await second.restore();

    final restored = second.books.firstWhere((item) => item.id == book.id);
    expect(restored.title, 'A Renamed Book');
    expect(restored.author, 'New Author');
  });

  test('updateBookDetails refuses a blank title', () async {
    final fake = fakeTranslator();
    final controller = StoryTaleController(translationService: fake.service);
    addTearDown(controller.dispose);
    final book = bookWithChapter();
    controller.addImportedBook(book);

    final saved = controller.updateBookDetails(book, title: '   ');

    expect(saved, isFalse);
    expect(book.title, 'A Local Book');
  });
}
