import '../../../shared/models/storytale_models.dart';

enum VolumePreparationStatus { notStarted, preparing, paused, ready, failed }

enum VolumePreparationStage {
  waiting,
  analyzingChapters,
  mergingStoryBible,
  preparingAssets,
  connectingStoryAssets,
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
  int backgroundAssetCount = 0;
  int backgroundReadyCount = 0;
  int assetTotal = 0;
  int assetReadyCount = 0;
  int assetNeedsReviewCount = 0;
  String? currentAssetLabel;
  String? lastError;

  int get readyCount => chapters
      .where((chapter) => chapter.status == PreparationStatus.ready)
      .length;

  double get progress {
    if (status == VolumePreparationStatus.ready) return 1;
    if (chapters.isEmpty) {
      return 0;
    }
    final chapterProgress = chapters.fold<double>(
      0,
      (sum, chapter) => sum + chapter.progress,
    );
    final analyzed = (chapterProgress / chapters.length).clamp(0, 1);
    if (stage == VolumePreparationStage.preparingAssets) {
      if (assetTotal == 0) return 0.95;
      final processed = assetReadyCount + assetNeedsReviewCount;
      return (0.75 + (processed / assetTotal) * 0.25).clamp(0, 1);
    }
    if (stage == VolumePreparationStage.connectingStoryAssets) return 0.99;
    if (stage == VolumePreparationStage.mergingStoryBible) return 0.75;
    return (analyzed * 0.75).clamp(0, 1);
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
