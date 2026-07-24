import 'dart:math' as math;

import 'package:flutter/material.dart';

class StoryCameraMotion {
  const StoryCameraMotion({
    this.startScale = 1,
    this.endScale = 1,
    this.startX = 0,
    this.endX = 0,
    this.shakePixels = 0,
    this.duration = Duration.zero,
  });

  final double startScale;
  final double endScale;
  final double startX;
  final double endX;
  final double shakePixels;
  final Duration duration;
}

StoryCameraMotion storyCameraMotionFor(String presetId) {
  return switch (presetId) {
    'camera_push_in_slow' => const StoryCameraMotion(
      endScale: 1.12,
      duration: Duration(milliseconds: 2200),
    ),
    'camera_pull_out_slow' => const StoryCameraMotion(
      startScale: 1.12,
      duration: Duration(milliseconds: 2200),
    ),
    'camera_pan_left_slow' => const StoryCameraMotion(
      startScale: 1.12,
      endScale: 1.12,
      endX: -0.06,
      duration: Duration(milliseconds: 2400),
    ),
    'camera_pan_right_slow' => const StoryCameraMotion(
      startScale: 1.12,
      endScale: 1.12,
      endX: 0.06,
      duration: Duration(milliseconds: 2400),
    ),
    'camera_drift_left' => const StoryCameraMotion(
      startScale: 1.12,
      endScale: 1.12,
      startX: 0.025,
      endX: -0.025,
      duration: Duration(milliseconds: 4000),
    ),
    'camera_drift_right' => const StoryCameraMotion(
      startScale: 1.12,
      endScale: 1.12,
      startX: -0.025,
      endX: 0.025,
      duration: Duration(milliseconds: 4000),
    ),
    'camera_snap_in' => const StoryCameraMotion(
      endScale: 1.08,
      duration: Duration(milliseconds: 320),
    ),
    'camera_shake_short' => const StoryCameraMotion(
      startScale: 1.02,
      endScale: 1.02,
      shakePixels: 8,
      duration: Duration(milliseconds: 280),
    ),
    _ => const StoryCameraMotion(),
  };
}

class StoryCameraViewport extends StatelessWidget {
  const StoryCameraViewport({
    required this.animationKey,
    required this.presetId,
    required this.reducedMotion,
    required this.child,
    super.key,
  });

  final String animationKey;
  final String presetId;
  final bool reducedMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = storyCameraMotionFor(presetId);
    if (motion.duration == Duration.zero) {
      return KeyedSubtree(
        key: ValueKey('story-camera-static-$animationKey'),
        child: child,
      );
    }
    if (reducedMotion) {
      return TweenAnimationBuilder<double>(
        key: ValueKey('story-camera-reduced-$animationKey'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 160),
        child: child,
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
      );
    }
    return LayoutBuilder(
      key: ValueKey('story-camera-$presetId-$animationKey'),
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motion.duration,
          curve: Curves.easeInOutCubic,
          child: child,
          builder: (context, value, child) {
            final scale = _lerp(
              motion.startScale,
              motion.endScale,
              value,
            ).clamp(1.0, 1.18);
            final xFraction = _lerp(
              motion.startX,
              motion.endX,
              value,
            ).clamp(-0.06, 0.06);
            final shake =
                math.sin(value * math.pi * 6) *
                motion.shakePixels.clamp(0, 8) *
                (1 - value);
            return Transform.translate(
              offset: Offset(constraints.maxWidth * xFraction + shake, 0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
        );
      },
    );
  }
}

double _lerp(double start, double end, double value) {
  return start + (end - start) * value;
}
