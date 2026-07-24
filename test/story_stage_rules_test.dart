import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/presentation/widgets/story_character_view.dart';
import 'package:storytale/src/features/animated_story/presentation/widgets/visual_novel_stage.dart';

void main() {
  test('whole assembled characters only flip for left-facing shots', () {
    expect(shouldFlipStoryCharacter('left'), isTrue);
    expect(shouldFlipStoryCharacter('right'), isFalse);
    expect(shouldFlipStoryCharacter('front'), isFalse);
  });

  test('approved scale and depth values stay bounded', () {
    expect(storyScaleFactor('background'), 0.78);
    expect(storyScaleFactor('full'), 1);
    expect(storyScaleFactor('medium'), 1.16);
    expect(storyScaleFactor('close'), 1.32);
    expect(storyScaleFactor('unknown'), 1);

    expect(storyDepthOrder('back'), 0);
    expect(storyDepthOrder('normal'), 1);
    expect(storyDepthOrder('front'), 2);
  });

  test('speaker remains clear while a listener is softly dimmed', () {
    expect(
      storyCharacterOpacity(
        isSpeaking: true,
        hasSpeaker: true,
        characterCount: 2,
        depth: 'normal',
      ),
      1,
    );
    expect(
      storyCharacterOpacity(
        isSpeaking: false,
        hasSpeaker: true,
        characterCount: 2,
        depth: 'normal',
      ),
      0.68,
    );
    expect(
      storyCharacterOpacity(
        isSpeaking: false,
        hasSpeaker: false,
        characterCount: 2,
        depth: 'back',
      ),
      0.84,
    );
  });
}
