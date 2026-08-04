import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../generated/voice_manifest.g.dart';
import '../../features/animated_story/data/subtitle_beat_splitter.dart';
import '../../features/animated_story/data/volume_preparation_models.dart';
import '../../features/library/data/library_repository.dart';
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
  final Map<String, VolumePreparationJobData> volumePreparationJobs = {};
  final Map<String, Map<String, String>> voiceAudio = {};
  final Map<String, String> voiceModelFiles = {};
  final Map<String, int> voicePitches = {};
  final Set<String> preparedAudioChapters = {};

  bool onboardingCompleted = false;
  String localProfileName = 'StoryTale Reader';
  String? currentBookId;
  String? currentChapterId;

  /// True when the last save could not be written, normally because the web
  /// preview's local storage is full. The session keeps working.
  bool libraryStorageFailed = false;

  final LibraryRepository _library = LibraryRepository();
  final Set<String> _importedBookIds = {};
  Timer? _readingStateTimer;
  bool _userChangedReadingState = false;
  bool _disposed = false;

  static const _readingStateSaveDelay = Duration(milliseconds: 600);

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

  /// Loads the locally stored library. Call once at startup.
  ///
  /// Imported books are always merged, because adding a book is safe at any
  /// time. Reading progress and the last position are applied only when the
  /// reader has not already changed them, so a slow load can never overwrite
  /// live reading.
  Future<void> restore() async {
    final storedBooks = await _library.loadImportedBooks();
    final knownIds = books.map((book) => book.id).toSet();
    for (final book in storedBooks) {
      _importedBookIds.add(book.id);
      if (knownIds.add(book.id)) books.add(book);
    }

    if (!_userChangedReadingState) {
      final state = await _library.loadReadingState();
      _applyReadingState(state);
    }

    notifyListeners();
  }

  void _applyReadingState(LibraryReadingState state) {
    for (final book in books) {
      final progress = state.bookProgress[book.id];
      if (progress != null) book.progress = progress;
      final opened = state.lastOpenedAt[book.id];
      if (opened != null) book.lastOpenedAt = opened;

      for (final chapter in book.chapters) {
        final saved = state.chapters[chapter.id];
        if (saved == null) continue;
        chapter.progress = saved.progress;
        chapter.bookmarked = saved.bookmarked;
        chapter.translatedText ??= saved.translatedText;
      }
      _updateBookProgress(book);
    }

    final settings = state.readerSettings;
    if (settings != null) {
      readerSettings
        ..textSize = settings.textSize
        ..fontFamily = settings.fontFamily
        ..theme = settings.theme
        ..lineSpacing = settings.lineSpacing
        ..languageMode = settings.languageMode;
    }

    final book = bookById(state.currentBookId);
    if (book == null) return;
    currentBookId = book.id;
    currentChapterId =
        chapterById(book, state.currentChapterId)?.id ??
        book.chapters.firstOrNull?.id;
  }

  LibraryReadingState _readingState() {
    final chapters = <String, ChapterReadingState>{};
    final bookProgress = <String, double>{};
    final lastOpenedAt = <String, DateTime>{};
    for (final book in books) {
      bookProgress[book.id] = book.progress;
      lastOpenedAt[book.id] = book.lastOpenedAt;
      for (final chapter in book.chapters) {
        if (chapter.progress == 0 &&
            !chapter.bookmarked &&
            chapter.translatedText == null) {
          continue;
        }
        chapters[chapter.id] = ChapterReadingState(
          progress: chapter.progress,
          bookmarked: chapter.bookmarked,
          translatedText: chapter.translatedText,
        );
      }
    }
    return LibraryReadingState(
      chapters: chapters,
      bookProgress: bookProgress,
      lastOpenedAt: lastOpenedAt,
      currentBookId: currentBookId,
      currentChapterId: currentChapterId,
      readerSettings: readerSettings,
    );
  }

  /// Reading progress changes on every scroll frame, so writes are debounced.
  void _scheduleReadingStateSave() {
    _userChangedReadingState = true;
    _readingStateTimer?.cancel();
    _readingStateTimer = Timer(_readingStateSaveDelay, _saveReadingStateNow);
  }

  void _saveReadingStateNow() {
    _readingStateTimer?.cancel();
    _readingStateTimer = null;
    _recordWrite(_library.saveReadingState(_readingState()));
  }

  /// Writes reading progress that is still waiting behind the debounce.
  ///
  /// Called when the app widget goes away so nothing is lost, and so no timer
  /// outlives the screen that created it.
  void flushPendingSaves() {
    if (!(_readingStateTimer?.isActive ?? false)) return;
    _saveReadingStateNow();
  }

  void _saveImportedBooks() {
    final imported = books
        .where((book) => _importedBookIds.contains(book.id))
        .toList(growable: false);
    _recordWrite(_library.saveImportedBooks(imported));
  }

  void _recordWrite(Future<LibraryWriteResult> write) {
    write.then((result) {
      final failed = result != LibraryWriteResult.saved;
      if (_disposed || failed == libraryStorageFailed) return;
      libraryStorageFailed = failed;
      notifyListeners();
    });
  }

  void completeOnboarding() {
    onboardingCompleted = true;
    notifyListeners();
  }

  void openBook(BookData book, {ChapterData? chapter}) {
    currentBookId = book.id;
    currentChapterId = (chapter ?? book.chapters.first).id;
    book.lastOpenedAt = DateTime.now();
    _scheduleReadingStateSave();
    notifyListeners();
  }

  void addImportedBook(BookData book) {
    books.add(book);
    _importedBookIds.add(book.id);
    openBook(book);
    _saveImportedBooks();
  }

  void removeBook(BookData book) {
    books.removeWhere((item) => item.id == book.id);
    final wasImported = _importedBookIds.remove(book.id);
    if (currentBookId == book.id) {
      currentBookId = books.firstOrNull?.id;
      currentChapterId = books.firstOrNull?.chapters.firstOrNull?.id;
    }
    if (wasImported) _saveImportedBooks();
    _saveReadingStateNow();
    notifyListeners();
  }

  void clearReadingProgress(BookData book) {
    book.progress = 0;
    for (final chapter in book.chapters) {
      chapter.progress = 0;
    }
    _scheduleReadingStateSave();
    notifyListeners();
  }

  void updateReadingProgress(double progress) {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null || chapter == null) return;
    chapter.progress = progress.clamp(0, 1);
    _updateBookProgress(book);
    book.lastOpenedAt = DateTime.now();
    _scheduleReadingStateSave();
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
    _scheduleReadingStateSave();
    notifyListeners();
  }

  void translateChapter(ChapterData chapter) {
    chapter.translatedText ??=
        'Noong unang panahon, may isang munting prinsipe na nakatira '
        'sa isang maliit na planeta. Minahal niya ang panonood ng paglubog '
        'ng araw at inalagaan niya ang kanyang bulaklak.';
    _scheduleReadingStateSave();
    notifyListeners();
  }

  void saveReaderSettings(ReaderSettingsData settings) {
    readerSettings
      ..textSize = settings.textSize
      ..fontFamily = settings.fontFamily
      ..theme = settings.theme
      ..lineSpacing = settings.lineSpacing
      ..languageMode = settings.languageMode;
    _scheduleReadingStateSave();
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
      final blocks = _sourceBlocks(chapter);
      return ChapterStoryData(
        chapterId: chapter.id,
        moral: 'Kindness and friendship make every journey meaningful.',
        cutscenes: [
          StoryCutsceneData(
            id: '${chapter.id}-cutscene-1',
            locationId: 'moonlit_rose_garden',
            timeOfDay: 'night',
            shots: List.generate(
              blocks.length,
              (index) => _safeShot(chapter, index + 1, blocks[index]),
            ),
          ),
        ],
      );
    });
  }

  VolumePreparationJobData volumeJobFor(BookData book) {
    return volumePreparationJobs.putIfAbsent(
      book.id,
      () => VolumePreparationJobData.forBook(book),
    );
  }

  void volumePreparationChanged() {
    notifyListeners();
  }

  void requestVolumePreparationPause(BookData book) {
    volumeJobFor(book).pauseRequested = true;
    notifyListeners();
  }

  static StoryShotPlanData _safeShot(
    ChapterData chapter,
    int number,
    ChapterTextBlock block,
  ) {
    final shotId = '${chapter.id}-shot-$number';
    final lines = splitSubtitleBeats(block.text);
    final detailShot = number.isEven;
    return StoryShotPlanData(
      id: shotId,
      layoutId: detailShot ? 'object_detail' : 'background_establishing',
      backgroundId: 'moonlit_rose_garden',
      transitionId: number == 1 ? 'fade_in' : 'cut',
      camera: StoryCameraPlanData(
        presetId: detailShot ? 'camera_push_in_slow' : 'camera_static',
        targetId: 'background',
      ),
      beats: List.generate(
        lines.length,
        (index) => StoryBeatData(
          id: '$shotId-beat-${index + 1}',
          speakerId: 'Narrator',
          originalText: lines[index],
          sourceBlockIds: [block.id],
        ),
      ),
    );
  }

  static List<ChapterTextBlock> _sourceBlocks(ChapterData chapter) {
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

  void markStoryPrepared(ChapterData chapter) {
    storyFor(chapter).status = PreparationStatus.ready;
    notifyListeners();
  }

  void replaceStory(ChapterData chapter, ChapterStoryData story) {
    story.status = PreparationStatus.ready;
    stories[chapter.id] = story;
    notifyListeners();
  }

  void updateProfileName(String value) {
    if (value.trim().isEmpty) return;
    localProfileName = value.trim();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    flushPendingSaves();
    _readingStateTimer?.cancel();
    _readingStateTimer = null;
    super.dispose();
  }

  static List<BookData> _demoBooks() {
    // Short Story Mode fixture: each visual moment appears once and in order.
    const passage =
        'Once upon a time, there was a little prince who lived on a small '
        'planet. He loved watching the sunset.\n\nEvery evening, he would '
        'move his chair a little closer and enjoy the changing colors of '
        'the sky.\n\nOne day, he saw a beautiful flower growing on his '
        'planet. He took care of it with great love.';
    const chapterText = passage;

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
