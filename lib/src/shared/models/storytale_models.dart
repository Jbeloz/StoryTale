import 'dart:typed_data';

enum PreparationStatus { notStarted, preparing, ready, failed }

enum ReaderLanguageMode { english, filipino, dual }

enum ChapterType { chapter, sideStory, extra, prologue, epilogue, other }

class ChapterTextBlock {
  const ChapterTextBlock({required this.id, required this.text});

  final String id;
  final String text;
}

class ChapterData {
  ChapterData({
    required this.id,
    required this.title,
    required this.originalText,
    this.type = ChapterType.chapter,
    this.sourceBlocks = const [],
    this.translatedText,
    this.progress = 0,
    this.bookmarked = false,
  });

  final String id;
  final String title;
  final String originalText;
  final ChapterType type;
  final List<ChapterTextBlock> sourceBlocks;
  String? translatedText;
  double progress;
  bool bookmarked;
}

class BookData {
  BookData({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.tags,
    required this.chapters,
    this.language = 'English',
    this.coverPath,
    this.coverBytes,
    this.sourceFileName,
    this.progress = 0,
    DateTime? lastOpenedAt,
  }) : lastOpenedAt = lastOpenedAt ?? DateTime.now();

  final String id;
  String title;
  String author;
  String language;
  String description;
  final List<String> tags;
  final List<ChapterData> chapters;
  String? coverPath;
  final Uint8List? coverBytes;
  final String? sourceFileName;
  double progress;
  DateTime lastOpenedAt;
}

class VoiceProfileData {
  VoiceProfileData({
    required this.id,
    required this.name,
    required this.role,
    required this.modelPath,
    this.status = PreparationStatus.notStarted,
  });

  final String id;
  final String name;
  final String role;
  final String modelPath;
  PreparationStatus status;
}

class StoryBeatData {
  const StoryBeatData({
    required this.id,
    required this.speakerId,
    required this.originalText,
    this.sourceBlockIds = const [],
    this.filipinoText,
    this.audioAssetId,
    this.actionId,
  });

  final String id;
  final String speakerId;
  final String originalText;
  final List<String> sourceBlockIds;
  final String? filipinoText;
  final String? audioAssetId;
  final String? actionId;

  factory StoryBeatData.fromJson(Map<String, dynamic> json) {
    return StoryBeatData(
      id: json['id'] as String,
      speakerId: json['speakerId'] as String,
      originalText: json['originalText'] as String,
      sourceBlockIds:
          (json['sourceBlockIds'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      filipinoText: json['filipinoText'] as String?,
      audioAssetId: json['audioAssetId'] as String?,
      actionId: json['actionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'speakerId': speakerId,
    'originalText': originalText,
    'sourceBlockIds': sourceBlockIds,
    if (filipinoText != null) 'filipinoText': filipinoText,
    if (audioAssetId != null) 'audioAssetId': audioAssetId,
    if (actionId != null) 'actionId': actionId,
  };
}

class StoryCameraPlanData {
  const StoryCameraPlanData({
    this.presetId = 'camera_static',
    this.targetId = 'stage',
    this.triggerBeatId,
  });

  final String presetId;
  final String targetId;
  final String? triggerBeatId;

  factory StoryCameraPlanData.fromJson(Map<String, dynamic> json) {
    return StoryCameraPlanData(
      presetId: json['presetId'] as String? ?? 'camera_static',
      targetId: json['targetId'] as String? ?? 'stage',
      triggerBeatId: json['triggerBeatId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'presetId': presetId,
    'targetId': targetId,
    if (triggerBeatId != null) 'triggerBeatId': triggerBeatId,
  };
}

class StoryFocusAssetLayerData {
  const StoryFocusAssetLayerData({
    required this.entityId,
    required this.assetId,
    required this.variantId,
    this.stagePosition = 'center',
    this.scale = 'medium',
    this.depth = 'normal',
    this.movement = 'idle',
  });

  final String entityId;
  final String assetId;
  final String variantId;
  final String stagePosition;
  final String scale;
  final String depth;
  final String movement;

  factory StoryFocusAssetLayerData.fromJson(Map<String, dynamic> json) {
    return StoryFocusAssetLayerData(
      entityId: json['entityId'] as String,
      assetId: json['assetId'] as String,
      variantId: json['variantId'] as String,
      stagePosition: json['stagePosition'] as String? ?? 'center',
      scale: json['scale'] as String? ?? 'medium',
      depth: json['depth'] as String? ?? 'normal',
      movement: json['movement'] as String? ?? 'idle',
    );
  }

  Map<String, dynamic> toJson() => {
    'entityId': entityId,
    'assetId': assetId,
    'variantId': variantId,
    'stagePosition': stagePosition,
    'scale': scale,
    'depth': depth,
    'movement': movement,
  };
}

class StoryShotPlanData {
  const StoryShotPlanData({
    required this.id,
    required this.layoutId,
    required this.backgroundId,
    required this.beats,
    this.characterLayers = const [],
    this.focusAssetLayers = const [],
    this.camera = const StoryCameraPlanData(),
    this.transitionId = 'cut',
    this.backgroundPath,
  });

  final String id;
  final String layoutId;
  final String backgroundId;
  final List<StoryBeatData> beats;
  final List<StoryCharacterLayerData> characterLayers;
  final List<StoryFocusAssetLayerData> focusAssetLayers;
  final StoryCameraPlanData camera;
  final String transitionId;
  final String? backgroundPath;

  factory StoryShotPlanData.fromJson(Map<String, dynamic> json) {
    final camera = json['camera'];
    return StoryShotPlanData(
      id: json['id'] as String,
      layoutId: json['layoutId'] as String,
      backgroundId: json['backgroundId'] as String,
      beats: _jsonMaps(
        json['beats'],
      ).map(StoryBeatData.fromJson).toList(growable: false),
      characterLayers: _jsonMaps(
        json['characterLayers'],
      ).map(StoryCharacterLayerData.fromJson).toList(growable: false),
      focusAssetLayers: _jsonMaps(
        json['focusAssetLayers'],
      ).map(StoryFocusAssetLayerData.fromJson).toList(growable: false),
      camera: camera is Map
          ? StoryCameraPlanData.fromJson(Map<String, dynamic>.from(camera))
          : const StoryCameraPlanData(),
      transitionId: json['transitionId'] as String? ?? 'cut',
      backgroundPath: json['backgroundPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'layoutId': layoutId,
    'backgroundId': backgroundId,
    'beats': beats.map((beat) => beat.toJson()).toList(growable: false),
    'characterLayers': characterLayers
        .map((layer) => layer.toJson())
        .toList(growable: false),
    'focusAssetLayers': focusAssetLayers
        .map((layer) => layer.toJson())
        .toList(growable: false),
    'camera': camera.toJson(),
    'transitionId': transitionId,
    if (backgroundPath != null) 'backgroundPath': backgroundPath,
  };
}

class StoryCutsceneData {
  const StoryCutsceneData({
    required this.id,
    required this.locationId,
    required this.shots,
    this.timeOfDay = 'unspecified',
    this.backgroundStateId = 'unspecified',
  });

  final String id;
  final String locationId;
  final List<StoryShotPlanData> shots;
  final String timeOfDay;
  final String backgroundStateId;

  factory StoryCutsceneData.fromJson(Map<String, dynamic> json) {
    return StoryCutsceneData(
      id: json['id'] as String,
      locationId: json['locationId'] as String,
      shots: _jsonMaps(
        json['shots'],
      ).map(StoryShotPlanData.fromJson).toList(growable: false),
      timeOfDay: json['timeOfDay'] as String? ?? 'unspecified',
      backgroundStateId:
          json['backgroundStateId'] as String? ??
          json['timeOfDay'] as String? ??
          'unspecified',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'locationId': locationId,
    'shots': shots.map((shot) => shot.toJson()).toList(growable: false),
    'timeOfDay': timeOfDay,
    'backgroundStateId': backgroundStateId,
  };
}

class StoryCharacterLayerData {
  const StoryCharacterLayerData({
    required this.characterId,
    required this.rigId,
    required this.poseId,
    this.faceExpressionId = 'neutral',
    this.faceProfileId,
    this.faceSetId,
    this.outfitId,
    this.stagePosition = 'center',
    this.scale = 'full',
    this.facing = 'front',
    this.depth = 'normal',
    this.movement = 'idle',
    this.isSpeaking = false,
  });

  final String characterId;
  final String rigId;
  final String poseId;
  final String faceExpressionId;
  final String? faceProfileId;
  final String? faceSetId;
  final String? outfitId;
  final String stagePosition;
  final String scale;
  final String facing;
  final String depth;
  final String movement;
  final bool isSpeaking;

  factory StoryCharacterLayerData.fromJson(Map<String, dynamic> json) {
    return StoryCharacterLayerData(
      characterId: json['characterId'] as String,
      rigId: json['rigId'] as String? ?? 'humanoid_v1',
      poseId: json['poseId'] as String? ?? 'neutral',
      faceExpressionId: json['faceExpressionId'] as String? ?? 'neutral',
      faceProfileId: json['faceProfileId'] as String?,
      faceSetId: json['faceSetId'] as String?,
      outfitId: json['outfitId'] as String?,
      stagePosition: json['stagePosition'] as String? ?? 'center',
      scale: json['scale'] as String? ?? 'full',
      facing: json['facing'] as String? ?? 'front',
      depth: json['depth'] as String? ?? 'normal',
      movement: json['movement'] as String? ?? 'idle',
      isSpeaking: json['isSpeaking'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'characterId': characterId,
    'rigId': rigId,
    'poseId': poseId,
    'faceExpressionId': faceExpressionId,
    if (faceProfileId != null) 'faceProfileId': faceProfileId,
    if (faceSetId != null) 'faceSetId': faceSetId,
    if (outfitId != null) 'outfitId': outfitId,
    'stagePosition': stagePosition,
    'scale': scale,
    'facing': facing,
    'depth': depth,
    'movement': movement,
    'isSpeaking': isSpeaking,
  };
}

class ChapterStoryData {
  ChapterStoryData({
    required this.chapterId,
    required this.moral,
    required this.cutscenes,
    this.status = PreparationStatus.notStarted,
  });

  final String chapterId;
  final String moral;
  final List<StoryCutsceneData> cutscenes;
  PreparationStatus status;

  List<StoryShotPlanData> get shots => [
    for (final cutscene in cutscenes) ...cutscene.shots,
  ];

  List<StoryBackgroundRequirementData> get backgroundRequirements {
    final seen = <String>{};
    return [
      for (final cutscene in cutscenes)
        if (seen.add('${cutscene.locationId}::${cutscene.backgroundStateId}'))
          StoryBackgroundRequirementData(
            locationId: cutscene.locationId,
            stateId: cutscene.backgroundStateId,
          ),
    ];
  }

  int cutsceneNumberForShot(int shotIndex) {
    var firstShot = 0;
    for (var index = 0; index < cutscenes.length; index++) {
      firstShot += cutscenes[index].shots.length;
      if (shotIndex < firstShot) return index + 1;
    }
    return cutscenes.length;
  }

  StoryBackgroundRequirementData? backgroundRequirementForShot(int shotIndex) {
    var offset = 0;
    for (final cutscene in cutscenes) {
      final end = offset + cutscene.shots.length;
      if (shotIndex >= offset && shotIndex < end) {
        return StoryBackgroundRequirementData(
          locationId: cutscene.locationId,
          stateId: cutscene.backgroundStateId,
        );
      }
      offset = end;
    }
    return null;
  }

  factory ChapterStoryData.fromJson(Map<String, dynamic> json) {
    return ChapterStoryData(
      chapterId: json['chapterId'] as String,
      moral: json['moral'] as String? ?? '',
      cutscenes: _jsonMaps(
        json['cutscenes'],
      ).map(StoryCutsceneData.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'moral': moral,
    'cutscenes': cutscenes
        .map((cutscene) => cutscene.toJson())
        .toList(growable: false),
  };
}

class StoryBackgroundRequirementData {
  const StoryBackgroundRequirementData({
    required this.locationId,
    required this.stateId,
  });

  final String locationId;
  final String stateId;

  String get key => '$locationId::$stateId';
}

List<Map<String, dynamic>> _jsonMaps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

class ReaderSettingsData {
  ReaderSettingsData({
    this.textSize = 18,
    this.fontFamily = 'Sans Serif',
    this.theme = 'Light',
    this.lineSpacing = 1.5,
    this.languageMode = ReaderLanguageMode.english,
  });

  double textSize;
  String fontFamily;
  String theme;
  double lineSpacing;
  ReaderLanguageMode languageMode;

  ReaderSettingsData copy() => ReaderSettingsData(
    textSize: textSize,
    fontFamily: fontFamily,
    theme: theme,
    lineSpacing: lineSpacing,
    languageMode: languageMode,
  );
}
