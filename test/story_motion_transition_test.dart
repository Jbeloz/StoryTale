import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/presentation/widgets/story_character_motion.dart';
import 'package:storytale/src/features/animated_story/presentation/widgets/story_shot_transition.dart';

void main() {
  test('approved character motions stay small and only breathing loops', () {
    const movementIds = [
      'enter_left',
      'enter_right',
      'exit_left',
      'exit_right',
      'walk_left',
      'walk_right',
      'step_forward',
      'step_back',
      'focus_speaker',
      'idle_breathe',
      'gentle_bob',
      'reaction_pop',
      'fade_in',
      'fade_out',
    ];

    for (final id in movementIds) {
      final motion = storyCharacterMotionFor(id);
      expect(motion.startX.abs(), lessThanOrEqualTo(0.26));
      expect(motion.endX.abs(), lessThanOrEqualTo(0.26));
      expect(motion.startY.abs(), lessThanOrEqualTo(0.025));
      expect(motion.endY.abs(), lessThanOrEqualTo(0.025));
      expect(motion.repeats, id == 'idle_breathe');
    }
  });

  test('shot transitions resolve to the approved styles and durations', () {
    expect(storyShotTransitionFor('cut'), StoryShotTransitionStyle.cut);
    expect(storyShotTransitionFor('fade'), StoryShotTransitionStyle.fade);
    expect(
      storyShotTransitionFor('slide_left'),
      StoryShotTransitionStyle.slideLeft,
    );
    expect(
      storyShotTransitionFor('slide_right'),
      StoryShotTransitionStyle.slideRight,
    );
    expect(
      storyShotTransitionDuration('cut', reducedMotion: false),
      Duration.zero,
    );
    expect(
      storyShotTransitionDuration('slide_left', reducedMotion: true),
      const Duration(milliseconds: 160),
    );
  });

  testWidgets('reduced motion replaces an entrance with a short fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 500,
          child: StoryCharacterMotion(
            animationKey: 'test-character',
            movementId: 'enter_left',
            reducedMotion: true,
            child: ColoredBox(color: Colors.purple),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('story-motion-enter_left-test-character')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });
}
