import '../../../shared/models/storytale_models.dart';

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

class StoryAnalysisCatalog {
  const StoryAnalysisCatalog({
    required this.characters,
    required this.backgroundIds,
  });

  final List<StoryAnalysisCharacter> characters;
  final List<String> backgroundIds;

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
  );

  Map<String, dynamic> toJson() => {
    'characters': characters
        .map((character) => character.toJson())
        .toList(growable: false),
    'backgroundIds': backgroundIds,
    'layoutIds': StoryAnalysisContract.layoutIds,
    'cameraPresetIds': StoryAnalysisContract.cameraPresetIds,
    'transitionIds': StoryAnalysisContract.transitionIds,
    'stagePositions': StoryAnalysisContract.stagePositions,
    'scaleIds': StoryAnalysisContract.scaleIds,
    'facingIds': StoryAnalysisContract.facingIds,
    'depthIds': StoryAnalysisContract.depthIds,
    'movementIds': StoryAnalysisContract.movementIds,
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

    for (final shot in story.shots) {
      _require(layoutIds, shot.layoutId, 'layout');
      _require(catalog.backgroundIds, shot.backgroundId, 'background');
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

      final cameraTarget = shot.camera.targetId;
      if (cameraTarget != 'stage' &&
          cameraTarget != 'background' &&
          !visibleCharacters.contains(cameraTarget)) {
        throw StoryAnalysisException('Invalid camera target: $cameraTarget.');
      }

      if (shot.beats.isEmpty) {
        throw const StoryAnalysisException('Every shot needs subtitle text.');
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
