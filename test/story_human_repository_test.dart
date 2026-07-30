import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/features/animated_story/data/sprite_layer_processor.dart';
import 'package:storytale/src/features/animated_story/data/story_analysis_contract.dart';
import 'package:storytale/src/features/animated_story/data/story_asset_binary_store.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_models.dart';
import 'package:storytale/src/features/animated_story/data/story_human_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'creates one stable reusable human record from the Story Bible',
    () async {
      const bible = BookStoryBibleData(
        bookId: 'book-1',
        entities: [
          StoryEntityData(
            entityId: 'little_prince',
            kind: StoryEntityKind.human,
            canonicalName: 'Little Prince',
            description: 'A kind young prince and main hero.',
            firstSeenChapterId: 'chapter-1',
            chapterAppearanceIds: ['chapter-1', 'chapter-2'],
            approved: true,
          ),
        ],
      );
      final repository = StoryHumanRepository();
      final first = (await repository.sync(bible)).single;
      final second = (await repository.sync(bible)).single;

      expect(first.rigId, 'human.book_1.little_prince');
      expect(first.actorProfileId, 'hero');
      expect(first.chapterIds, ['chapter-1', 'chapter-2']);
      expect(second.rigId, first.rigId);
    },
  );

  test(
    'only exposes a human after its master and all rig layers exist',
    () async {
      const bible = BookStoryBibleData(
        bookId: 'book-2',
        entities: [
          StoryEntityData(
            entityId: 'alice',
            kind: StoryEntityKind.human,
            canonicalName: 'Alice',
            description: 'A curious young girl.',
            firstSeenChapterId: 'chapter-1',
            approved: true,
          ),
        ],
      );
      final repository = StoryHumanRepository();
      final asset = (await repository.sync(bible)).single;
      final source = image.Image(
        SpriteLayerProcessor.canonicalCanvasWidth,
        SpriteLayerProcessor.canonicalCanvasHeight,
      );
      for (final frame in SpriteLayerProcessor.canonicalPartFrames.values) {
        source.setPixelRgba(
          frame.x + frame.width ~/ 2,
          frame.y + frame.height ~/ 2,
          30,
          40,
          50,
          255,
        );
      }
      final rig = const SpriteLayerProcessor().processRig(
        Uint8List.fromList(image.encodePng(source)),
      );

      StoryAssetBinaryStore.write(asset.masterAssetId, rig.source);
      StoryAssetBinaryStore.write(asset.rejoinedAssetId, rig.rejoined);
      for (final entry in rig.parts.entries) {
        StoryAssetBinaryStore.write(
          asset.partAssetIds[entry.key]!,
          entry.value,
        );
      }
      await repository.save(
        asset.copyWith(
          status: StoryHumanAssetStatus.approved,
          width: rig.width,
          height: rig.height,
          rigMetadata: StoryHumanRigMetadata.fromProcessedLayers(rig),
          packageValidated: true,
        ),
      );

      expect(await repository.loadReady(bible.bookId), hasLength(1));
    },
  );

  test(
    'prepared analysis catalog uses the locked book character ID and rig',
    () {
      const rigId = 'human.book_3.hero';
      StoryAssetBinaryStore.write('$rigId.master', Uint8List.fromList([1]));
      const bible = BookStoryBibleData(
        bookId: 'book-3',
        entities: [
          StoryEntityData(
            entityId: 'hero',
            kind: StoryEntityKind.human,
            canonicalName: 'Ren',
            description: 'A bright young hero.',
            firstSeenChapterId: 'chapter-1',
            approved: true,
            lockedAppearance: true,
            rigId: rigId,
            faceProfileId: 'hero',
          ),
        ],
      );

      final catalog = StoryAnalysisCatalog.fromPreparedAssets(
        bible: bible,
        chapterId: 'chapter-1',
        backgrounds: const [],
        foregrounds: const [],
      );

      expect(catalog.characters.single.id, 'hero');
      expect(catalog.characters.single.rigIds, [rigId]);
      expect(catalog.characters.single.faceProfileIds, ['hero']);
    },
  );
}
