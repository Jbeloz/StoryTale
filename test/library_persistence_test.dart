import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/features/library/data/library_repository.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  BookData importedBook({
    String id = 'book-imported-1',
    String title = 'An Imported Book',
    Uint8List? cover,
  }) {
    ChapterData chapter(int number) {
      final chapterId = '$id-chapter-$number';
      final blocks = [
        ChapterTextBlock(
          id: '$chapterId-block-0001',
          text: 'First block $number.',
        ),
        ChapterTextBlock(
          id: '$chapterId-block-0002',
          text: 'Second block $number.',
        ),
      ];
      return ChapterData(
        id: chapterId,
        title: 'Chapter $number',
        originalText: blocks.map((block) => block.text).join('\n\n'),
        sourceBlocks: blocks,
      );
    }

    return BookData(
      id: id,
      title: title,
      author: 'A Local Author',
      description: 'Imported locally for the test.',
      tags: const ['Imported'],
      chapters: [chapter(1), chapter(2)],
      coverBytes: cover,
      sourceFileName: 'imported.epub',
    );
  }

  Future<StoryTaleController> restoredController() async {
    final controller = StoryTaleController();
    await controller.restore();
    return controller;
  }

  test('an imported book and its blocks survive a restart', () async {
    final first = StoryTaleController();
    final demoCount = first.books.length;
    first.addImportedBook(importedBook());
    await pumpEventQueue();

    final second = await restoredController();
    expect(second.books.length, demoCount + 1);

    final book = second.bookById('book-imported-1');
    expect(book, isNotNull);
    expect(book!.title, 'An Imported Book');
    expect(book.author, 'A Local Author');
    expect(book.sourceFileName, 'imported.epub');
    expect(book.chapters, hasLength(2));

    final chapter = book.chapters.first;
    expect(chapter.sourceBlocks, hasLength(2));
    expect(
      chapter.sourceBlocks.first.id,
      'book-imported-1-chapter-1-block-0001',
    );
    // originalText is rebuilt from the blocks instead of being stored twice.
    expect(chapter.originalText, 'First block 1.\n\nSecond block 1.');
  });

  test('reading progress and bookmarks survive a restart', () async {
    final first = StoryTaleController();
    first.addImportedBook(importedBook());
    final chapter = first.currentBook!.chapters.first;
    first.openBook(first.currentBook!, chapter: chapter);
    first.updateReadingProgress(0.42);
    first.toggleBookmark(chapter);
    first.saveReaderSettings(
      ReaderSettingsData(textSize: 24, languageMode: ReaderLanguageMode.dual),
    );
    // Reading writes are debounced, so wait for the timer.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final second = await restoredController();
    final restored = second.bookById('book-imported-1')!;
    expect(restored.chapters.first.progress, closeTo(0.42, 0.0001));
    expect(restored.chapters.first.bookmarked, isTrue);
    expect(restored.progress, greaterThan(0));
    expect(second.currentBookId, 'book-imported-1');
    expect(second.currentChapterId, 'book-imported-1-chapter-1');
    expect(second.readerSettings.textSize, 24);
    expect(second.readerSettings.languageMode, ReaderLanguageMode.dual);
  });

  test('demo book progress survives without storing bundled text', () async {
    final first = StoryTaleController();
    final demo = first.books.first;
    first.openBook(demo, chapter: demo.chapters[1]);
    first.updateReadingProgress(0.75);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final preferences = await SharedPreferences.getInstance();
    // Only reading state is stored for bundled books; no book record is written.
    expect(preferences.getString(LibraryRepository.importedBooksKey), isNull);

    final second = await restoredController();
    expect(second.books.first.chapters[1].progress, closeTo(0.75, 0.0001));
  });

  test('restoring twice never duplicates a book', () async {
    final first = StoryTaleController();
    final demoCount = first.books.length;
    first.addImportedBook(importedBook());
    await pumpEventQueue();

    final second = StoryTaleController();
    await second.restore();
    await second.restore();

    expect(second.books.length, demoCount + 1);
    expect(
      second.books.where((book) => book.id == 'book-imported-1'),
      hasLength(1),
    );
  });

  test('removing an imported book clears the stored record', () async {
    final first = StoryTaleController();
    first.addImportedBook(importedBook());
    await pumpEventQueue();

    first.removeBook(first.bookById('book-imported-1')!);
    await pumpEventQueue();

    final second = await restoredController();
    expect(second.bookById('book-imported-1'), isNull);
  });

  test('an oversized cover is dropped but the book still loads', () async {
    final controller = StoryTaleController();
    controller.addImportedBook(
      importedBook(cover: Uint8List(BookData.maxPersistedCoverBytes + 1024)),
    );
    await pumpEventQueue();

    final restored = await restoredController();
    final book = restored.bookById('book-imported-1');
    expect(book, isNotNull);
    expect(book!.coverBytes, isNull);
    expect(book.chapters, hasLength(2));
  });

  test('a small cover is kept', () async {
    final cover = Uint8List.fromList(List<int>.filled(64, 7));
    final controller = StoryTaleController();
    controller.addImportedBook(importedBook(cover: cover));
    await pumpEventQueue();

    final restored = await restoredController();
    expect(restored.bookById('book-imported-1')!.coverBytes, cover);
  });

  test('corrupt stored data falls back to the demo library', () async {
    SharedPreferences.setMockInitialValues({
      LibraryRepository.importedBooksKey: 'not json at all',
      LibraryRepository.readingStateKey: '{"chapters": 12}',
    });

    final controller = StoryTaleController();
    final demoCount = controller.books.length;
    await controller.restore();

    expect(controller.books.length, demoCount);
    expect(controller.currentBook, isNotNull);
  });

  test('a stored book without chapters is skipped', () async {
    SharedPreferences.setMockInitialValues({
      LibraryRepository.importedBooksKey: jsonEncode([
        {'id': 'broken', 'title': 'No chapters', 'chapters': <dynamic>[]},
      ]),
    });

    final controller = StoryTaleController();
    final demoCount = controller.books.length;
    await controller.restore();

    expect(controller.books.length, demoCount);
    expect(controller.bookById('broken'), isNull);
  });

  test(
    'restore does not overwrite progress the reader already changed',
    () async {
      final first = StoryTaleController();
      first.addImportedBook(importedBook());
      first.updateReadingProgress(0.9);
      await Future<void>.delayed(const Duration(milliseconds: 900));

      // Simulate a slow load arriving after the reader already moved on.
      final second = StoryTaleController();
      final demo = second.books.first;
      second.openBook(demo, chapter: demo.chapters.first);
      second.updateReadingProgress(0.1);
      await second.restore();

      expect(second.currentBookId, demo.id);
      expect(second.books.first.chapters.first.progress, closeTo(0.1, 0.0001));
      // The imported book is still merged in, because adding a book is safe.
      expect(second.bookById('book-imported-1'), isNotNull);
    },
  );
}
