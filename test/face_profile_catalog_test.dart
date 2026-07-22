import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/face_profile_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalogAsset = 'assets/images/characters/face_profiles/catalog.json';

  test(
    'bundled catalog loads all five profiles with a safe fallback',
    () async {
      final catalog = await SpriteFaceProfileCatalog.load(catalogAsset);

      expect(catalog.profiles, hasLength(5));
      expect(catalog.profiles.last.label, 'Adult');
      expect(catalog.resolveProfileId('heroine'), 'heroine');
      expect(catalog.resolveProfileId('missing'), 'default');
    },
  );

  test('heroine sets resolve into the fixed modular layer order', () async {
    final catalog = await SpriteFaceProfileCatalog.load(catalogAsset);
    final bundle = await catalog.loadProfile('heroine');
    final composition = bundle.compositionFor('happy');

    expect(bundle.profile.canvasWidth, 1254);
    expect(bundle.profile.canvasHeight, 1254);
    expect(bundle.profile.status, 'ready');
    expect(bundle.sets.sets, hasLength(6));
    expect(composition.profileId, 'heroine');
    expect(composition.setId, 'happy');
    expect(composition.layerAssets, [
      'assets/images/characters/face_profiles/heroine/eyes/happy.png',
      'assets/images/characters/face_profiles/heroine/noses/default.png',
      'assets/images/characters/face_profiles/heroine/mouths/smile.png',
      'assets/images/characters/face_profiles/heroine/details/soft_blush.png',
    ]);
  });

  test('legacy expressions and speaking use safe set fallbacks', () async {
    final catalog = await SpriteFaceProfileCatalog.load(catalogAsset);
    final bundle = await catalog.loadProfile('heroine');

    expect(
      bundle.sets.resolveSetId(null, legacyExpressionId: 'angry'),
      'angry',
    );
    expect(bundle.sets.resolveSetId('neutral', isSpeaking: true), 'talking');
    expect(bundle.sets.resolveSetId('angry', isSpeaking: true), 'angry');
    expect(bundle.sets.resolveSetId('missing'), 'neutral');
  });

  test('elder and adult profiles append their detail overlays last', () async {
    final catalog = await SpriteFaceProfileCatalog.load(catalogAsset);
    final elder = await catalog.loadProfile('elder');
    final adult = await catalog.loadProfile('adult_deep');

    expect(
      elder.compositionFor('neutral').layerAssets.last,
      'assets/images/characters/face_profiles/elder/details/wrinkles.png',
    );
    expect(
      adult.compositionFor('neutral').layerAssets.last,
      'assets/images/characters/face_profiles/adult_deep/details/adult_lines.png',
    );
  });
}
