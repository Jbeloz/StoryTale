import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';

void main() {
  test('chapter uses cutscene, shot, beat, camera, and staging data', () {
    final controller = StoryTaleController();
    final story = controller.storyFor(controller.currentChapter!);

    expect(story.cutscenes, hasLength(1));
    expect(story.shots, isNotEmpty);
    expect(story.shots.every((shot) => shot.beats.isNotEmpty), isTrue);
    expect(
      story.shots.every((shot) => shot.camera.presetId == 'camera_static'),
      isTrue,
    );
    expect(
      story.shots.every(
        (shot) =>
            shot.layoutId.startsWith('solo_') &&
            shot.characterLayers.single.scale == 'full' &&
            {
              'left',
              'right',
              'front',
            }.contains(shot.characterLayers.single.facing),
      ),
      isTrue,
    );
    expect(story.cutsceneNumberForShot(0), 1);
  });
}
