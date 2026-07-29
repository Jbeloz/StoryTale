import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/core/state/storytale_scope.dart';
import 'package:storytale/src/features/animated_story/data/story_asset_binary_store.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_models.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_repository.dart';
import 'package:storytale/src/features/animated_story/data/story_foreground_repository.dart';
import 'package:storytale/src/features/animated_story/presentation/story_foreground_inventory_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('foreground replacement preserves the canonical asset ID', () async {
    final repository = StoryForegroundRepository();
    final asset = _asset('foreground.book.flower.normal');
    final candidateId = '${asset.assetId}.candidate.1';
    final replacement = _replacement(candidateId);

    StoryAssetBinaryStore.write(asset.assetId, Uint8List.fromList([1]));
    StoryAssetBinaryStore.write(candidateId, Uint8List.fromList([7, 8, 9]));
    await repository.save(asset);

    final assets = await repository.applyReplacement(asset, replacement);

    expect(assets.single.assetId, asset.assetId);
    expect(assets.single.status, StoryForegroundAssetStatus.approved);
    expect(assets.single.bytes, orderedEquals([7, 8, 9]));
    expect(StoryAssetBinaryStore.contains(candidateId), isFalse);
  });

  test('reuse discards only the replacement candidate', () {
    final repository = StoryForegroundRepository();
    final asset = _asset('foreground.book.chair.normal');
    final candidateId = '${asset.assetId}.candidate.2';
    final replacement = _replacement(candidateId);

    StoryAssetBinaryStore.write(asset.assetId, Uint8List.fromList([3, 4]));
    StoryAssetBinaryStore.write(candidateId, Uint8List.fromList([5, 6]));

    repository.discardReplacement(replacement);

    expect(StoryAssetBinaryStore.read(asset.assetId), orderedEquals([3, 4]));
    expect(StoryAssetBinaryStore.contains(candidateId), isFalse);
  });

  testWidgets('ready foreground shows preview and optional review actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = StoryTaleController();
    final bookId = controller.currentBook!.id;
    final bibleRepository = StoryBibleRepository();
    final foregroundRepository = StoryForegroundRepository();
    const entityId = 'rose';
    final assetId = StoryForegroundAssetData.stableId(
      bookId: bookId,
      entityId: entityId,
      variantId: 'normal',
    );
    await bibleRepository.save(
      BookStoryBibleData(
        bookId: bookId,
        entities: const [
          StoryEntityData(
            entityId: entityId,
            kind: StoryEntityKind.plant,
            canonicalName: 'Rose',
            description: 'A story-important rose.',
            firstSeenChapterId: 'chapter-1',
            sourceBlockIds: ['block-1'],
            recurring: true,
            importance: StoryEntityImportance.focus,
            confidence: 1,
            approved: true,
          ),
        ],
      ),
    );
    final asset = StoryForegroundAssetData(
      assetId: assetId,
      bookId: bookId,
      entityId: entityId,
      entityKind: StoryEntityKind.plant,
      entityName: 'Rose',
      variantId: 'normal',
      description: 'A story-important rose.',
      chapterIds: const ['chapter-1'],
      reasons: const ['recurring', 'visual focus'],
      status: StoryForegroundAssetStatus.approved,
      width: 4,
      height: 4,
    );
    StoryAssetBinaryStore.write(
      assetId,
      Uint8List.fromList(image.encodePng(image.Image(4, 4))),
    );
    await foregroundRepository.save(asset);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryTaleScope(
          controller: controller,
          child: StoryForegroundInventoryPage(
            foregroundRepository: foregroundRepository,
            storyBibleRepository: bibleRepository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('Current asset'), findsOneWidget);
    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Replace PNG'), findsOneWidget);
  });
}

StoryForegroundAssetData _asset(String assetId) {
  return StoryForegroundAssetData(
    assetId: assetId,
    bookId: 'book',
    entityId: 'entity',
    entityKind: StoryEntityKind.prop,
    entityName: 'Subject',
    variantId: 'normal',
    description: 'A reusable subject.',
    chapterIds: const ['chapter-1'],
    reasons: const ['visual focus'],
    status: StoryForegroundAssetStatus.approved,
  );
}

StoryForegroundReplacementData _replacement(String candidateId) {
  return StoryForegroundReplacementData(
    candidateAssetId: candidateId,
    mimeType: 'image/png',
    width: 256,
    height: 256,
    generationPrompt: 'Replacement.',
    generatedAt: '2026-07-29T00:00:00.000Z',
  );
}
