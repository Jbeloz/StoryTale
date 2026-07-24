import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/presentation/widgets/story_camera_viewport.dart';

void main() {
  test('all approved camera presets stay inside the safety limits', () {
    const presetIds = [
      'camera_static',
      'camera_push_in_slow',
      'camera_pull_out_slow',
      'camera_pan_left_slow',
      'camera_pan_right_slow',
      'camera_drift_left',
      'camera_drift_right',
      'camera_snap_in',
      'camera_shake_short',
    ];

    for (final presetId in presetIds) {
      final motion = storyCameraMotionFor(presetId);
      expect(motion.startScale, inInclusiveRange(1, 1.18));
      expect(motion.endScale, inInclusiveRange(1, 1.18));
      expect(motion.startX.abs(), lessThanOrEqualTo(0.06));
      expect(motion.endX.abs(), lessThanOrEqualTo(0.06));
      expect(motion.shakePixels, inInclusiveRange(0, 8));
    }
  });

  testWidgets('reduced motion replaces a moving camera with a short fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: StoryCameraViewport(
            animationKey: 'test-shot',
            presetId: 'camera_push_in_slow',
            reducedMotion: true,
            child: ColoredBox(color: Colors.purple),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('story-camera-reduced-test-shot')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });
}
