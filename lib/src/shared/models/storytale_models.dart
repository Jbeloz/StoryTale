enum PreparationStatus { notStarted, preparing, ready, failed }

enum ReaderLanguageMode { english, filipino, dual }

class ChapterData {
  ChapterData({
    required this.id,
    required this.title,
    required this.originalText,
    this.translatedText,
    this.progress = 0,
    this.bookmarked = false,
  });

  final String id;
  final String title;
  final String originalText;
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

class StorySceneData {
  StorySceneData({
    required this.id,
    required this.speaker,
    required this.subtitle,
    required this.movement,
    this.backgroundPath,
    this.characterPath,
    this.audioPath,
  });

  final String id;
  final String speaker;
  final String subtitle;
  final String movement;
  final String? backgroundPath;
  final String? characterPath;
  final String? audioPath;
}

class ChapterStoryData {
  ChapterStoryData({
    required this.chapterId,
    required this.moral,
    required this.scenes,
    this.status = PreparationStatus.notStarted,
  });

  final String chapterId;
  final String moral;
  final List<StorySceneData> scenes;
  PreparationStatus status;
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
