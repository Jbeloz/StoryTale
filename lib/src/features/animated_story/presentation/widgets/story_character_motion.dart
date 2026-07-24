import 'dart:math' as math;

import 'package:flutter/material.dart';

class StoryCharacterMotionSpec {
  const StoryCharacterMotionSpec({
    this.startX = 0,
    this.endX = 0,
    this.startY = 0,
    this.endY = 0,
    this.startScale = 1,
    this.endScale = 1,
    this.startOpacity = 1,
    this.endOpacity = 1,
    this.pulseScale = 0,
    this.repeats = false,
    this.duration = Duration.zero,
  });

  final double startX;
  final double endX;
  final double startY;
  final double endY;
  final double startScale;
  final double endScale;
  final double startOpacity;
  final double endOpacity;
  final double pulseScale;
  final bool repeats;
  final Duration duration;
}

StoryCharacterMotionSpec storyCharacterMotionFor(String movementId) {
  return switch (movementId) {
    'enter_left' => const StoryCharacterMotionSpec(
      startX: -0.26,
      startOpacity: 0,
      duration: Duration(milliseconds: 480),
    ),
    'enter_right' => const StoryCharacterMotionSpec(
      startX: 0.26,
      startOpacity: 0,
      duration: Duration(milliseconds: 480),
    ),
    'exit_left' => const StoryCharacterMotionSpec(
      endX: -0.26,
      endOpacity: 0,
      duration: Duration(milliseconds: 420),
    ),
    'exit_right' => const StoryCharacterMotionSpec(
      endX: 0.26,
      endOpacity: 0,
      duration: Duration(milliseconds: 420),
    ),
    'walk_left' => const StoryCharacterMotionSpec(
      startX: 0.12,
      endX: -0.08,
      duration: Duration(milliseconds: 700),
    ),
    'walk_right' => const StoryCharacterMotionSpec(
      startX: -0.12,
      endX: 0.08,
      duration: Duration(milliseconds: 700),
    ),
    'step_forward' => const StoryCharacterMotionSpec(
      startScale: 0.94,
      endScale: 1.08,
      duration: Duration(milliseconds: 360),
    ),
    'step_back' => const StoryCharacterMotionSpec(
      startScale: 1.08,
      endScale: 0.92,
      duration: Duration(milliseconds: 360),
    ),
    'focus_speaker' => const StoryCharacterMotionSpec(
      startScale: 0.98,
      endScale: 1.05,
      duration: Duration(milliseconds: 260),
    ),
    'idle_breathe' => const StoryCharacterMotionSpec(
      endScale: 1.025,
      repeats: true,
      duration: Duration(milliseconds: 900),
    ),
    'gentle_bob' => const StoryCharacterMotionSpec(
      endY: -0.025,
      duration: Duration(milliseconds: 700),
    ),
    'reaction_pop' => const StoryCharacterMotionSpec(
      pulseScale: 0.10,
      duration: Duration(milliseconds: 360),
    ),
    'fade_in' => const StoryCharacterMotionSpec(
      startOpacity: 0,
      duration: Duration(milliseconds: 260),
    ),
    'fade_out' => const StoryCharacterMotionSpec(
      endOpacity: 0,
      duration: Duration(milliseconds: 260),
    ),
    _ => const StoryCharacterMotionSpec(),
  };
}

class StoryCharacterMotion extends StatefulWidget {
  const StoryCharacterMotion({
    required this.animationKey,
    required this.movementId,
    required this.reducedMotion,
    required this.child,
    super.key,
  });

  final String animationKey;
  final String movementId;
  final bool reducedMotion;
  final Widget child;

  @override
  State<StoryCharacterMotion> createState() => _StoryCharacterMotionState();
}

class _StoryCharacterMotionState extends State<StoryCharacterMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  StoryCharacterMotionSpec get _motion {
    final motion = storyCharacterMotionFor(widget.movementId);
    if (!widget.reducedMotion || motion.duration == Duration.zero) {
      return motion;
    }
    return StoryCharacterMotionSpec(
      startOpacity: widget.movementId == 'fade_out' ? 1 : 0,
      endOpacity: widget.movementId == 'fade_out' ? 0 : 1,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1),
    );
    _start();
  }

  @override
  void didUpdateWidget(covariant StoryCharacterMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationKey != widget.animationKey ||
        oldWidget.movementId != widget.movementId ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _start();
    }
  }

  void _start() {
    final motion = _motion;
    _controller.stop();
    if (motion.duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller.duration = motion.duration;
    if (motion.repeats && !widget.reducedMotion) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motion;
    if (motion.duration == Duration.zero) {
      return KeyedSubtree(
        key: ValueKey('story-motion-static-${widget.animationKey}'),
        child: widget.child,
      );
    }
    return LayoutBuilder(
      key: ValueKey('story-motion-${widget.movementId}-${widget.animationKey}'),
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final value = Curves.easeInOutCubic.transform(_controller.value);
            final pulse = math.sin(value * math.pi) * motion.pulseScale;
            final scale =
                _lerp(motion.startScale, motion.endScale, value) + pulse;
            return Opacity(
              opacity: _lerp(
                motion.startOpacity,
                motion.endOpacity,
                value,
              ).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(
                  constraints.maxWidth *
                      _lerp(motion.startX, motion.endX, value),
                  constraints.maxHeight *
                      _lerp(motion.startY, motion.endY, value),
                ),
                child: Transform.scale(scale: scale, child: child),
              ),
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
