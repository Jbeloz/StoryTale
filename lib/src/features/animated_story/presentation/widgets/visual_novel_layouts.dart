import 'package:flutter/widgets.dart';

class VisualNovelSlot {
  const VisualNovelSlot(this.alignment, this.heightFactor);

  final Alignment alignment;
  final double heightFactor;
}

class VisualNovelLayoutPreset {
  const VisualNovelLayoutPreset(this.slots);

  final List<VisualNovelSlot> slots;

  static VisualNovelLayoutPreset resolve(String layoutId, int characterCount) {
    final preset = switch (layoutId) {
      'background_establishing' || 'object_detail' => empty,
      'solo_left_full' => soloLeft,
      'solo_right_full' => soloRight,
      'solo_medium' => soloMedium,
      'solo_close_reaction' => soloClose,
      'two_left_cluster' => pairLeft,
      'two_right_cluster' => pairRight,
      'speaker_focus_left' => focusLeft,
      'speaker_focus_right' => focusRight,
      'depth_pair' => depthPair,
      'group_three' => groupThree,
      'entrance_exit' => entrance,
      'two_balanced' ||
      'pointing_reveal' ||
      'conflict_impact' ||
      'quiet_emotional' => pair,
      _ => _fallback(characterCount),
    };
    return preset.slots.length >= characterCount
        ? preset
        : _fallback(characterCount);
  }

  static const empty = VisualNovelLayoutPreset([]);
  static const soloLeft = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(-0.72, 1), 0.76),
  ]);
  static const soloCenter = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment.bottomCenter, 0.76),
  ]);
  static const soloRight = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(0.72, 1), 0.76),
  ]);
  static const soloMedium = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment.bottomCenter, 0.92),
  ]);
  static const soloClose = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment.bottomCenter, 1.08),
  ]);
  static const pair = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(-0.62, 1), 0.70),
    VisualNovelSlot(Alignment(0.62, 1), 0.70),
  ]);
  static const pairLeft = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(-0.76, 1), 0.70),
    VisualNovelSlot(Alignment(-0.22, 1), 0.70),
  ]);
  static const pairRight = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(0.22, 1), 0.70),
    VisualNovelSlot(Alignment(0.76, 1), 0.70),
  ]);
  static const focusLeft = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(-0.42, 1), 0.84),
    VisualNovelSlot(Alignment(0.72, 1), 0.58),
  ]);
  static const focusRight = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(-0.72, 1), 0.58),
    VisualNovelSlot(Alignment(0.42, 1), 0.84),
  ]);
  static const depthPair = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(-0.26, 1), 0.88),
    VisualNovelSlot(Alignment(0.72, 0.72), 0.50),
  ]);
  static const groupThree = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(-0.72, 1), 0.56),
    VisualNovelSlot(Alignment.bottomCenter, 0.62),
    VisualNovelSlot(Alignment(0.72, 1), 0.56),
  ]);
  static const entrance = VisualNovelLayoutPreset([
    VisualNovelSlot(Alignment(0.86, 1), 0.72),
  ]);

  static VisualNovelLayoutPreset _fallback(int characterCount) {
    return switch (characterCount) {
      0 => empty,
      1 => soloCenter,
      2 => pair,
      _ => groupThree,
    };
  }
}
