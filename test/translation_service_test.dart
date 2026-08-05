import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storytale/src/features/reader/data/translation_service.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

ChapterData chapterWithBlocks(int count) {
  final blocks = [
    for (var index = 0; index < count; index++)
      ChapterTextBlock(id: 'block-$index', text: 'Paragraph $index.'),
  ];
  return ChapterData(
    id: 'chapter-1',
    title: 'Chapter 1',
    originalText: blocks.map((block) => block.text).join('\n\n'),
    sourceBlocks: blocks,
  );
}

void main() {
  test('sends one batch and rejoins the paragraphs', () async {
    final requests = <Map<String, dynamic>>[];
    final service = TranslationService(
      endpoint: 'http://127.0.0.1:52828/',
      client: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        final texts =
            (jsonDecode(request.body) as Map<String, dynamic>)['texts']
                as List<dynamic>;
        return http.Response(
          jsonEncode({
            'translations': [for (final text in texts) 'TL:$text'],
          }),
          200,
        );
      }),
    );

    final result = await service.translateChapter(chapterWithBlocks(3));

    expect(result, 'TL:Paragraph 0.\n\nTL:Paragraph 1.\n\nTL:Paragraph 2.');
    expect(requests, hasLength(1));
    expect(requests.single['targetLang'], 'TL');
    expect(requests.single['texts'], hasLength(3));
  });

  test('splits work into batches DeepL accepts', () async {
    final batchSizes = <int>[];
    final service = TranslationService(
      endpoint: 'http://127.0.0.1:52828',
      client: MockClient((request) async {
        final texts =
            (jsonDecode(request.body) as Map<String, dynamic>)['texts']
                as List<dynamic>;
        batchSizes.add(texts.length);
        return http.Response(
          jsonEncode({
            'translations': [for (final text in texts) 'TL:$text'],
          }),
          200,
        );
      }),
    );

    await service.translateChapter(chapterWithBlocks(120));

    expect(batchSizes, [TranslationService.batchSize, 50, 20]);
    expect(
      batchSizes.every((size) => size <= TranslationService.batchSize),
      isTrue,
    );
  });

  test(
    'surfaces the real provider message instead of a generic failure',
    () async {
      final service = TranslationService(
        endpoint: 'http://127.0.0.1:52828',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'DeepL returned 456. Quota exceeded.'}),
            456,
          ),
        ),
      );

      expect(
        () => service.translateChapter(chapterWithBlocks(1)),
        throwsA(
          isA<TranslationException>().having(
            (error) => error.message,
            'message',
            contains('Quota exceeded'),
          ),
        ),
      );
    },
  );

  test('explains how to start the proxy when it is unreachable', () async {
    final service = TranslationService(
      endpoint: 'http://127.0.0.1:52828',
      client: MockClient((_) async => throw const SocketFailure()),
    );

    expect(
      () => service.translateChapter(chapterWithBlocks(1)),
      throwsA(
        isA<TranslationException>().having(
          (error) => error.message,
          'message',
          contains('run_storytale.ps1'),
        ),
      ),
    );
  });

  test(
    'rejects a reply whose paragraph count does not match the request',
    () async {
      final service = TranslationService(
        endpoint: 'http://127.0.0.1:52828',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'translations': ['only one'],
            }),
            200,
          ),
        ),
      );

      expect(
        () => service.translateChapter(chapterWithBlocks(3)),
        throwsA(isA<TranslationException>()),
      );
    },
  );

  test('falls back to originalText when a book has no source blocks', () async {
    List<dynamic>? sent;
    final service = TranslationService(
      endpoint: 'http://127.0.0.1:52828',
      client: MockClient((request) async {
        sent =
            (jsonDecode(request.body) as Map<String, dynamic>)['texts']
                as List<dynamic>;
        return http.Response(
          jsonEncode({
            'translations': [for (final text in sent!) 'TL:$text'],
          }),
          200,
        );
      }),
    );

    final legacy = ChapterData(
      id: 'legacy',
      title: 'Legacy',
      originalText: 'First para.\n\nSecond para.',
    );
    final result = await service.translateChapter(legacy);

    expect(sent, ['First para.', 'Second para.']);
    expect(result, 'TL:First para.\n\nTL:Second para.');
  });

  test('refuses an empty chapter without calling the provider', () async {
    var called = false;
    final service = TranslationService(
      endpoint: 'http://127.0.0.1:52828',
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      service.translateChapter(
        ChapterData(id: 'empty', title: 'Empty', originalText: '   '),
      ),
      throwsA(isA<TranslationException>()),
    );
    expect(called, isFalse);
  });
}

class SocketFailure implements Exception {
  const SocketFailure();
}
