import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storytale/src/features/animated_story/data/story_analysis_contract.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_models.dart';
import 'package:storytale/src/features/animated_story/data/story_entity_service.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  final chapter = ChapterData(
    id: 'chapter-1',
    title: 'The Rose',
    originalText: 'A rose grew on his planet.',
    sourceBlocks: const [
      ChapterTextBlock(id: 'block-1', text: 'A rose grew on his planet.'),
    ],
  );
  final book = BookData(
    id: 'book-1',
    title: 'Test Book',
    author: 'Author',
    description: '',
    tags: [],
    chapters: [chapter],
  );

  test('locally auto-approves safe high-confidence candidates', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://worker.example/entities');
      expect(request.headers['authorization'], 'Bearer private-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect((body['book'] as Map<String, dynamic>)['id'], 'book-1');
      expect((body['storyBible'] as Map<String, dynamic>)['entities'], isEmpty);
      return http.Response(
        jsonEncode({
          'entities': [_roseJson()],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final provider = GeminiStoryEntityProvider(
      client: client,
      endpoint: 'https://worker.example/',
      token: 'private-token',
    );

    final entities = await provider.extract(
      book: book,
      chapter: chapter,
      bible: BookStoryBibleData.empty(book.id),
    );

    expect(entities.single.kind, StoryEntityKind.plant);
    expect(entities.single.approved, isTrue);
    expect(entities.single.automaticallyApproved, isTrue);
    expect(entities.single.assetIds, isEmpty);
    expect(entities.single.sourceBlockIds, ['block-1']);
  });

  test('keeps uncertain candidates pending', () {
    final entity = StoryEntityData.fromJson({
      ..._roseJson(),
      'confidence': 0.7,
    });

    final result = StoryEntityPolicy.applyAutomaticApproval(entity);

    expect(result.approved, isFalse);
    expect(result.automaticallyApproved, isFalse);
  });

  test('approves only background-ready scene locations', () {
    final broad = StoryEntityData.fromJson({
      ..._roseJson(),
      'entityId': 'world',
      'kind': 'location',
      'canonicalName': 'Fantasy World',
      'parentSetting': 'Fantasy World',
      'backgroundBrief': 'A broad fantasy realm.',
      'sceneLocation': true,
    });
    final specific = broad.copyWith(
      canonicalName: 'Castle Courtyard',
      parentSetting: 'Fantasy World',
      backgroundBrief: 'A stone courtyard beside the castle gate.',
    );

    expect(StoryEntityPolicy.applyAutomaticApproval(broad).approved, isFalse);
    expect(StoryEntityPolicy.applyAutomaticApproval(specific).approved, isTrue);
  });

  test('rejects candidates that try to approve themselves', () async {
    final client = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'entities': [
            {..._roseJson(), 'approved': true},
          ],
        }),
        200,
      );
    });
    final provider = GeminiStoryEntityProvider(
      client: client,
      endpoint: 'https://worker.example',
      token: 'private-token',
    );

    expect(
      () => provider.extract(
        book: book,
        chapter: chapter,
        bible: BookStoryBibleData.empty(book.id),
      ),
      throwsA(isA<StoryAnalysisException>()),
    );
  });
}

Map<String, dynamic> _roseJson() => {
  'entityId': 'rose',
  'kind': 'plant',
  'canonicalName': 'Rose',
  'aliases': ['flower'],
  'description': 'A rose growing on the small planet.',
  'relationships': ['cared for by the prince'],
  'firstSeenChapterId': 'chapter-1',
  'sourceBlockIds': ['block-1'],
  'recurring': true,
  'importance': 'focus',
  'speaker': false,
  'approved': false,
  'lockedAppearance': false,
  'assetIds': <String>[],
  'unresolvedNotes': <String>[],
  'confidence': 0.98,
};
