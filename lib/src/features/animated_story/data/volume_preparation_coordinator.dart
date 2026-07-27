import '../../../shared/models/storytale_models.dart';
import 'story_analysis_contract.dart';
import 'story_analysis_service.dart';
import 'story_bible_models.dart';
import 'story_bible_repository.dart';
import 'story_entity_service.dart';
import 'volume_preparation_models.dart';

class VolumePreparationCoordinator {
  VolumePreparationCoordinator({
    required this.analysisProvider,
    required this.entityProvider,
    required this.storyBibleRepository,
  });

  final StoryAnalysisProvider analysisProvider;
  final StoryEntityProvider entityProvider;
  final StoryBibleRepository storyBibleRepository;

  Future<void> prepare({
    required BookData book,
    required VolumePreparationJobData job,
    required ChapterStoryData Function(ChapterData chapter) localStory,
    required void Function(ChapterData chapter, ChapterStoryData story)
    saveStory,
    required void Function() onChanged,
  }) async {
    job
      ..status = VolumePreparationStatus.preparing
      ..stage = VolumePreparationStage.analyzingChapters
      ..pauseRequested = false
      ..startedAt ??= DateTime.now()
      ..finishedAt = null
      ..lastError = null;
    job.addEvent('Preparing ${book.chapters.length} chapters');
    onChanged();

    var bible = entityProvider.isConfigured || analysisProvider.isConfigured
        ? await storyBibleRepository.load(book.id)
        : BookStoryBibleData.empty(book.id);
    for (final chapter in book.chapters) {
      final chapterJob = job.chapter(chapter.id);
      if (chapterJob.status == PreparationStatus.ready) continue;
      if (job.pauseRequested) {
        job
          ..status = VolumePreparationStatus.paused
          ..currentChapterId = null;
        job.addEvent('Preparation paused');
        onChanged();
        return;
      }

      job.currentChapterId = chapter.id;
      chapterJob
        ..status = PreparationStatus.preparing
        ..progress = 0.15
        ..lastError = null;
      job.addEvent('Analyzing ${chapter.title}');
      onChanged();

      try {
        if (entityProvider.isConfigured) {
          final candidates = await entityProvider.extract(
            book: book,
            chapter: chapter,
            bible: bible,
          );
          bible = bible.mergeCandidates(
            candidates
                .map((entity) => entity.withChapterAppearance(chapter.id))
                .toList(growable: false),
          );
          await storyBibleRepository.save(bible);
        }
        chapterJob.progress = 0.55;
        onChanged();

        final story = analysisProvider.isConfigured
            ? await analysisProvider.analyze(
                chapter: chapter,
                catalog: StoryAnalysisCatalog.fromStoryBible(bible),
              )
            : localStory(chapter);
        story.status = PreparationStatus.ready;
        saveStory(chapter, story);
        chapterJob
          ..status = PreparationStatus.ready
          ..progress = 1;
        job.addEvent('${chapter.title} is ready');
      } catch (error) {
        final story = localStory(chapter)..status = PreparationStatus.ready;
        saveStory(chapter, story);
        chapterJob
          ..status = PreparationStatus.ready
          ..progress = 1
          ..lastError = '$error';
        job.addEvent('${chapter.title} used the safe local preview');
      }
      onChanged();
    }

    job
      ..stage = VolumePreparationStage.mergingStoryBible
      ..currentChapterId = null
      ..entityCount = bible.entities.length
      ..reusedRequirementCount = _requirementCount(book, localStory);
    job.addEvent('Merged the volume inventory');
    onChanged();

    job
      ..stage = VolumePreparationStage.ready
      ..status = VolumePreparationStatus.ready
      ..finishedAt = DateTime.now();
    job.addEvent('Animated volume preview is ready');
    onChanged();
  }

  int _requirementCount(
    BookData book,
    ChapterStoryData Function(ChapterData chapter) storyFor,
  ) {
    final keys = <String>{};
    for (final chapter in book.chapters) {
      for (final requirement in storyFor(chapter).backgroundRequirements) {
        keys.add(requirement.key);
      }
    }
    return keys.length;
  }
}
