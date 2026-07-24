import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  test('chapter uses cutscene, shot, beat, camera, and staging data', () {
    final controller = StoryTaleController();
    final story = controller.storyFor(controller.currentChapter!);

    expect(story.cutscenes, hasLength(1));
    expect(story.shots, isNotEmpty);
    expect(story.shots.every((shot) => shot.beats.isNotEmpty), isTrue);
    expect(story.shots.map((shot) => shot.camera.presetId), [
      'camera_static',
      'camera_pull_out_slow',
      'camera_push_in_slow',
      'camera_static',
      'camera_snap_in',
      'camera_pan_left_slow',
    ]);
    expect(story.shots.map((shot) => shot.transitionId), [
      'fade',
      'slide_left',
      'cut',
      'fade',
      'slide_right',
      'cut',
    ]);
    expect(story.shots.map((shot) => shot.characterLayers.length), [
      2,
      0,
      1,
      3,
      1,
      2,
    ]);
    expect(
      story.shots
          .expand((shot) => shot.characterLayers)
          .every(
            (layer) =>
                {
                  'background',
                  'full',
                  'medium',
                  'close',
                }.contains(layer.scale) &&
                {'left', 'right', 'front'}.contains(layer.facing) &&
                {'back', 'normal', 'front'}.contains(layer.depth),
          ),
      isTrue,
    );
    expect(story.shots.first.characterLayers.map((layer) => layer.facing), [
      'right',
      'left',
    ]);
    expect(story.shots.first.characterLayers.map((layer) => layer.isSpeaking), [
      true,
      false,
    ]);
    expect(story.shots.first.characterLayers.map((layer) => layer.movement), [
      'enter_left',
      'enter_right',
    ]);
    expect(story.shots.last.characterLayers.map((layer) => layer.scale), [
      'medium',
      'background',
    ]);
    expect(story.shots.last.characterLayers.map((layer) => layer.depth), [
      'front',
      'back',
    ]);
    expect(story.shots.last.characterLayers.map((layer) => layer.movement), [
      'walk_right',
      'step_back',
    ]);
    expect(story.cutsceneNumberForShot(0), 1);
  });

  test('an uploaded EPUB chapter receives the same reusable layouts', () {
    final controller = StoryTaleController();
    final uploadedChapter = ChapterData(
      id: 'uploaded-epub-chapter-1',
      title: 'An Uploaded Chapter',
      originalText: List.filled(
        12,
        'A reusable line from an uploaded EPUB chapter.',
      ).join('\n\n'),
    );

    final story = controller.storyFor(uploadedChapter);

    expect(story.chapterId, uploadedChapter.id);
    expect(story.shots.map((shot) => shot.layoutId), [
      'two_balanced',
      'background_establishing',
      'solo_left_full',
      'group_three',
      'solo_right_full',
      'depth_pair',
    ]);
  });
}
