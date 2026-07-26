import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/core/state/storytale_scope.dart';
import 'package:storytale/src/features/animated_story/data/story_background_repository.dart';
import 'package:storytale/src/features/animated_story/presentation/animated_story_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('approved background replaces fallback without reopening story', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = StoryTaleController();
    final chapter = controller.currentChapter!;
    controller.markStoryPrepared(chapter);
    final repository = StoryBackgroundRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: StoryTaleScope(
          controller: controller,
          child: AnimatedStoryPage(backgroundRepository: repository),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('visual-novel-background')), findsOneWidget);

    final createdAt = DateTime.utc(2026, 7, 26);
    await repository.approveCandidate(
      StoryBackgroundAssetData(
        assetId: StoryBackgroundAssetData.candidateId(
          bookId: controller.currentBook!.id,
          locationId: 'moonlit_rose_garden',
          stateId: 'unspecified',
          createdAt: createdAt,
        ),
        bookId: controller.currentBook!.id,
        locationId: 'moonlit_rose_garden',
        stateId: 'unspecified',
        prompt: 'Landscape visual-novel garden background.',
        imageBase64: base64Encode(_transparentPng),
        createdAt: createdAt.toIso8601String(),
        width: 1024,
        height: 576,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const Key('approved-visual-novel-background')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('visual-novel-background')), findsNothing);
  });
}

final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
