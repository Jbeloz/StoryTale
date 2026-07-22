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
    this.filipinoText,
    this.audioAssetId,
    this.actionId,
  });

  final String id;
  final String speakerId;
  final String originalText;
  final String? filipinoText;
  final String? audioAssetId;
  final String? actionId;
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
}

class StoryShotPlanData {
  const StoryShotPlanData({
    required this.id,
    required this.layoutId,
    required this.backgroundId,
    required this.beats,
    this.characterLayers = const [],
    this.camera = const StoryCameraPlanData(),
    this.transitionId = 'cut',
    this.backgroundPath,
  });

  final String id;
  final String layoutId;
  final String backgroundId;
  final List<StoryBeatData> beats;
  final List<StoryCharacterLayerData> characterLayers;
  final StoryCameraPlanData camera;
  final String transitionId;
  final String? backgroundPath;
}

class StoryCutsceneData {
  const StoryCutsceneData({
    required this.id,
    required this.locationId,
    required this.shots,
    this.timeOfDay = 'unspecified',
  });

  final String id;
  final String locationId;
  final List<StoryShotPlanData> shots;
  final String timeOfDay;
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

  int cutsceneNumberForShot(int shotIndex) {
    var firstShot = 0;
    for (var index = 0; index < cutscenes.length; index++) {
      firstShot += cutscenes[index].shots.length;
      if (shotIndex < firstShot) return index + 1;
    }
    return cutscenes.length;
  }
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
