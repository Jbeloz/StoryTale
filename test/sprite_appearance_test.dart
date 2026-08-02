import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/sprite_appearance.dart';

void main() {
  test('stores independent hair fits for actors and back-hair styles', () {
    var appearance = const SpriteAppearanceSelection();
    appearance = appearance.withHairFitForPart(
      'front_hair',
      const SpriteHairFit(offsetX: 12, offsetY: -8, scale: 1.25),
    );
    appearance = appearance.copyWith(hairStyleId: 'long');
    appearance = appearance.withHairFitForPart(
      'back_hair',
      const SpriteHairFit(offsetX: -4, offsetY: 18, scale: 1.5),
    );
    appearance = appearance.copyWith(actorId: 'elder', hairStyleId: 'none');
    appearance = appearance.withHairFitForPart(
      'front_hair',
      const SpriteHairFit(scale: 1.1),
    );

    final restored = SpriteAppearanceSelection.fromJson(appearance.toJson());

    expect(restored.hairFitForPart('front_hair').scale, 1.1);
    final defaultActor = restored.copyWith(
      actorId: 'default',
      hairStyleId: 'medium',
    );
    expect(defaultActor.hairFitForPart('front_hair').offsetX, 12);
    expect(defaultActor.hairFitForPart('back_hair').scale, 1);
    expect(
      defaultActor
          .copyWith(hairStyleId: 'long')
          .hairFitForPart('back_hair')
          .scale,
      1.5,
    );
  });
}
