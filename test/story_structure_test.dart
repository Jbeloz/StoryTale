import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  test('chapter uses safe narration-only fallback structure', () {
    final controller = StoryTaleController();
    final chapter = ChapterData(
      id: 'structured-fallback-chapter',
      title: 'Structured Fallback',
      originalText: 'The journey began.\n\nA flower appeared.',
      sourceBlocks: const [
        ChapterTextBlock(id: 'block-1', text: 'The journey began.'),
        ChapterTextBlock(id: 'block-2', text: 'A flower appeared.'),
      ],
    );
    final story = controller.storyFor(chapter);

    expect(story.cutscenes, hasLength(1));
    expect(story.shots, hasLength(2));
    expect(story.shots.every((shot) => shot.beats.isNotEmpty), isTrue);
    expect(story.shots.map((shot) => shot.camera.presetId), [
      'camera_static',
      'camera_push_in_slow',
    ]);
    expect(story.shots.map((shot) => shot.transitionId), ['fade_in', 'cut']);
    expect(
      story.shots.every(
        (shot) =>
            shot.characterLayers.isEmpty &&
            shot.focusAssetLayers.isEmpty &&
            shot.beats.every((beat) => beat.speakerId == 'Narrator'),
      ),
      isTrue,
    );
    expect(story.shots.map((shot) => shot.layoutId), [
      'background_establishing',
      'object_detail',
    ]);
    expect(
      story.shots.map((shot) => shot.beats.single.sourceBlockIds).toList(),
      [
        ['block-1'],
        ['block-2'],
      ],
    );
    expect(story.shots.map((shot) => shot.backgroundId), [
      'moonlit_rose_garden',
      'moonlit_rose_garden',
    ]);
    expect(story.cutsceneNumberForShot(0), 1);
  });

  test('an uploaded EPUB chapter receives the same simple variation', () {
    final controller = StoryTaleController();
    final uploadedChapter = ChapterData(
      id: 'uploaded-epub-chapter-1',
      title: 'An Uploaded Chapter',
      originalText: List.filled(
        4,
        'A reusable line from an uploaded EPUB chapter.',
      ).join('\n\n'),
    );

    final story = controller.storyFor(uploadedChapter);

    expect(story.chapterId, uploadedChapter.id);
    expect(story.shots.map((shot) => shot.layoutId), [
      'background_establishing',
      'object_detail',
      'background_establishing',
      'object_detail',
    ]);
    expect(
      story.shots
          .map((shot) => shot.beats.single.sourceBlockIds.single)
          .toList(),
      [
        'uploaded-epub-chapter-1-block-1',
        'uploaded-epub-chapter-1-block-2',
        'uploaded-epub-chapter-1-block-3',
        'uploaded-epub-chapter-1-block-4',
      ],
    );
  });
}
