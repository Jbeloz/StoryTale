import 'dart:convert';
import 'dart:typed_data';

enum PreparationStatus { notStarted, preparing, ready, failed }

enum ReaderLanguageMode { english, filipino, dual }

/// Where one chapter's translation currently stands. `idle` covers both "never
/// translated" and "already cached"; check `translatedText` to tell them apart.
enum TranslationStatus { idle, translating, failed }

/// How the reader lays a chapter out: one continuous scroll, or fixed pages
/// turned sideways like a printed book.
enum ReaderReadingMode { scroll, page }

enum ChapterType { chapter, sideStory, extra, prologue, epilogue, other }

class ChapterTextBlock {
  const ChapterTextBlock({required this.id, required this.text});

  final String id;
  final String text;

  factory ChapterTextBlock.fromJson(Map<String, dynamic> json) =>
      ChapterTextBlock(id: _string(json['id']), text: _string(json['text']));

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// A running total of how many image bytes a save may still store.
///
/// Local storage on the web preview holds only a few megabytes, so artwork is
/// written until the budget runs out. Text, progress, and covers are never
/// sacrificed to illustrations.
class ImageByteBudget {
  ImageByteBudget(this.remaining);

  int remaining;

  bool take(int bytes) {
    if (bytes > remaining) return false;
    remaining -= bytes;
    return true;
  }
}

/// One illustration inside a chapter.
///
/// Illustrations are stored apart from [ChapterTextBlock] so Story Mode's
/// contract that every source block appears exactly once stays untouched.
/// [afterBlockIndex] is how many text blocks precede the image.
class ChapterImageData {
  ChapterImageData({
    required this.id,
    required this.afterBlockIndex,
    this.bytes,
    this.alt = '',
  });

  final String id;
  final int afterBlockIndex;
  final Uint8List? bytes;
  final String alt;

  /// True when the image was known at import but its bytes did not fit the
  /// local storage budget. The reader shows a placeholder instead.
  bool get isStored => bytes != null && bytes!.isNotEmpty;

  factory ChapterImageData.fromJson(Map<String, dynamic> json) {
    final raw = json['bytes'];
    Uint8List? bytes;
    if (raw is String && raw.isNotEmpty) {
      try {
        bytes = base64Decode(raw);
      } catch (_) {
        bytes = null;
      }
    }
    return ChapterImageData(
      id: _string(json['id']),
      afterBlockIndex: json['afterBlockIndex'] is num
          ? (json['afterBlockIndex'] as num).toInt()
          : 0,
      bytes: bytes,
      alt: _string(json['alt']),
    );
  }

  Map<String, dynamic> toJson({ImageByteBudget? budget}) {
    final data = bytes;
    final fits =
        data != null &&
        data.isNotEmpty &&
        (budget == null || budget.take(data.lengthInBytes));
    return {
      'id': id,
      'afterBlockIndex': afterBlockIndex,
      if (alt.isNotEmpty) 'alt': alt,
      if (fits) 'bytes': base64Encode(data),
    };
  }
}

class ChapterData {
  ChapterData({
    required this.id,
    required this.title,
    required this.originalText,
    this.type = ChapterType.chapter,
    this.sourceBlocks = const [],
    this.images = const [],
    this.translatedText,
    this.progress = 0,
    this.bookmarked = false,
  });

  final String id;
  final String title;
  final String originalText;
  final ChapterType type;
  final List<ChapterTextBlock> sourceBlocks;
  final List<ChapterImageData> images;
  String? translatedText;
  double progress;
  bool bookmarked;

  factory ChapterData.fromJson(Map<String, dynamic> json) {
    final blocks = _jsonMaps(
      json['sourceBlocks'],
    ).map(ChapterTextBlock.fromJson).toList(growable: false);
    return ChapterData(
      id: _string(json['id']),
      title: _string(json['title']),
      // The importer builds originalText by joining the same blocks, so it is
      // rebuilt here instead of being stored twice.
      originalText: blocks.isEmpty
          ? _string(json['originalText'])
          : blocks.map((block) => block.text).join('\n\n'),
      type: _enumByName(ChapterType.values, json['type'], ChapterType.chapter),
      sourceBlocks: blocks,
      images: _jsonMaps(
        json['images'],
      ).map(ChapterImageData.fromJson).toList(growable: false),
      translatedText: json['translatedText'] is String
          ? json['translatedText'] as String
          : null,
      progress: _double(json['progress']).clamp(0, 1),
      bookmarked: json['bookmarked'] == true,
    );
  }

  Map<String, dynamic> toJson({ImageByteBudget? budget}) => {
    'id': id,
    'title': title,
    if (sourceBlocks.isEmpty) 'originalText': originalText,
    'type': type.name,
    'sourceBlocks': sourceBlocks
        .map((block) => block.toJson())
        .toList(growable: false),
    if (images.isNotEmpty)
      'images': images
          .map((item) => item.toJson(budget: budget))
          .toList(growable: false),
    if (translatedText != null) 'translatedText': translatedText,
    'progress': progress,
    'bookmarked': bookmarked,
  };
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

  /// Covers are shrunk to a thumbnail at import by `ReaderImageCodec`, so a
  /// persisted cover is normally well under 100 KB. This is only a guard
  /// against an absurd value reaching local storage; it is not a display or
  /// quality limit.
  static const maxPersistedCoverBytes = 2 * 1024 * 1024;

  factory BookData.fromJson(Map<String, dynamic> json) {
    final cover = json['coverBytes'];
    Uint8List? coverBytes;
    if (cover is String && cover.isNotEmpty) {
      try {
        coverBytes = base64Decode(cover);
      } catch (_) {
        coverBytes = null;
      }
    }
    return BookData(
      id: _string(json['id']),
      title: _string(json['title']),
      author: _string(json['author']),
      description: _string(json['description']),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      chapters: _jsonMaps(json['chapters']).map(ChapterData.fromJson).toList(),
      language: json['language'] is String
          ? json['language'] as String
          : 'English',
      coverPath: json['coverPath'] is String
          ? json['coverPath'] as String
          : null,
      coverBytes: coverBytes,
      sourceFileName: json['sourceFileName'] is String
          ? json['sourceFileName'] as String
          : null,
      progress: _double(json['progress']).clamp(0, 1),
      lastOpenedAt:
          DateTime.tryParse(_string(json['lastOpenedAt'])) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({ImageByteBudget? budget}) {
    final cover = coverBytes;
    return {
      'id': id,
      'title': title,
      'author': author,
      'language': language,
      'description': description,
      'tags': tags,
      'chapters': chapters
          .map((chapter) => chapter.toJson(budget: budget))
          .toList(growable: false),
      if (coverPath != null) 'coverPath': coverPath,
      if (cover != null && cover.lengthInBytes <= maxPersistedCoverBytes)
        'coverBytes': base64Encode(cover),
      if (sourceFileName != null) 'sourceFileName': sourceFileName,
      'progress': progress,
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
    };
  }
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
    this.readingMode = ReaderReadingMode.scroll,
  });

  double textSize;
  String fontFamily;
  String theme;
  double lineSpacing;
  ReaderLanguageMode languageMode;
  ReaderReadingMode readingMode;

  ReaderSettingsData copy() => ReaderSettingsData(
    textSize: textSize,
    fontFamily: fontFamily,
    theme: theme,
    lineSpacing: lineSpacing,
    languageMode: languageMode,
    readingMode: readingMode,
  );

  factory ReaderSettingsData.fromJson(Map<String, dynamic> json) {
    final defaults = ReaderSettingsData();
    return ReaderSettingsData(
      textSize: _double(json['textSize'], defaults.textSize),
      fontFamily: json['fontFamily'] is String
          ? json['fontFamily'] as String
          : defaults.fontFamily,
      theme: json['theme'] is String ? json['theme'] as String : defaults.theme,
      lineSpacing: _double(json['lineSpacing'], defaults.lineSpacing),
      languageMode: _enumByName(
        ReaderLanguageMode.values,
        json['languageMode'],
        defaults.languageMode,
      ),
      readingMode: _enumByName(
        ReaderReadingMode.values,
        json['readingMode'],
        defaults.readingMode,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'textSize': textSize,
    'fontFamily': fontFamily,
    'theme': theme,
    'lineSpacing': lineSpacing,
    'languageMode': languageMode.name,
    'readingMode': readingMode.name,
  };
}

String _string(Object? value) => value is String ? value : '';

double _double(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
