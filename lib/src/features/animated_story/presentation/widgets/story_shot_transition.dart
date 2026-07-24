import 'package:flutter/material.dart';

enum StoryShotTransitionStyle { cut, fade, slideLeft, slideRight }

StoryShotTransitionStyle storyShotTransitionFor(String transitionId) {
  return switch (transitionId) {
    'fade' || 'fade_in' => StoryShotTransitionStyle.fade,
    'slide_left' => StoryShotTransitionStyle.slideLeft,
    'slide_right' => StoryShotTransitionStyle.slideRight,
    _ => StoryShotTransitionStyle.cut,
  };
}

Duration storyShotTransitionDuration(
  String transitionId, {
  required bool reducedMotion,
}) {
  if (reducedMotion) return const Duration(milliseconds: 160);
  return storyShotTransitionFor(transitionId) == StoryShotTransitionStyle.cut
      ? Duration.zero
      : const Duration(milliseconds: 320);
}

Widget buildStoryShotTransition({
  required String transitionId,
  required bool reducedMotion,
  required Animation<double> animation,
  required Widget child,
}) {
  final style = reducedMotion
      ? StoryShotTransitionStyle.fade
      : storyShotTransitionFor(transitionId);
  if (style == StoryShotTransitionStyle.cut) return child;
  final faded = FadeTransition(opacity: animation, child: child);
  if (style == StoryShotTransitionStyle.fade) return faded;
  final start = style == StoryShotTransitionStyle.slideLeft
      ? const Offset(0.08, 0)
      : const Offset(-0.08, 0);
  return SlideTransition(
    position: Tween(begin: start, end: Offset.zero).animate(animation),
    child: faded,
  );
}
