import '../../../shared/models/storytale_models.dart';
import 'face_profile_catalog.dart';
import 'pose_repository.dart';
import 'sprite_face_catalog.dart';
import 'sprite_rig.dart';

typedef StoryRigLoader = Future<SpriteRigDefinition> Function(String rigId);
typedef StoryFaceLoader = Future<SpriteFaceCatalog> Function(String rigId);
typedef StoryPoseLoader = Future<List<SpriteRigPose>> Function(String rigId);
typedef StoryFaceProfileLoader =
    Future<SpriteFaceProfileBundle> Function(String? profileId);

class ResolvedStoryCharacter {
  const ResolvedStoryCharacter({
    required this.rig,
    required this.pose,
    required this.faceCatalog,
    required this.faceComposition,
    required this.usedNeutralFallback,
  });

  final SpriteRigDefinition rig;
  final SpriteRigPose pose;
  final SpriteFaceCatalog faceCatalog;
  final SpriteFaceComposition? faceComposition;
  final bool usedNeutralFallback;
}

class StoryPoseMapper {
  const StoryPoseMapper._();

  static String fromAnalyzerTag(String value) {
    final tag = value.trim().toLowerCase().replaceAll('-', ' ');
    if (tag.contains('talk') ||
        tag.contains('speak') ||
        tag.contains('dialogue')) {
      return 'talking';
    }
    if (tag.contains('point') ||
        tag.contains('indicate') ||
        tag.contains('gesture')) {
      return 'pointing';
    }
    if (tag.contains('walk') ||
        tag.contains('move') ||
        tag.contains('enter') ||
        tag.contains('exit')) {
      return 'walking';
    }
    return 'neutral';
  }

  static StoryCharacterLayerData fromAnalyzer({
    required String characterId,
    required String poseTag,
    String rigId = 'humanoid_v1',
    String faceExpressionId = 'neutral',
    String? faceProfileId,
    String? faceSetId,
    String stagePosition = 'center',
    String movement = 'idle',
    bool isSpeaking = false,
  }) {
    return StoryCharacterLayerData(
      characterId: characterId,
      rigId: rigId,
      poseId: fromAnalyzerTag(poseTag),
      faceExpressionId: faceExpressionId,
      faceProfileId: faceProfileId,
      faceSetId: faceSetId,
      stagePosition: stagePosition,
      movement: movement,
      isSpeaking: isSpeaking,
    );
  }
}

class StoryPoseResolver {
  StoryPoseResolver({
    StoryRigLoader? loadRig,
    StoryFaceLoader? loadFaceCatalog,
    StoryPoseLoader? loadPoses,
    StoryFaceProfileLoader? loadFaceProfile,
  }) : _loadRig = loadRig ?? _defaultRigLoader,
       _loadFaceCatalog = loadFaceCatalog ?? _defaultFaceLoader,
       _loadPoses = loadPoses ?? _defaultPoseLoader,
       _loadFaceProfile = loadFaceProfile ?? _defaultFaceProfileLoader;

  final StoryRigLoader _loadRig;
  final StoryFaceLoader _loadFaceCatalog;
  final StoryPoseLoader _loadPoses;
  final StoryFaceProfileLoader _loadFaceProfile;

  Future<ResolvedStoryCharacter?> resolve(StoryCharacterLayerData layer) async {
    try {
      final results = await Future.wait<Object>([
        _loadRig(layer.rigId),
        _loadFaceCatalog(layer.rigId),
        _loadPoses(layer.rigId),
      ]);
      final rig = results[0] as SpriteRigDefinition;
      final faceCatalog = results[1] as SpriteFaceCatalog;
      final poses = results[2] as List<SpriteRigPose>;
      if (rig.id != layer.rigId || !rig.partsById.containsKey('head')) {
        return null;
      }

      final requested = poses
          .where((pose) => pose.id == layer.poseId)
          .firstOrNull;
      final fallback = poses.where((pose) => pose.id == 'neutral').firstOrNull;
      var pose = _isCompatible(requested, rig) ? requested : fallback;
      if (!_isCompatible(pose, rig)) return null;

      final faceId = faceCatalog.resolveId(
        layer.faceExpressionId,
        isSpeaking: layer.isSpeaking,
      );
      pose = SpriteLayerPolicy.normalize(pose!.withFaceExpression(faceId));
      final faceComposition = await _resolveFaceComposition(layer, rig, pose);
      return ResolvedStoryCharacter(
        rig: rig,
        pose: pose,
        faceCatalog: faceCatalog,
        faceComposition: faceComposition,
        usedNeutralFallback: requested == null || requested.id != pose.id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SpriteFaceComposition?> _resolveFaceComposition(
    StoryCharacterLayerData layer,
    SpriteRigDefinition rig,
    SpriteRigPose pose,
  ) async {
    try {
      final bundle = await _loadFaceProfile(
        layer.faceProfileId ?? pose.faceProfileId,
      );
      if (!bundle.profile.isReady ||
          bundle.profile.rigId != rig.id ||
          !rig.partsById.containsKey(bundle.profile.headPartId)) {
        return null;
      }
      return bundle.compositionFor(
        layer.faceSetId ?? pose.faceSetId,
        legacyExpressionId: layer.faceExpressionId,
        isSpeaking: layer.isSpeaking,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isCompatible(SpriteRigPose? pose, SpriteRigDefinition rig) {
    if (pose == null || pose.rigId != rig.id || pose.layerPolicyVersion != 1) {
      return false;
    }
    for (final entry in pose.parts.entries) {
      if (!rig.partsById.containsKey(entry.key)) return false;
      final value = entry.value;
      if (!value.rotation.isFinite ||
          !value.offsetX.isFinite ||
          !value.offsetY.isFinite) {
        return false;
      }
    }
    return true;
  }

  static Future<SpriteRigDefinition> _defaultRigLoader(String rigId) {
    return SpriteRigDefinition.load(
      'assets/images/characters/rigs/$rigId/rig.json',
    );
  }

  static Future<SpriteFaceCatalog> _defaultFaceLoader(String rigId) {
    return SpriteFaceCatalog.load(
      'assets/images/characters/rigs/$rigId/faces/catalog.json',
    );
  }

  static Future<List<SpriteRigPose>> _defaultPoseLoader(String rigId) {
    return PoseRepository(rigId: rigId).loadApprovedPoses();
  }

  static Future<SpriteFaceProfileBundle> _defaultFaceProfileLoader(
    String? profileId,
  ) async {
    final catalog = await SpriteFaceProfileCatalog.load(
      'assets/images/characters/face_profiles/catalog.json',
    );
    return catalog.loadProfile(profileId);
  }
}
