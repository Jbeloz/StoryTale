import 'package:flutter/foundation.dart';

import '../../generated/voice_manifest.g.dart';
import '../../shared/models/storytale_models.dart';

class StoryTaleController extends ChangeNotifier {
  StoryTaleController() {
    books.addAll(_demoBooks());
    for (final book in books) {
      _updateBookProgress(book);
    }
    currentBookId = books.first.id;
    currentChapterId = books.first.chapters.first.id;
    voiceModelFiles.addAll(generatedVoiceModels);
    voicePitches.addAll(generatedVoicePitches);
    voiceAudio.addAll(
      generatedVoiceAudio.map(
        (chapterId, paths) => MapEntry(chapterId, Map.of(paths)),
      ),
    );
    for (final voice in voices) {
      voice.status = generatedVoiceModels.containsKey(voice.id)
          ? PreparationStatus.ready
          : PreparationStatus.notStarted;
    }
  }

  final List<BookData> books = [];
  final List<String> recentSearches = [
    'The Little Prince',
    'Alice in Wonderland',
    'The Jungle Book',
  ];
  final List<VoiceProfileData> voices = [
    VoiceProfileData(
      id: 'narrator',
      name: 'Daily Dose Narrator',
      role: 'Narrator',
      modelPath: 'models/voices/raw/narrator',
    ),
    VoiceProfileData(
      id: 'heroine',
      name: 'Young Heroine',
      role: 'Character',
      modelPath: 'models/voices/raw/heroine',
    ),
    VoiceProfileData(
      id: 'hero',
      name: 'Young Hero',
      role: 'Character',
      modelPath: 'models/voices/raw/hero',
    ),
    VoiceProfileData(
      id: 'deep',
      name: 'Deep Character',
      role: 'Character',
      modelPath: 'models/voices/raw/deep',
    ),
    VoiceProfileData(
      id: 'elder',
      name: 'Elder / Extra',
      role: 'Character',
      modelPath: 'models/voices/raw/elder',
    ),
  ];

  final ReaderSettingsData readerSettings = ReaderSettingsData();
  final Map<String, ChapterStoryData> stories = {};
  final Map<String, Map<String, String>> voiceAudio = {};
  final Map<String, String> voiceModelFiles = {};
  final Map<String, int> voicePitches = {};
  final Set<String> preparedAudioChapters = {};

  bool onboardingCompleted = false;
  String localProfileName = 'StoryTale Reader';
  String? currentBookId;
  String? currentChapterId;

  BookData? get currentBook => bookById(currentBookId);

  ChapterData? get currentChapter {
    final book = currentBook;
    if (book == null) return null;
    return chapterById(book, currentChapterId) ?? book.chapters.firstOrNull;
  }

  String? audioPath(String chapterId, String voiceId) {
    return voiceAudio[chapterId]?[voiceId];
  }

  String? voiceModelFile(String voiceId) => voiceModelFiles[voiceId];

  int voicePitch(String voiceId) => voicePitches[voiceId] ?? 0;

  BookData? bookById(String? id) {
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  ChapterData? chapterById(BookData book, String? id) {
    for (final chapter in book.chapters) {
      if (chapter.id == id) return chapter;
    }
    return null;
  }

  void completeOnboarding() {
    onboardingCompleted = true;
    notifyListeners();
  }

  void openBook(BookData book, {ChapterData? chapter}) {
    currentBookId = book.id;
    currentChapterId = (chapter ?? book.chapters.first).id;
    book.lastOpenedAt = DateTime.now();
    notifyListeners();
  }

  void addImportedBook(BookData book) {
    books.add(book);
    openBook(book);
  }

  void removeBook(BookData book) {
    books.removeWhere((item) => item.id == book.id);
    if (currentBookId == book.id) {
      currentBookId = books.firstOrNull?.id;
      currentChapterId = books.firstOrNull?.chapters.firstOrNull?.id;
    }
    notifyListeners();
  }

  void clearReadingProgress(BookData book) {
    book.progress = 0;
    for (final chapter in book.chapters) {
      chapter.progress = 0;
    }
    notifyListeners();
  }

  void updateReadingProgress(double progress) {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null || chapter == null) return;
    chapter.progress = progress.clamp(0, 1);
    _updateBookProgress(book);
    book.lastOpenedAt = DateTime.now();
    notifyListeners();
  }

  void _updateBookProgress(BookData book) {
    if (book.chapters.isEmpty) {
      book.progress = 0;
      return;
    }
    final total = book.chapters.fold<double>(
      0,
      (sum, chapter) => sum + chapter.progress,
    );
    book.progress = total / book.chapters.length;
  }

  void toggleBookmark(ChapterData chapter) {
    chapter.bookmarked = !chapter.bookmarked;
    notifyListeners();
  }

  void translateChapter(ChapterData chapter) {
    chapter.translatedText ??=
        'Noong unang panahon, may isang munting prinsipe na nakatira '
        'sa isang maliit na planeta. Minahal niya ang panonood ng paglubog '
        'ng araw at inalagaan niya ang kanyang bulaklak.';
    notifyListeners();
  }

  void saveReaderSettings(ReaderSettingsData settings) {
    readerSettings
      ..textSize = settings.textSize
      ..fontFamily = settings.fontFamily
      ..theme = settings.theme
      ..lineSpacing = settings.lineSpacing
      ..languageMode = settings.languageMode;
    notifyListeners();
  }

  void setVoiceStatus(String id, PreparationStatus status) {
    for (final voice in voices) {
      if (voice.id == id) voice.status = status;
    }
    notifyListeners();
  }

  void markAudioPrepared(ChapterData chapter) {
    preparedAudioChapters.add(chapter.id);
    notifyListeners();
  }

  ChapterStoryData storyFor(ChapterData chapter) {
    return stories.putIfAbsent(chapter.id, () {
      final lines = _storySceneLines(chapter);
      return ChapterStoryData(
        chapterId: chapter.id,
        moral: 'Kindness and friendship make every journey meaningful.',
        scenes: [
          _testScene(chapter, 1, lines[0], 'neutral', 'left', 'fade in'),
          _testScene(chapter, 2, lines[1], 'talking', 'center', 'talking'),
          _testScene(chapter, 3, lines[2], 'pointing', 'right', 'pointing'),
          _testScene(chapter, 4, lines[3], 'walking', 'center', 'walk right'),
        ],
      );
    });
  }

  static StorySceneData _testScene(
    ChapterData chapter,
    int number,
    String subtitle,
    String poseId,
    String position,
    String movement,
  ) {
    final speaking = poseId == 'talking';
    return StorySceneData(
      id: '${chapter.id}-scene-$number',
      speaker: speaking ? 'Prince' : 'Narrator',
      subtitle: subtitle,
      movement: movement,
      characterLayers: [
        StoryCharacterLayerData(
          characterId: 'little_prince',
          rigId: 'humanoid_v1',
          poseId: poseId,
          faceProfileId: 'hero',
          faceSetId: poseId == 'pointing' ? 'happy' : 'neutral',
          stagePosition: position,
          movement: movement,
          isSpeaking: speaking,
        ),
      ],
    );
  }

  static List<String> _storySceneLines(ChapterData chapter) {
    final blocks = chapter.sourceBlocks.isNotEmpty
        ? chapter.sourceBlocks.map((block) => block.text)
        : chapter.originalText.split(RegExp(r'\n\s*\n'));
    final lines = blocks
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .take(4)
        .toList();
    while (lines.length < 4) {
      lines.add(lines.isEmpty ? chapter.title : lines.last);
    }
    return lines;
  }

  void markStoryPrepared(ChapterData chapter) {
    storyFor(chapter).status = PreparationStatus.ready;
    notifyListeners();
  }

  void updateProfileName(String value) {
    if (value.trim().isEmpty) return;
    localProfileName = value.trim();
    notifyListeners();
  }

  static List<BookData> _demoBooks() {
    const passage =
        'Once upon a time, there was a little prince who lived on a small '
        'planet. He loved watching the sunset.\n\nEvery evening, he would '
        'move his chair a little closer and enjoy the changing colors of '
        'the sky.\n\nOne day, he saw a beautiful flower growing on his '
        'planet. He took care of it with great love.';
    final chapterText = List.filled(6, passage).join('\n\n');

    BookData book({
      required String id,
      required String title,
      required String author,
      required List<String> tags,
    }) {
      return BookData(
        id: id,
        title: title,
        author: author,
        description:
            'A classic story available in the local StoryTale library.',
        tags: tags,
        chapters: List.generate(
          4,
          (index) => ChapterData(
            id: '$id-chapter-${index + 1}',
            title: 'Chapter ${index + 1}',
            originalText: chapterText,
            progress: index == 0 ? 0.3 : 0,
          ),
        ),
        progress: id == 'little-prince' ? 0.3 : 0,
      );
    }

    return [
      book(
        id: 'little-prince',
        title: 'The Little Prince',
        author: 'Antoine de Saint-Exupéry',
        tags: ['Fantasy', 'Classic', 'Friendship'],
      ),
      book(
        id: 'alice',
        title: 'Alice in Wonderland',
        author: 'Lewis Carroll',
        tags: ['Adventure', 'Fantasy', 'Classic'],
      ),
      book(
        id: 'jungle-book',
        title: 'The Jungle Book',
        author: 'Rudyard Kipling',
        tags: ['Adventure', 'Children', 'Classic'],
      ),
    ];
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
