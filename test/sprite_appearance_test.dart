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

  test('restores each actor selection including explicit no back hair', () {
    var appearance = const SpriteAppearanceSelection();
    appearance = appearance.copyWith(hairStyleId: 'none', skinTone: '#ABCDEF');
    appearance = appearance.copyWith(actorId: 'hero');
    appearance = appearance.copyWith(hairStyleId: 'long', skinTone: '#123456');

    final restored = SpriteAppearanceSelection.fromJson(appearance.toJson());
    final defaultActor = restored.copyWith(actorId: 'default');
    final hero = restored.copyWith(actorId: 'hero');

    expect(defaultActor.frontHairId, 'front_default');
    expect(defaultActor.hairStyleId, 'none');
    expect(defaultActor.skinTone, '#ABCDEF');
    expect(hero.frontHairId, 'front_hero');
    expect(hero.hairStyleId, 'long');
    expect(hero.skinTone, '#123456');
    expect(restored.toJson()['actorAppearances'], hasLength(5));
  });

  test('migrates the previous active-actor appearance format', () {
    final appearance = SpriteAppearanceSelection.fromJson({
      'actorId': 'elder',
      'hairStyleId': 'none',
      'skinTone': '#DDB99D',
    });

    expect(appearance.actorId, 'elder');
    expect(appearance.frontHairId, 'front_elder');
    expect(appearance.hairStyleId, 'none');
    expect(appearance.actorAppearance('default').backHairId, 'medium');
  });
}
