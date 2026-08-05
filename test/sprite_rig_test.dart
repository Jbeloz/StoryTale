import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/features/animated_story/data/sprite_face_catalog.dart';
import 'package:storytale/src/features/animated_story/data/sprite_rig.dart';
import 'package:storytale/src/features/animated_story/presentation/sprite_positioner_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a child joint follows its rotated parent', () {
    final rig = SpriteRigDefinition.fromJson({
      'id': 'test',
      'canvas': {'width': 100, 'height': 100},
      'parts': [
        {
          'id': 'root',
          'label': 'Root',
          'asset': 'root.png',
          'parent': null,
          'position': {'x': 0, 'y': 0},
          'pivot': {'x': 0, 'y': 0},
          'size': {'width': 10, 'height': 10},
          'z': 0,
        },
        {
          'id': 'child',
          'label': 'Child',
          'asset': 'child.png',
          'parent': 'root',
          'position': {'x': 10, 'y': 0},
          'pivot': {'x': 10, 'y': 0},
          'size': {'width': 10, 'height': 10},
          'z': 1,
        },
      ],
    });
    final pose = const SpriteRigPose(
      id: 'test',
    ).update('root', const SpritePartTransform(rotation: 90));

    final result = SpriteRigCalculator.calculate(rig, pose);

    expect(result['child']!.pivot.dx, closeTo(0, 0.001));
    expect(result['child']!.pivot.dy, closeTo(10, 0.001));
    expect(result['child']!.rotation, closeTo(math.pi / 2, 0.001));
  });

  testWidgets('the humanoid rig derives one root and nine bones', (
    tester,
  ) async {
    final rig = await tester.runAsync(
      () => SpriteRigDefinition.load(
        'assets/images/characters/rigs/humanoid_v1/rig.json',
      ),
    );
    expect(rig, isNotNull);
    const pose = SpriteRigPose(id: 'neutral');
    final bones = SpriteBoneCalculator.calculate(rig!, pose);
    final transforms = SpriteRigCalculator.calculate(rig, pose);

    expect(bones, hasLength(10));
    expect(rig.partsById['front_hair']?.label, 'Front hair');
    expect(rig.partsById['front_hair']?.parentId, 'head');
    expect(rig.partsById['front_hair']?.hasBone, isFalse);
    expect(rig.partsById['back_hair']?.label, 'Back hair');
    expect(rig.partsById['back_hair']?.parentId, 'head');
    expect(rig.partsById['back_hair']?.hasBone, isFalse);
    expect(bones.where((bone) => bone.partId == 'front_hair'), isEmpty);
    expect(bones.where((bone) => bone.partId == 'back_hair'), isEmpty);
    expect(bones.singleWhere((bone) => bone.isRoot).partId, 'torso');
    final upperArm = bones.singleWhere(
      (bone) => bone.partId == 'upper_arm_right',
    );
    expect(upperArm.end, transforms['lower_arm_right']!.pivot);
  });

  testWidgets('front hair follows the head but keeps its own adjustment', (
    tester,
  ) async {
    final rig = await tester.runAsync(
      () => SpriteRigDefinition.load(
        'assets/images/characters/rigs/humanoid_v1/rig.json',
      ),
    );
    expect(rig, isNotNull);

    const base = SpriteRigPose(id: 'neutral');
    final original = SpriteRigCalculator.calculate(rig!, base);
    final movedHead = base.update(
      'head',
      const SpritePartTransform(offsetX: 24, offsetY: -12),
    );
    final withMovedHead = SpriteRigCalculator.calculate(rig, movedHead);

    expect(
      withMovedHead['front_hair']!.pivot - original['front_hair']!.pivot,
      const Offset(24, -12),
    );
    expect(
      withMovedHead['back_hair']!.pivot - original['back_hair']!.pivot,
      const Offset(24, -12),
    );

    final adjustedHair = movedHead.update(
      'front_hair',
      const SpritePartTransform(offsetX: 8, offsetY: 6),
    );
    final withAdjustedHair = SpriteRigCalculator.calculate(rig, adjustedHair);

    expect(withAdjustedHair['head']!.pivot, withMovedHead['head']!.pivot);
    expect(
      withAdjustedHair['front_hair']!.pivot -
          withMovedHead['front_hair']!.pivot,
      const Offset(8, 6),
    );
    expect(
      withAdjustedHair['back_hair']!.pivot,
      withMovedHead['back_hair']!.pivot,
    );
  });

  test('bone dragging rotates around its joint and respects its limit', () {
    const range = SpriteRotationRange(min: -45, max: 45);

    final rotation = SpriteBoneCalculator.rotationFromDrag(
      initialRotation: 0,
      pivot: Offset.zero,
      initialPointer: const Offset(10, 0),
      pointer: const Offset(0, 10),
      range: range,
    );

    expect(rotation, 45);
  });

  testWidgets('the face catalog has five safe reusable expressions', (
    tester,
  ) async {
    final catalog = await tester.runAsync(
      () => SpriteFaceCatalog.load(
        'assets/images/characters/rigs/humanoid_v1/faces/catalog.json',
      ),
    );

    expect(catalog, isNotNull);
    expect(catalog!.expressions, hasLength(5));
    expect(catalog.resolveId('missing'), 'neutral');
    expect(catalog.resolveId('neutral', isSpeaking: true), 'talking');
    expect(catalog.resolveId('angry', isSpeaking: true), 'angry');
  });

  test('a pose saves and restores its face expression', () {
    final pose = SpriteRigPose.fromJson({
      'id': 'test',
      'name': 'Test Pose',
      'rigId': 'humanoid_v1',
      'faceExpressionId': 'happy',
      'faceProfileId': 'heroine',
      'faceSetId': 'happy',
      'layerPolicyVersion': 1,
      'parts': <String, dynamic>{},
    });

    expect(pose.displayName, 'Test Pose');
    expect(pose.rigId, 'humanoid_v1');
    expect(pose.faceExpressionId, 'happy');
    expect(pose.faceProfileId, 'heroine');
    expect(pose.faceSetId, 'happy');
    expect(pose.toJson()['faceExpressionId'], 'happy');
    expect(pose.toJson()['faceProfileId'], 'heroine');
    expect(pose.toJson()['layerPolicyVersion'], 1);
    expect(
      pose.update('head', const SpritePartTransform()).faceExpressionId,
      'happy',
    );
  });

  test('an attachment pose saves and restores its size', () {
    final pose = SpriteRigPose.fromJson({
      'id': 'test',
      'name': 'Test Pose',
      'rigId': 'humanoid_v1',
      'faceExpressionId': 'neutral',
      'parts': {
        'front_hair': {'rotation': 0, 'x': 12, 'y': -8, 'scale': 1.25},
      },
    });

    final hair = pose.transformFor('front_hair');
    expect(hair.offsetX, 12);
    expect(hair.offsetY, -8);
    expect(hair.scale, 1.25);
    expect((pose.toJson()['parts'] as Map)['front_hair']['scale'], 1.25);
  });

  testWidgets('the arm layers use the approved overlap order', (tester) async {
    final rig = await tester.runAsync(
      () => SpriteRigDefinition.load(
        'assets/images/characters/rigs/humanoid_v1/rig.json',
      ),
    );
    expect(rig, isNotNull);

    final parts = {for (final part in rig!.parts) part.id: part.z};
    expect(parts['upper_arm_right'], greaterThan(parts['lower_arm_right']!));
    expect(parts['upper_arm_right'], greaterThan(parts['torso']!));
    expect(parts['lower_arm_left'], lessThan(parts['upper_arm_left']!));
    expect(parts['lower_arm_left'], lessThan(parts['torso']!));
  });

  testWidgets('the four approved poses load', (tester) async {
    for (final name in ['neutral', 'talking', 'pointing', 'walking']) {
      final pose = await tester.runAsync(
        () => SpriteRigPose.load(
          'assets/images/characters/rigs/humanoid_v1/poses/$name.json',
        ),
      );
      expect(pose?.id, name);
    }
  });

  testWidgets('fixed body layers cannot be overridden by a pose', (
    tester,
  ) async {
    final rig = await tester.runAsync(
      () => SpriteRigDefinition.load(
        'assets/images/characters/rigs/humanoid_v1/rig.json',
      ),
    );
    expect(rig, isNotNull);
    const pose = SpriteRigPose(
      id: 'test',
      parts: {'lower_leg_right': SpritePartTransform(layer: 999)},
    );
    final part = rig!.partsById['lower_leg_right']!;

    expect(
      SpriteLayerPolicy.effectiveLayer(part, pose.transformFor(part.id)),
      part.z,
    );
    expect(
      SpriteLayerPolicy.normalize(pose).transformFor('lower_leg_right').layer,
      isNull,
    );
  });

  testWidgets('Sprite Studio has responsive editing and undo redo', (
    tester,
  ) async {
    // Pin the Default actor. Without this the studio falls back to the project
    // appearance asset, whose actor decides the face chip keys.
    SharedPreferences.setMockInitialValues({
      'sprite_studio.humanoid_v1.appearance': '{"actorId":"default"}',
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: SpritePositionerPage()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sprite Studio'), findsOneWidget);
    expect(find.byKey(const Key('mobileStudio')), findsOneWidget);
    expect(find.byKey(const Key('spriteCanvas')), findsOneWidget);
    expect(find.byKey(const Key('spriteInspector')), findsOneWidget);
    expect(find.text('Save session'), findsOneWidget);
    expect(find.byKey(const Key('showBonesSwitch')), findsOneWidget);
    expect(find.byKey(const Key('boneModeSwitch')), findsOneWidget);
    expect(find.byKey(const Key('face-neutral')), findsOneWidget);
    expect(find.byKey(const Key('face-talking')), findsOneWidget);
    expect(find.byKey(const Key('face-happy')), findsOneWidget);
    expect(find.byKey(const Key('face-sad')), findsOneWidget);
    expect(find.byKey(const Key('face-angry')), findsOneWidget);
    expect(find.byKey(const Key('faceProfileSelector')), findsOneWidget);
    expect(find.byKey(const Key('newFaceSetButton')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('boneModeSwitch')));
    await tester.tap(find.byKey(const Key('boneModeSwitch')));
    await tester.pump();
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('boneModeSwitch')))
          .value,
      isTrue,
    );

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(const MaterialApp(home: SpritePositionerPage()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktopStudio')), findsOneWidget);
    expect(find.byKey(const Key('rotationInput')), findsOneWidget);
    expect(find.byKey(const Key('xInput')), findsOneWidget);
    expect(find.byKey(const Key('yInput')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('newFaceSetButton')));
    await tester.tap(find.byKey(const Key('newFaceSetButton')));
    await tester.pumpAndSettle();

    expect(find.text('Set Maker'), findsOneWidget);
    expect(find.byKey(const Key('faceEyesPicker')), findsOneWidget);
    expect(find.byKey(const Key('faceNosePicker')), findsOneWidget);
    expect(find.byKey(const Key('faceMouthPicker')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('faceSetNameInput')), 'Gentle');
    await tester.tap(find.byKey(const Key('saveFaceSetButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('face-gentle')), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('face-gentle'))).selected,
      isTrue,
    );

    await tester.ensureVisible(find.byKey(const Key('face-happy')));
    await tester.tap(find.byKey(const Key('face-happy')));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('face-happy'))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('undoButton')));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('face-gentle'))).selected,
      isTrue,
    );

    await tester.enterText(find.byKey(const Key('rotationInput')), '30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('Rotation 30°'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undoButton')));
    await tester.pump();
    expect(find.textContaining('Rotation 0°'), findsOneWidget);

    await tester.tap(find.byKey(const Key('redoButton')));
    await tester.pump();
    expect(find.textContaining('Rotation 30°'), findsOneWidget);
  });
}
