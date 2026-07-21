import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/features/animated_story/data/sprite_face_catalog.dart';
import 'package:storytale/src/features/animated_story/data/sprite_rig.dart';
import 'package:storytale/src/features/animated_story/data/story_pose_resolver.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('analyzer tags map to the four approved poses', () {
    expect(StoryPoseMapper.fromAnalyzerTag('standing calmly'), 'neutral');
    expect(StoryPoseMapper.fromAnalyzerTag('speaking dialogue'), 'talking');
    expect(StoryPoseMapper.fromAnalyzerTag('points ahead'), 'pointing');
    expect(StoryPoseMapper.fromAnalyzerTag('walks into view'), 'walking');
    expect(StoryPoseMapper.fromAnalyzerTag('unsupported action'), 'neutral');
  });

  test('character layer keeps replaceable character and rig IDs', () {
    final layer = StoryCharacterLayerData.fromJson({
      'characterId': 'volume_1_heroine',
      'rigId': 'volume_1_heroine_v1',
      'poseId': 'talking',
      'faceExpressionId': 'happy',
      'outfitId': 'academy_uniform',
      'stagePosition': 'right',
      'movement': 'enter right',
      'isSpeaking': true,
    });

    expect(layer.rigId, 'volume_1_heroine_v1');
    expect(layer.toJson()['outfitId'], 'academy_uniform');
  });

  test('missing pose and face safely fall back to neutral', () async {
    final resolver = _resolver('book_hero_v1');
    final resolved = await resolver.resolve(
      const StoryCharacterLayerData(
        characterId: 'book_hero',
        rigId: 'book_hero_v1',
        poseId: 'missing_pose',
        faceExpressionId: 'missing_face',
      ),
    );

    expect(resolved, isNotNull);
    expect(resolved!.pose.id, 'neutral');
    expect(resolved.pose.faceExpressionId, 'neutral');
    expect(resolved.usedNeutralFallback, isTrue);
  });

  test('neutral face becomes talking only while the layer speaks', () async {
    final resolved = await _resolver('book_hero_v1').resolve(
      const StoryCharacterLayerData(
        characterId: 'book_hero',
        rigId: 'book_hero_v1',
        poseId: 'talking',
        isSpeaking: true,
      ),
    );

    expect(resolved!.pose.faceExpressionId, 'talking');
  });

  test('an incompatible rig is hidden instead of partly rendered', () async {
    final resolver = _resolver('different_rig');
    final resolved = await resolver.resolve(
      const StoryCharacterLayerData(
        characterId: 'book_hero',
        rigId: 'requested_rig',
        poseId: 'neutral',
      ),
    );

    expect(resolved, isNull);
  });

  testWidgets('the test chapter poses resolve from project assets', (
    tester,
  ) async {
    final resolver = StoryPoseResolver();
    for (final poseId in ['neutral', 'talking', 'pointing', 'walking']) {
      final resolved = await tester.runAsync(
        () => resolver.resolve(
          StoryCharacterLayerData(
            characterId: 'little_prince',
            rigId: 'humanoid_v1',
            poseId: poseId,
            isSpeaking: poseId == 'talking',
          ),
        ),
      );
      expect(resolved?.pose.id, poseId);
    }
  });
}

StoryPoseResolver _resolver(String rigId) {
  final rig = SpriteRigDefinition(
    id: rigId,
    canvasSize: const Size(100, 100),
    parts: const [
      SpriteRigPart(
        id: 'torso',
        label: 'Torso',
        asset: 'torso.png',
        parentId: null,
        position: Offset.zero,
        pivot: Offset.zero,
        size: Size(40, 60),
        z: 1,
      ),
      SpriteRigPart(
        id: 'head',
        label: 'Head',
        asset: 'head.png',
        parentId: 'torso',
        position: Offset.zero,
        pivot: Offset.zero,
        size: Size(40, 40),
        z: 2,
      ),
    ],
  );
  final catalog = SpriteFaceCatalog(
    id: '${rigId}_faces',
    headPartId: 'head',
    defaultExpressionId: 'neutral',
    expressions: const [
      SpriteFaceExpression(id: 'neutral', label: 'Neutral', asset: 'n.png'),
      SpriteFaceExpression(id: 'talking', label: 'Talking', asset: 't.png'),
    ],
  );
  final poses = [
    SpriteRigPose(id: 'neutral', rigId: rigId),
    SpriteRigPose(id: 'talking', rigId: rigId),
  ];
  return StoryPoseResolver(
    loadRig: (_) async => rig,
    loadFaceCatalog: (_) async => catalog,
    loadPoses: (_) async => poses,
  );
}
