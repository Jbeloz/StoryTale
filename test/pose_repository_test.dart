import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/features/animated_story/data/pose_repository.dart';
import 'package:storytale/src/features/animated_story/data/sprite_rig.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('custom poses survive repository reload and can be deleted', () async {
    final repository = PoseRepository();
    const pose = SpriteRigPose(
      id: 'thinking',
      name: 'Thinking',
      faceExpressionId: 'happy',
      parts: {'head': SpritePartTransform(rotation: 12)},
    );

    await repository.save(pose);
    final restored = await repository.loadAll();

    expect(restored, hasLength(1));
    expect(restored.single.displayName, 'Thinking');
    expect(restored.single.faceExpressionId, 'happy');
    expect(restored.single.transformFor('head').rotation, 12);

    await repository.delete('thinking');
    expect(await repository.loadAll(), isEmpty);
  });

  test('pose names and stable IDs are validated', () {
    expect(SpritePoseRules.nameError('A', const []), isNotNull);
    expect(SpritePoseRules.nameError('Idle', const ['Idle']), isNotNull);
    expect(SpritePoseRules.nameError('Thinking', const ['Idle']), isNull);
    expect(
      SpritePoseRules.createId('Hero Pose', const ['hero_pose']),
      'hero_pose_2',
    );
    expect(SpritePoseRules.validId('../bad'), isFalse);
    expect(SpritePoseRules.validId('hero_pose_2'), isTrue);
  });
}
