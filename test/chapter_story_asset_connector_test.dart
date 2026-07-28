import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/chapter_story_asset_connector.dart';
import 'package:storytale/src/features/animated_story/data/story_analysis_contract.dart';
import 'package:storytale/src/features/animated_story/data/story_background_repository.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_models.dart';
import 'package:storytale/src/features/animated_story/data/story_foreground_repository.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  test('connects only source-backed ready assets with stable IDs', () {
    const bookId = 'phase-6e-book';
    const chapterId = 'chapter-1';
    const blockId = 'chapter-1-block-1';
    final backgroundId = StoryBackgroundAssetData.stableId(
      bookId: bookId,
      locationId: 'rose_garden',
      stateId: 'moonlit',
    );
    final flowerId = StoryForegroundAssetData.stableId(
      bookId: bookId,
      entityId: 'flower',
      variantId: 'normal',
    );
    final chairId = StoryForegroundAssetData.stableId(
      bookId: bookId,
      entityId: 'chair',
      variantId: 'normal',
    );
    final lampWithoutBytesId = StoryForegroundAssetData.stableId(
      bookId: bookId,
      entityId: 'lamp',
      variantId: 'normal',
    );
    final chapter = ChapterData(
      id: chapterId,
      title: 'The Flower',
      originalText: 'The flower waited beside the chair and lamp.',
      sourceBlocks: const [
        ChapterTextBlock(
          id: blockId,
          text: 'The flower waited beside the chair and lamp.',
        ),
      ],
    );
    final story = ChapterStoryData(
      chapterId: chapterId,
      moral: '',
      cutscenes: const [
        StoryCutsceneData(
          id: 'cutscene-1',
          locationId: 'rose_garden',
          backgroundStateId: 'moonlit',
          shots: [
            StoryShotPlanData(
              id: 'shot-1',
              layoutId: 'object_detail',
              backgroundId: 'background-placeholder',
              beats: [
                StoryBeatData(
                  id: 'beat-1',
                  speakerId: 'prototype_heroine',
                  originalText: 'The flower waited beside the chair and lamp.',
                  sourceBlockIds: [blockId],
                ),
              ],
              characterLayers: [
                StoryCharacterLayerData(
                  characterId: 'prototype_heroine',
                  rigId: 'humanoid_v1',
                  poseId: 'neutral',
                ),
              ],
            ),
          ],
        ),
      ],
    );
    const bible = BookStoryBibleData(
      bookId: bookId,
      entities: [
        StoryEntityData(
          entityId: 'flower',
          kind: StoryEntityKind.plant,
          canonicalName: 'Flower',
          description: 'A flower from the chapter.',
          firstSeenChapterId: chapterId,
          sourceBlockIds: [blockId],
          approved: true,
        ),
        StoryEntityData(
          entityId: 'chair',
          kind: StoryEntityKind.prop,
          canonicalName: 'Chair',
          description: 'A chair from the chapter.',
          firstSeenChapterId: chapterId,
          sourceBlockIds: [blockId],
          approved: true,
        ),
        StoryEntityData(
          entityId: 'lamp',
          kind: StoryEntityKind.prop,
          canonicalName: 'Lamp',
          description: 'A lamp from the chapter.',
          firstSeenChapterId: chapterId,
          sourceBlockIds: [blockId],
          approved: true,
        ),
      ],
    );
    final connected = const ChapterStoryAssetConnector().connect(
      chapter: chapter,
      story: story,
      bible: bible,
      backgrounds: [
        StoryBackgroundAssetData(
          assetId: backgroundId,
          bookId: bookId,
          locationId: 'rose_garden',
          stateId: 'moonlit',
          prompt: 'A visual-novel rose garden.',
          imageBase64: base64Encode([1, 2, 3]),
          createdAt: '2026-07-28T00:00:00.000Z',
          approved: true,
        ),
      ],
      foregrounds: [
        StoryForegroundAssetData(
          assetId: flowerId,
          bookId: bookId,
          entityId: 'flower',
          entityKind: StoryEntityKind.plant,
          entityName: 'Flower',
          variantId: 'normal',
          description: 'A flower from the chapter.',
          chapterIds: const [chapterId],
          reasons: const ['visual focus'],
          status: StoryForegroundAssetStatus.approved,
          imageBase64: base64Encode([4, 5, 6]),
        ),
        StoryForegroundAssetData(
          assetId: chairId,
          bookId: bookId,
          entityId: 'chair',
          entityKind: StoryEntityKind.prop,
          entityName: 'Chair',
          variantId: 'normal',
          description: 'A chair from the chapter.',
          chapterIds: const [chapterId],
          reasons: const ['visual focus'],
          status: StoryForegroundAssetStatus.approved,
          imageBase64: base64Encode([7, 8, 9]),
        ),
        StoryForegroundAssetData(
          assetId: lampWithoutBytesId,
          bookId: bookId,
          entityId: 'lamp',
          entityKind: StoryEntityKind.prop,
          entityName: 'Lamp',
          variantId: 'normal',
          description: 'A lamp from the chapter.',
          chapterIds: const [chapterId],
          reasons: const ['visual focus'],
          status: StoryForegroundAssetStatus.approved,
        ),
      ],
    );

    final shot = connected.shots.single;
    expect(shot.backgroundId, backgroundId);
    expect(shot.characterLayers, isEmpty);
    expect(shot.focusAssetLayers.map((layer) => layer.assetId), [
      flowerId,
      chairId,
    ]);
    expect(
      shot.focusAssetLayers.any((layer) => layer.assetId == lampWithoutBytesId),
      isFalse,
    );
  });

  test('analysis contract rejects an unknown focus asset ID', () {
    final chapter = ChapterData(
      id: 'chapter-1',
      title: 'The Flower',
      originalText: 'The flower waited.',
      sourceBlocks: const [
        ChapterTextBlock(id: 'block-1', text: 'The flower waited.'),
      ],
    );
    final story = ChapterStoryData(
      chapterId: chapter.id,
      moral: '',
      cutscenes: const [
        StoryCutsceneData(
          id: 'cutscene-1',
          locationId: 'rose_garden',
          backgroundStateId: 'night',
          shots: [
            StoryShotPlanData(
              id: 'shot-1',
              layoutId: 'object_detail',
              backgroundId: 'background.book.rose_garden.night',
              beats: [
                StoryBeatData(
                  id: 'beat-1',
                  speakerId: 'Narrator',
                  originalText: 'The flower waited.',
                  sourceBlockIds: ['block-1'],
                ),
              ],
              focusAssetLayers: [
                StoryFocusAssetLayerData(
                  entityId: 'flower',
                  assetId: 'foreground.book.invented.normal',
                  variantId: 'normal',
                ),
              ],
            ),
          ],
        ),
      ],
    );
    const catalog = StoryAnalysisCatalog(
      characters: [],
      backgroundIds: ['background.book.rose_garden.night'],
      locations: [
        StoryAnalysisLocation(
          id: 'rose_garden',
          name: 'Rose Garden',
          backgroundBrief: 'A rose garden at night.',
        ),
      ],
      backgroundAssets: [
        StoryAnalysisBackgroundAsset(
          assetId: 'background.book.rose_garden.night',
          locationId: 'rose_garden',
          stateId: 'night',
        ),
      ],
      foregroundAssets: [
        StoryAnalysisForegroundAsset(
          entityId: 'flower',
          assetId: 'foreground.book.flower.normal',
          variantId: 'normal',
          name: 'Flower',
          kind: 'plant',
          sourceBlockIds: ['block-1'],
        ),
      ],
    );

    expect(
      () => StoryAnalysisContract.validate(
        story: story,
        chapter: chapter,
        catalog: catalog,
      ),
      throwsA(isA<StoryAnalysisException>()),
    );
  });
}
