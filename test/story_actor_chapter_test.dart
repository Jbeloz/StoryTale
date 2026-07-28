import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  test('safe fallback narrates source blocks without prototype actors', () {
    final controller = StoryTaleController();
    final chapter = ChapterData(
      id: 'safe-fallback-chapter',
      title: 'A Safe Chapter',
      originalText: 'A boy entered the garden.\n\nHe noticed a flower.',
      sourceBlocks: const [
        ChapterTextBlock(
          id: 'source-block-1',
          text: 'A boy entered the garden.',
        ),
        ChapterTextBlock(id: 'source-block-2', text: 'He noticed a flower.'),
      ],
    );
    final story = controller.storyFor(chapter);
    final storyText = story.shots
        .expand((shot) => shot.beats)
        .map((beat) => beat.originalText)
        .join(' ');

    expect(storyText, 'A boy entered the garden. He noticed a flower.');
    expect(story.shots, hasLength(2));
    expect(
      story.shots.every(
        (shot) => shot.characterLayers.isEmpty && shot.focusAssetLayers.isEmpty,
      ),
      isTrue,
    );
    expect(
      story.shots
          .expand((shot) => shot.beats)
          .every((beat) => beat.speakerId == 'Narrator'),
      isTrue,
    );
    expect(
      story.shots.map((shot) => shot.beats.single.sourceBlockIds).toList(),
      [
        ['source-block-1'],
        ['source-block-2'],
      ],
    );
  });
}
