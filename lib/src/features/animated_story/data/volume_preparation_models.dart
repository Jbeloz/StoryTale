import '../../../shared/models/storytale_models.dart';

enum VolumePreparationStatus { notStarted, preparing, paused, ready, failed }

enum VolumePreparationStage {
  waiting,
  analyzingChapters,
  mergingStoryBible,
  ready,
}

class ChapterPreparationJobData {
  ChapterPreparationJobData({
    required this.chapterId,
    required this.title,
    this.status = PreparationStatus.notStarted,
    this.progress = 0,
    this.lastError,
  });

  final String chapterId;
  final String title;
  PreparationStatus status;
  double progress;
  String? lastError;
}

class VolumePreparationJobData {
  VolumePreparationJobData({required this.bookId, required this.chapters});

  factory VolumePreparationJobData.forBook(BookData book) {
    return VolumePreparationJobData(
      bookId: book.id,
      chapters: [
        for (final chapter in book.chapters)
          ChapterPreparationJobData(
            chapterId: chapter.id,
            title: chapter.title,
          ),
      ],
    );
  }

  final String bookId;
  final List<ChapterPreparationJobData> chapters;
  final List<String> events = [];
  VolumePreparationStatus status = VolumePreparationStatus.notStarted;
  VolumePreparationStage stage = VolumePreparationStage.waiting;
  String? currentChapterId;
  DateTime? startedAt;
  DateTime? finishedAt;
  bool pauseRequested = false;
  int entityCount = 0;
  int reusedRequirementCount = 0;
  int foregroundEntityCount = 0;
  int foregroundAssetCount = 0;
  int foregroundApprovedCount = 0;
  String? lastError;

  int get readyCount => chapters
      .where((chapter) => chapter.status == PreparationStatus.ready)
      .length;

  double get progress {
    if (chapters.isEmpty) {
      return status == VolumePreparationStatus.ready ? 1 : 0;
    }
    final chapterProgress = chapters.fold<double>(
      0,
      (sum, chapter) => sum + chapter.progress,
    );
    return (chapterProgress / chapters.length).clamp(0, 1);
  }

  Duration get elapsed {
    final start = startedAt;
    if (start == null) return Duration.zero;
    return (finishedAt ?? DateTime.now()).difference(start);
  }

  ChapterPreparationJobData chapter(String chapterId) {
    return chapters.firstWhere((chapter) => chapter.chapterId == chapterId);
  }

  void addEvent(String message) {
    final timestamp = DateTime.now();
    final minutes = timestamp.minute.toString().padLeft(2, '0');
    final seconds = timestamp.second.toString().padLeft(2, '0');
    events.insert(0, '${timestamp.hour}:$minutes:$seconds  $message');
    if (events.length > 12) events.removeLast();
  }
}
