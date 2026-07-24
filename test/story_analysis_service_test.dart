import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storytale/src/features/animated_story/data/story_analysis_contract.dart';
import 'package:storytale/src/features/animated_story/data/story_analysis_service.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  final chapter = ChapterData(
    id: 'chapter-1',
    title: 'A Test Chapter',
    originalText: 'Hello world.\n\nGood night.',
    sourceBlocks: const [
      ChapterTextBlock(id: 'block-1', text: 'Hello world.'),
      ChapterTextBlock(id: 'block-2', text: 'Good night.'),
    ],
  );

  test('accepts a validated plan made only from approved IDs', () {
    expect(
      () => StoryAnalysisContract.validate(
        story: _validStory(),
        chapter: chapter,
        catalog: StoryAnalysisCatalog.prototype,
      ),
      returnsNormally,
    );
  });

  test('rejects invented camera IDs and changed chapter text', () {
    final invalid = _validStory(
      cameraPresetId: 'gemini_free_camera',
      secondLine: 'Gemini rewrote this.',
    );

    expect(
      () => StoryAnalysisContract.validate(
        story: invalid,
        chapter: chapter,
        catalog: StoryAnalysisCatalog.prototype,
      ),
      throwsA(isA<StoryAnalysisException>()),
    );
  });

  test('posts stable blocks and parses the Worker plan', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://worker.example/analyze');
      expect(request.headers['authorization'], 'Bearer private-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['schemaVersion'], 1);
      expect((body['chapter'] as Map<String, dynamic>)['blocks'], hasLength(2));
      return http.Response(
        jsonEncode(_validStory().toJson()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final provider = GeminiStoryAnalysisProvider(
      client: client,
      endpoint: 'https://worker.example/',
      token: 'private-token',
    );

    final story = await provider.analyze(
      chapter: chapter,
      catalog: StoryAnalysisCatalog.prototype,
    );

    expect(story.chapterId, chapter.id);
    expect(story.shots, hasLength(2));
    expect(story.shots.last.beats.single.sourceBlockIds, ['block-2']);
  });
}

ChapterStoryData _validStory({
  String cameraPresetId = 'camera_static',
  String secondLine = 'Good night.',
}) {
  StoryShotPlanData shot(int number, String blockId, String line) {
    return StoryShotPlanData(
      id: 'shot-$number',
      layoutId: 'solo_left_full',
      backgroundId: 'moonlit_rose_garden',
      transitionId: number == 1 ? 'fade' : 'cut',
      camera: StoryCameraPlanData(presetId: cameraPresetId),
      characterLayers: const [
        StoryCharacterLayerData(
          characterId: 'hero_actor',
          rigId: 'humanoid_v1',
          poseId: 'talking',
          faceProfileId: 'hero',
          faceSetId: 'neutral',
          stagePosition: 'left',
          facing: 'right',
          movement: 'focus_speaker',
          isSpeaking: true,
        ),
      ],
      beats: [
        StoryBeatData(
          id: 'beat-$number',
          speakerId: 'Hero',
          originalText: line,
          sourceBlockIds: [blockId],
        ),
      ],
    );
  }

  return ChapterStoryData(
    chapterId: 'chapter-1',
    moral: 'Be kind.',
    cutscenes: [
      StoryCutsceneData(
        id: 'cutscene-1',
        locationId: 'moonlit_rose_garden',
        shots: [
          shot(1, 'block-1', 'Hello world.'),
          shot(2, 'block-2', secondLine),
        ],
      ),
    ],
  );
}
