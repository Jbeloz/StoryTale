import '../../../shared/models/storytale_models.dart';
import 'story_background_repository.dart';
import 'story_bible_models.dart';
import 'story_foreground_repository.dart';

class StoryAnalysisCharacter {
  const StoryAnalysisCharacter({
    required this.id,
    required this.name,
    required this.rigIds,
    required this.poseIds,
    required this.faceProfileIds,
    required this.faceSetIds,
  });

  final String id;
  final String name;
  final List<String> rigIds;
  final List<String> poseIds;
  final List<String> faceProfileIds;
  final List<String> faceSetIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rigIds': rigIds,
    'poseIds': poseIds,
    'faceProfileIds': faceProfileIds,
    'faceSetIds': faceSetIds,
  };
}

class StoryAnalysisLocation {
  const StoryAnalysisLocation({
    required this.id,
    required this.name,
    required this.backgroundBrief,
    this.parentSetting,
  });

  final String id;
  final String name;
  final String backgroundBrief;
  final String? parentSetting;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'backgroundBrief': backgroundBrief,
    if (parentSetting != null) 'parentSetting': parentSetting,
  };
}

class StoryAnalysisBackgroundAsset {
  const StoryAnalysisBackgroundAsset({
    required this.assetId,
    required this.locationId,
    required this.stateId,
  });

  final String assetId;
  final String locationId;
  final String stateId;

  Map<String, dynamic> toJson() => {
    'assetId': assetId,
    'locationId': locationId,
    'stateId': stateId,
  };
}

class StoryAnalysisForegroundAsset {
  const StoryAnalysisForegroundAsset({
    required this.entityId,
    required this.assetId,
    required this.variantId,
    required this.name,
    required this.kind,
    required this.sourceBlockIds,
    this.aliases = const [],
  });

  final String entityId;
  final String assetId;
  final String variantId;
  final String name;
  final String kind;
  final List<String> sourceBlockIds;
  final List<String> aliases;

  Map<String, dynamic> toJson() => {
    'entityId': entityId,
    'assetId': assetId,
    'variantId': variantId,
    'name': name,
    'kind': kind,
    'sourceBlockIds': sourceBlockIds,
    'aliases': aliases,
  };
}

class StoryAnalysisCatalog {
  const StoryAnalysisCatalog({
    required this.characters,
    required this.backgroundIds,
    required this.locations,
    this.backgroundAssets = const [],
    this.foregroundAssets = const [],
  });

  final List<StoryAnalysisCharacter> characters;
  final List<String> backgroundIds;
  final List<StoryAnalysisLocation> locations;
  final List<StoryAnalysisBackgroundAsset> backgroundAssets;
  final List<StoryAnalysisForegroundAsset> foregroundAssets;

  List<String> get locationIds =>
      locations.map((location) => location.id).toList(growable: false);

  static const prototype = StoryAnalysisCatalog(
    characters: [
      StoryAnalysisCharacter(
        id: 'default_actor',
        name: 'Narrator',
        rigIds: ['humanoid_v1'],
        poseIds: ['neutral', 'talking', 'pointing', 'walking'],
        faceProfileIds: ['default'],
        faceSetIds: [
          'neutral',
          'talking',
          'happy',
          'sad',
          'angry',
          'surprised',
        ],
      ),
      StoryAnalysisCharacter(
        id: 'hero_actor',
        name: 'Hero',
        rigIds: ['humanoid_v1'],
        poseIds: ['neutral', 'talking', 'pointing', 'walking'],
        faceProfileIds: ['hero'],
        faceSetIds: [
          'neutral',
          'talking',
          'happy',
          'sad',
          'angry',
          'surprised',
        ],
      ),
      StoryAnalysisCharacter(
        id: 'heroine_actor',
        name: 'Heroine',
        rigIds: ['humanoid_v1'],
        poseIds: ['neutral', 'talking', 'pointing', 'walking'],
        faceProfileIds: ['heroine'],
        faceSetIds: [
          'neutral',
          'talking',
          'happy',
          'sad',
          'angry',
          'surprised',
        ],
      ),
      StoryAnalysisCharacter(
        id: 'elder_actor',
        name: 'Elder',
        rigIds: ['humanoid_v1'],
        poseIds: ['neutral', 'talking', 'pointing', 'walking'],
        faceProfileIds: ['elder'],
        faceSetIds: [
          'neutral',
          'talking',
          'happy',
          'sad',
          'angry',
          'surprised',
        ],
      ),
      StoryAnalysisCharacter(
        id: 'adult_actor',
        name: 'Adult',
        rigIds: ['humanoid_v1'],
        poseIds: ['neutral', 'talking', 'pointing', 'walking'],
        faceProfileIds: ['adult_deep'],
        faceSetIds: [
          'neutral',
          'talking',
          'happy',
          'sad',
          'angry',
          'surprised',
        ],
      ),
    ],
    backgroundIds: ['moonlit_rose_garden'],
    backgroundAssets: [
      StoryAnalysisBackgroundAsset(
        assetId: 'moonlit_rose_garden',
        locationId: 'moonlit_rose_garden',
        stateId: 'unspecified',
      ),
    ],
    locations: [
      StoryAnalysisLocation(
        id: 'moonlit_rose_garden',
        name: 'Moonlit rose garden',
        backgroundBrief: 'A moonlit path surrounded by rose bushes.',
      ),
    ],
  );

  factory StoryAnalysisCatalog.fromStoryBible(BookStoryBibleData bible) {
    final locations = bible.entities
        .where(
          (entity) =>
              entity.kind == StoryEntityKind.location &&
              entity.approved &&
              entity.sceneLocation &&
              (entity.backgroundBrief?.trim().isNotEmpty ?? false),
        )
        .map(
          (entity) => StoryAnalysisLocation(
            id: entity.entityId,
            name: entity.canonicalName,
            parentSetting: entity.parentSetting,
            backgroundBrief: entity.backgroundBrief!,
          ),
        )
        .toList(growable: false);
    return StoryAnalysisCatalog(
      characters: prototype.characters,
      backgroundIds: prototype.backgroundIds,
      locations: locations.isEmpty ? prototype.locations : locations,
    );
  }

  factory StoryAnalysisCatalog.fromPreparedAssets({
    required BookStoryBibleData bible,
    required String chapterId,
    required List<StoryBackgroundAssetData> backgrounds,
    required List<StoryForegroundAssetData> foregrounds,
  }) {
    final base = StoryAnalysisCatalog.fromStoryBible(bible);
    final entities = {
      for (final entity in bible.entities)
        if (entity.approved) entity.entityId: entity,
    };
    final readyBackgrounds = [
      for (final asset in backgrounds)
        if (asset.approved &&
            asset.isVisualNovelSize &&
            asset.hasBytes &&
            (asset.chapterIds.isEmpty || asset.chapterIds.contains(chapterId)))
          StoryAnalysisBackgroundAsset(
            assetId: asset.assetId,
            locationId: asset.locationId,
            stateId: asset.stateId,
          ),
    ];
    final readyForegrounds = [
      for (final asset in foregrounds)
        if (asset.status == StoryForegroundAssetStatus.approved &&
            asset.hasBytes &&
            (asset.chapterIds.isEmpty || asset.chapterIds.contains(chapterId)))
          if (entities[asset.entityId] case final entity?)
            StoryAnalysisForegroundAsset(
              entityId: asset.entityId,
              assetId: asset.assetId,
              variantId: asset.variantId,
              name: entity.canonicalName,
              aliases: entity.aliases,
              kind: entity.kind.name,
              sourceBlockIds: entity.sourceBlockIds,
            ),
    ];
    return StoryAnalysisCatalog(
      characters: const [],
      backgroundIds: readyBackgrounds
          .map((asset) => asset.assetId)
          .toList(growable: false),
      backgroundAssets: readyBackgrounds,
      foregroundAssets: readyForegrounds,
      locations: base.locations,
    );
  }

  Map<String, dynamic> toJson() => {
    'characters': characters
        .map((character) => character.toJson())
        .toList(growable: false),
    'backgroundIds': backgroundIds,
    'backgroundAssets': backgroundAssets
        .map((asset) => asset.toJson())
        .toList(growable: false),
    'foregroundAssets': foregroundAssets
        .map((asset) => asset.toJson())
        .toList(growable: false),
    'locations': locations
        .map((location) => location.toJson())
        .toList(growable: false),
    'layoutIds': StoryAnalysisContract.layoutIds,
    'cameraPresetIds': StoryAnalysisContract.cameraPresetIds,
    'transitionIds': StoryAnalysisContract.transitionIds,
    'stagePositions': StoryAnalysisContract.stagePositions,
    'scaleIds': StoryAnalysisContract.scaleIds,
    'facingIds': StoryAnalysisContract.facingIds,
    'depthIds': StoryAnalysisContract.depthIds,
    'movementIds': StoryAnalysisContract.movementIds,
    'backgroundStateIds': StoryAnalysisContract.backgroundStateIds,
  };
}

class StoryAnalysisContract {
  const StoryAnalysisContract._();

  static const layoutIds = [
    'background_establishing',
    'object_detail',
    'solo_center_full',
    'solo_left_full',
    'solo_right_full',
    'solo_medium',
    'solo_close_reaction',
    'two_balanced',
    'two_left_cluster',
    'two_right_cluster',
    'speaker_focus_left',
    'speaker_focus_right',
    'depth_pair',
    'group_three',
    'entrance_exit',
    'travel_walking',
    'pointing_reveal',
    'conflict_impact',
    'quiet_emotional',
    'memory_dream',
    'ending_moral',
  ];
  static const cameraPresetIds = [
    'camera_static',
    'camera_push_in_slow',
    'camera_pull_out_slow',
    'camera_pan_left_slow',
    'camera_pan_right_slow',
    'camera_drift_left',
    'camera_drift_right',
    'camera_snap_in',
    'camera_shake_short',
  ];
  static const transitionIds = [
    'cut',
    'fade',
    'fade_in',
    'slide_left',
    'slide_right',
  ];
  static const stagePositions = ['left', 'center', 'right'];
  static const scaleIds = ['background', 'full', 'medium', 'close'];
  static const facingIds = ['left', 'right', 'front'];
  static const depthIds = ['back', 'normal', 'front'];
  static const movementIds = [
    'none',
    'idle',
    'enter_left',
    'enter_right',
    'exit_left',
    'exit_right',
    'walk_left',
    'walk_right',
    'step_forward',
    'step_back',
    'focus_speaker',
    'idle_breathe',
    'gentle_bob',
    'reaction_pop',
    'fade_in',
    'fade_out',
  ];
  static const backgroundStateIds = [
    'unspecified',
    'dawn',
    'day',
    'sunset',
    'night',
    'rain',
    'storm',
    'snow',
    'damaged',
  ];

  static List<ChapterTextBlock> blocksFor(ChapterData chapter) {
    if (chapter.sourceBlocks.isNotEmpty) return chapter.sourceBlocks;
    final paragraphs = chapter.originalText
        .split(RegExp(r'\n\s*\n'))
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    if (paragraphs.isEmpty) {
      return [
        ChapterTextBlock(id: '${chapter.id}-block-1', text: chapter.title),
      ];
    }
    return List.generate(
      paragraphs.length,
      (index) => ChapterTextBlock(
        id: '${chapter.id}-block-${index + 1}',
        text: paragraphs[index],
      ),
      growable: false,
    );
  }

  static void validate({
    required ChapterStoryData story,
    required ChapterData chapter,
    required StoryAnalysisCatalog catalog,
  }) {
    if (story.chapterId != chapter.id) {
      throw const StoryAnalysisException('Gemini returned the wrong chapter.');
    }
    if (story.cutscenes.isEmpty || story.shots.isEmpty) {
      throw const StoryAnalysisException('Gemini returned no playable shots.');
    }

    final characters = {
      for (final value in catalog.characters) value.id: value,
    };
    final speakerIds = {
      'Narrator',
      for (final value in catalog.characters) value.id,
      for (final value in catalog.characters) value.name,
    };
    final groupedText = <String, List<String>>{};
    final blockSequence = <String>[];

    for (final cutscene in story.cutscenes) {
      _require(catalog.locationIds, cutscene.locationId, 'location');
      _require(
        backgroundStateIds,
        cutscene.backgroundStateId,
        'background state',
      );
    }

    for (final shot in story.shots) {
      _require(layoutIds, shot.layoutId, 'layout');
      _require(catalog.backgroundIds, shot.backgroundId, 'background');
      if (catalog.backgroundAssets.isNotEmpty) {
        final requirement = story.backgroundRequirementForShot(
          story.shots.indexOf(shot),
        );
        final exactBackground = catalog.backgroundAssets.any(
          (asset) =>
              asset.assetId == shot.backgroundId &&
              asset.locationId == requirement?.locationId &&
              asset.stateId == requirement?.stateId,
        );
        if (!exactBackground) {
          throw const StoryAnalysisException(
            'A shot used the wrong location background.',
          );
        }
      }
      _require(transitionIds, shot.transitionId, 'transition');
      _require(cameraPresetIds, shot.camera.presetId, 'camera');
      if (shot.characterLayers.length > 3) {
        throw const StoryAnalysisException(
          'A shot cannot show more than three characters.',
        );
      }

      final visibleCharacters = <String>{};
      for (final layer in shot.characterLayers) {
        final character = characters[layer.characterId];
        if (character == null) {
          throw StoryAnalysisException(
            'Unknown character ID: ${layer.characterId}.',
          );
        }
        visibleCharacters.add(layer.characterId);
        _require(character.rigIds, layer.rigId, 'rig');
        _require(character.poseIds, layer.poseId, 'pose');
        _require(stagePositions, layer.stagePosition, 'stage position');
        _require(scaleIds, layer.scale, 'scale');
        _require(facingIds, layer.facing, 'facing');
        _require(depthIds, layer.depth, 'depth');
        _require(movementIds, layer.movement, 'movement');
        if (layer.faceProfileId != null) {
          _require(
            character.faceProfileIds,
            layer.faceProfileId!,
            'face profile',
          );
        }
        if (layer.faceSetId != null) {
          _require(character.faceSetIds, layer.faceSetId!, 'face set');
        }
      }
      if (shot.focusAssetLayers.length > 2) {
        throw const StoryAnalysisException(
          'A shot cannot show more than two focus assets.',
        );
      }
      final focusEntities = <String>{};
      final shotBlockIds = {
        for (final beat in shot.beats) ...beat.sourceBlockIds,
      };
      for (final layer in shot.focusAssetLayers) {
        final asset = catalog.foregroundAssets
            .where((candidate) => candidate.assetId == layer.assetId)
            .firstOrNull;
        if (asset == null ||
            asset.entityId != layer.entityId ||
            asset.variantId != layer.variantId) {
          throw StoryAnalysisException(
            'Unknown foreground asset ID: ${layer.assetId}.',
          );
        }
        if (!focusEntities.add(layer.entityId)) {
          throw const StoryAnalysisException(
            'A shot cannot repeat the same focus entity.',
          );
        }
        if (!asset.sourceBlockIds.any(shotBlockIds.contains)) {
          throw StoryAnalysisException(
            'Foreground ${layer.entityId} is not supported by this shot.',
          );
        }
        _require(stagePositions, layer.stagePosition, 'focus stage position');
        _require(scaleIds, layer.scale, 'focus scale');
        _require(depthIds, layer.depth, 'focus depth');
        _require(movementIds, layer.movement, 'focus movement');
      }

      final cameraTarget = shot.camera.targetId;
      if (cameraTarget != 'stage' &&
          cameraTarget != 'background' &&
          !visibleCharacters.contains(cameraTarget)) {
        throw StoryAnalysisException('Invalid camera target: $cameraTarget.');
      }

      if (shot.beats.isEmpty) {
        throw const StoryAnalysisException('Every shot needs subtitle text.');
      }
      if (shot.beats.length > 3) {
        throw const StoryAnalysisException(
          'A shot cannot contain more than three subtitle beats.',
        );
      }
      for (final beat in shot.beats) {
        if (!speakerIds.contains(beat.speakerId)) {
          throw StoryAnalysisException('Unknown speaker: ${beat.speakerId}.');
        }
        if (beat.actionId != null) {
          _require(movementIds, beat.actionId!, 'beat action');
        }
        if (beat.sourceBlockIds.length != 1) {
          throw const StoryAnalysisException(
            'Every beat must reference exactly one source block.',
          );
        }
        final blockId = beat.sourceBlockIds.single;
        if (blockSequence.isEmpty || blockSequence.last != blockId) {
          blockSequence.add(blockId);
        }
        groupedText.putIfAbsent(blockId, () => []).add(beat.originalText);
      }
      final trigger = shot.camera.triggerBeatId;
      if (trigger != null && !shot.beats.any((beat) => beat.id == trigger)) {
        throw StoryAnalysisException('Unknown camera trigger beat: $trigger.');
      }
    }

    final blocks = blocksFor(chapter);
    final expectedIds = blocks.map((block) => block.id).toList(growable: false);
    if (!_sameStrings(blockSequence, expectedIds)) {
      throw const StoryAnalysisException(
        'Gemini changed, skipped, duplicated, or reordered chapter blocks.',
      );
    }
    for (final block in blocks) {
      final result = groupedText[block.id]?.join(' ') ?? '';
      if (_normalize(result) != _normalize(block.text)) {
        throw StoryAnalysisException(
          'Gemini changed the chapter text in ${block.id}.',
        );
      }
    }
  }

  static void _require(List<String> allowed, String value, String label) {
    if (!allowed.contains(value)) {
      throw StoryAnalysisException('Unknown $label ID: $value.');
    }
  }

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static String _normalize(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class StoryAnalysisException implements Exception {
  const StoryAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}
