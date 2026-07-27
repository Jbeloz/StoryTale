import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/features/animated_story/data/story_analysis_contract.dart';
import 'package:storytale/src/features/animated_story/data/story_analysis_service.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_models.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_repository.dart';
import 'package:storytale/src/features/animated_story/data/story_entity_service.dart';
import 'package:storytale/src/features/animated_story/data/volume_preparation_coordinator.dart';
import 'package:storytale/src/features/animated_story/data/volume_preparation_models.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('prepares every chapter and merges one volume inventory', () async {
    final book = _book();
    final stories = <String, ChapterStoryData>{};
    final repository = StoryBibleRepository();
    final job = VolumePreparationJobData.forBook(book);
    final coordinator = VolumePreparationCoordinator(
      analysisProvider: _AnalysisProvider(),
      entityProvider: _EntityProvider(),
      storyBibleRepository: repository,
    );

    await coordinator.prepare(
      book: book,
      job: job,
      localStory: _localStory,
      saveStory: (chapter, story) => stories[chapter.id] = story,
      onChanged: () {},
    );

    final bible = await repository.load(book.id);
    final prince = bible.entities.single;
    expect(job.status, VolumePreparationStatus.ready);
    expect(job.readyCount, 3);
    expect(job.progress, 1);
    expect(stories.keys, book.chapters.map((chapter) => chapter.id).toSet());
    expect(prince.canonicalName, 'Little Prince');
    expect(prince.aliases, contains('Prince'));
    expect(
      prince.chapterAppearanceIds,
      book.chapters.map((chapter) => chapter.id),
    );
    expect(
      prince.speakingChapterIds,
      book.chapters.map((chapter) => chapter.id),
    );
  });

  test('pauses between chapters and resumes the same volume job', () async {
    final book = _book();
    final stories = <String, ChapterStoryData>{};
    final job = VolumePreparationJobData.forBook(book);
    final coordinator = VolumePreparationCoordinator(
      analysisProvider: _AnalysisProvider(),
      entityProvider: _EntityProvider(),
      storyBibleRepository: StoryBibleRepository(),
    );

    await coordinator.prepare(
      book: book,
      job: job,
      localStory: _localStory,
      saveStory: (chapter, story) => stories[chapter.id] = story,
      onChanged: () {
        if (job.readyCount == 1) job.pauseRequested = true;
      },
    );

    expect(job.status, VolumePreparationStatus.paused);
    expect(job.readyCount, 1);

    await coordinator.prepare(
      book: book,
      job: job,
      localStory: _localStory,
      saveStory: (chapter, story) => stories[chapter.id] = story,
      onChanged: () {},
    );

    expect(job.status, VolumePreparationStatus.ready);
    expect(job.readyCount, 3);
  });
}

class _EntityProvider implements StoryEntityProvider {
  @override
  bool get isConfigured => true;

  @override
  Future<List<StoryEntityData>> extract({
    required BookData book,
    required ChapterData chapter,
    required BookStoryBibleData bible,
  }) async {
    return [
      StoryEntityData(
        entityId: 'little_prince',
        kind: StoryEntityKind.human,
        canonicalName: chapter.id.endsWith('1') ? 'Little Prince' : 'Prince',
        aliases: chapter.id.endsWith('1')
            ? const ['Prince']
            : const ['Little Prince'],
        description: 'The recurring main character.',
        firstSeenChapterId: chapter.id,
        sourceBlockIds: const ['block-1'],
        recurring: true,
        importance: StoryEntityImportance.focus,
        speaker: true,
        confidence: 0.98,
      ),
    ];
  }
}

class _AnalysisProvider implements StoryAnalysisProvider {
  @override
  bool get isConfigured => true;

  @override
  Future<ChapterStoryData> analyze({
    required ChapterData chapter,
    required StoryAnalysisCatalog catalog,
  }) async {
    return _localStory(chapter);
  }
}

BookData _book() {
  return BookData(
    id: 'book-1',
    title: 'Test Volume',
    author: 'Author',
    description: 'Description',
    tags: const [],
    chapters: List.generate(
      3,
      (index) => ChapterData(
        id: 'chapter-${index + 1}',
        title: 'Chapter ${index + 1}',
        originalText: 'The Little Prince speaks.',
      ),
    ),
  );
}

ChapterStoryData _localStory(ChapterData chapter) {
  return ChapterStoryData(
    chapterId: chapter.id,
    moral: 'Be kind.',
    cutscenes: [
      StoryCutsceneData(
        id: '${chapter.id}-scene',
        locationId: 'rose_garden',
        backgroundStateId: 'day',
        shots: const [],
      ),
    ],
  );
}
