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
    expect(bones.singleWhere((bone) => bone.isRoot).partId, 'torso');
    final upperArm = bones.singleWhere(
      (bone) => bone.partId == 'upper_arm_right',
    );
    expect(upperArm.end, transforms['lower_arm_right']!.pivot);
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
      'layerPolicyVersion': 1,
      'parts': <String, dynamic>{},
    });

    expect(pose.displayName, 'Test Pose');
    expect(pose.rigId, 'humanoid_v1');
    expect(pose.faceExpressionId, 'happy');
    expect(pose.toJson()['faceExpressionId'], 'happy');
    expect(pose.toJson()['layerPolicyVersion'], 1);
    expect(
      pose.update('head', const SpritePartTransform()).faceExpressionId,
      'happy',
    );
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
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: SpritePositionerPage()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

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
    await tester.pump();

    expect(find.byKey(const Key('desktopStudio')), findsOneWidget);
    expect(find.byKey(const Key('rotationInput')), findsOneWidget);
    expect(find.byKey(const Key('xInput')), findsOneWidget);
    expect(find.byKey(const Key('yInput')), findsOneWidget);

    await tester.tap(find.byKey(const Key('face-happy')));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('face-happy'))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('undoButton')));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('face-neutral'))).selected,
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
