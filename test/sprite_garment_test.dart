import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/sprite_appearance.dart';
import 'package:storytale/src/features/animated_story/data/sprite_rig.dart';
import 'package:storytale/src/features/animated_story/presentation/widgets/sprite_rig_view.dart';

/// Guards the V5 clothing layer.
///
/// The rule these tests exist to hold is that a garment is painted **over** a
/// body part and never in place of it. A replacement would render identically
/// at first glance and silently disable the local skin tint, which is the one
/// thing V5 promised would stay local and free.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the garment selection', () {
    test('survives a save and reload with its bytes and fit intact', () {
      var appearance = const SpriteAppearanceSelection();
      appearance = appearance.withGarmentForPart(
        'torso',
        SpriteGarmentLayer(
          partId: 'torso',
          bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
          fit: const SpritePartFit(offsetX: 6, offsetY: -4, scale: 1.2),
          sourceRequestId: 'request-42',
        ),
      );

      final restored = SpriteAppearanceSelection.fromJson(
        jsonDecode(appearance.toJsonString()) as Map<String, dynamic>,
      );

      final garment = restored.garmentForPart('torso');
      expect(garment, isNotNull);
      expect(garment!.bytes, [1, 2, 3, 4, 5]);
      expect(garment.fit.offsetX, 6);
      expect(garment.fit.offsetY, -4);
      expect(garment.fit.scale, 1.2);
      expect(garment.sourceRequestId, 'request-42');
    });

    test('keeps each actor dressed separately', () {
      var appearance = const SpriteAppearanceSelection();
      appearance = appearance.withGarmentForPart(
        'torso',
        SpriteGarmentLayer(partId: 'torso', bytes: Uint8List.fromList([1])),
      );
      appearance = appearance.copyWith(actorId: 'elder');
      expect(appearance.garmentForPart('torso'), isNull);

      appearance = appearance.withGarmentForPart(
        'torso',
        SpriteGarmentLayer(partId: 'torso', bytes: Uint8List.fromList([9])),
      );
      final restored = SpriteAppearanceSelection.fromJson(appearance.toJson());

      expect(restored.garmentForPart('torso')!.bytes, [9]);
      expect(
        restored.copyWith(actorId: 'default').garmentForPart('torso')!.bytes,
        [1],
      );
    });

    test('clearing one part leaves the others dressed', () {
      var appearance = const SpriteAppearanceSelection();
      for (final partId in ['torso', 'upper_arm_left']) {
        appearance = appearance.withGarmentForPart(
          partId,
          SpriteGarmentLayer(partId: partId, bytes: Uint8List.fromList([7])),
        );
      }
      appearance = appearance.withoutGarmentForPart('torso');

      expect(appearance.garmentForPart('torso'), isNull);
      expect(appearance.garmentForPart('upper_arm_left'), isNotNull);
    });

    test('omits the key entirely when nothing is worn', () {
      expect(const SpriteAppearanceSelection().toJson(), isNot(contains('garments')));
    });

    test('a corrupt garment is dropped rather than losing the appearance', () {
      final json = {
        'actorId': 'default',
        'skinTone': '#F2C9A0',
        'garments': {
          'default': {
            'torso': {'bytes': 'not base64 !!'},
            'head': {'bytes': ''},
            'upper_arm_left': {
              'bytes': base64Encode(const [4, 5, 6]),
            },
          },
        },
      };

      final restored = SpriteAppearanceSelection.fromJson(json);

      expect(restored.garmentForPart('torso'), isNull);
      expect(restored.garmentForPart('head'), isNull);
      expect(restored.garmentForPart('upper_arm_left')!.bytes, [4, 5, 6]);
      expect(restored.skinTone, '#F2C9A0');
    });
  });

  group('the rig view', () {
    testWidgets('draws the garment above its body part, not instead of it', (
      tester,
    ) async {
      final rig = await tester.runAsync(
        () => SpriteRigDefinition.load(
          'assets/images/characters/rigs/humanoid_v1/rig.json',
        ),
      );
      final garmentBytes = await tester.runAsync(_fixtureBytes);
      const pose = SpriteRigPose(id: 'neutral');

      await tester.pumpWidget(
        MaterialApp(
          home: SpriteRigView(
            rig: rig!,
            pose: pose,
            skinTone: const Color(0xFFF2C9A0),
            garments: {
              'torso': SpriteGarmentLayer(
                partId: 'torso',
                bytes: garmentBytes!,
              ),
            },
          ),
        ),
      );
      await tester.pump();
      final dressed = _imageCounts(tester);

      // Now the same character with nothing on, for comparison.
      await tester.pumpWidget(
        MaterialApp(
          home: SpriteRigView(
            rig: rig,
            pose: pose,
            skinTone: const Color(0xFFF2C9A0),
          ),
        ),
      );
      await tester.pump();
      final bare = _imageCounts(tester);

      // This is the assertion that distinguishes an overlay from a
      // replacement, and the only reason this test is worth having. Dressing
      // the torso must *add* an image, not swap one: every body part still
      // renders from its own asset, and one garment is added from memory.
      expect(
        dressed.fromMemory,
        bare.fromMemory + 1,
        reason: 'the garment should add exactly one image',
      );
      expect(
        dressed.fromAsset,
        bare.fromAsset,
        reason:
            'no body part may be replaced. A replacement would also disable the '
            'skin tint, because _canTint refuses a part whose pixels were '
            'overridden',
      );
    });

    testWidgets('renders the character unchanged when nothing is worn', (
      tester,
    ) async {
      final rig = await tester.runAsync(
        () => SpriteRigDefinition.load(
          'assets/images/characters/rigs/humanoid_v1/rig.json',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SpriteRigView(
            rig: rig!,
            pose: const SpriteRigPose(id: 'neutral'),
          ),
        ),
      );
      await tester.pump();

      final memoryImages = tester
          .widgetList<Image>(find.byType(Image))
          .where((widget) => widget.image is MemoryImage);
      expect(memoryImages, isEmpty);
    });
  });
}

({int fromMemory, int fromAsset}) _imageCounts(WidgetTester tester) {
  final images = tester.widgetList<Image>(find.byType(Image));
  return (
    fromMemory: images.where((widget) => widget.image is MemoryImage).length,
    fromAsset: images.where((widget) => widget.image is AssetImage).length,
  );
}

Future<Uint8List> _fixtureBytes() async {
  // A real owner-drawn example rather than a placeholder, so this test exercises
  // the artwork the app actually ships.
  final data = await rootBundle.load(
    'assets/images/characters/garment_fixtures/v5/pieces/torso.png',
  );
  return data.buffer.asUint8List();
}
