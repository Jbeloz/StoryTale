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
    expect(
      story.shots.every((shot) => shot.camera.presetId == 'camera_static'),
      isTrue,
    );
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
                layer.scale == 'full' &&
                {'left', 'right', 'front'}.contains(layer.facing),
          ),
      isTrue,
    );
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
