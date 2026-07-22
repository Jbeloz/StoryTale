import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/presentation/widgets/visual_novel_layouts.dart';

void main() {
  test('layout presets cover empty, solo, pair, and group shots', () {
    expect(
      VisualNovelLayoutPreset.resolve('background_establishing', 0).slots,
      isEmpty,
    );
    expect(
      VisualNovelLayoutPreset.resolve('solo_left_full', 1).slots,
      hasLength(1),
    );
    expect(
      VisualNovelLayoutPreset.resolve('two_balanced', 2).slots,
      hasLength(2),
    );
    expect(
      VisualNovelLayoutPreset.resolve('group_three', 3).slots,
      hasLength(3),
    );
  });

  test('unknown analyzer layouts safely fall back by character count', () {
    expect(
      VisualNovelLayoutPreset.resolve('future_layout', 1).slots,
      hasLength(1),
    );
    expect(
      VisualNovelLayoutPreset.resolve('future_layout', 2).slots,
      hasLength(2),
    );
    expect(
      VisualNovelLayoutPreset.resolve('future_layout', 3).slots,
      hasLength(3),
    );
  });
}
