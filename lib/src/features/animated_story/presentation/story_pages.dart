import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/sprite_layer_processor.dart';
import '../data/story_bible_repository.dart';
import '../data/story_artwork_service.dart';
import '../data/story_analysis_service.dart';
import '../data/story_asset_binary_store.dart';
import '../data/story_background_repository.dart';
import '../data/story_entity_service.dart';
import '../data/story_foreground_repository.dart';
import '../data/visual_novel_background_brief.dart';
import '../data/volume_preparation_coordinator.dart';
import '../data/volume_preparation_models.dart';
import 'story_background_catalog_page.dart';
import 'story_bible_review_page.dart';
import 'story_foreground_inventory_page.dart';
import 'sprite_positioner_page.dart';
import 'widgets/story_shot_transition.dart';
import 'widgets/visual_novel_stage.dart';

class StoryPreparationPage extends StatefulWidget {
  const StoryPreparationPage({
    super.key,
    this.analysisProvider,
    this.entityProvider,
    this.storyBibleRepository,
  });

  final StoryAnalysisProvider? analysisProvider;
  final StoryEntityProvider? entityProvider;
  final StoryBibleRepository? storyBibleRepository;

  @override
  State<StoryPreparationPage> createState() => _StoryPreparationPageState();
}

class _StoryPreparationPageState extends State<StoryPreparationPage> {
  late final StoryAnalysisProvider _analysisProvider;
  late final StoryEntityProvider _entityProvider;
  late final StoryBibleRepository _storyBibleRepository;

  @override
  void initState() {
    super.initState();
    _analysisProvider =
        widget.analysisProvider ?? GeminiStoryAnalysisProvider();
    _entityProvider = widget.entityProvider ?? GeminiStoryEntityProvider();
    _storyBibleRepository =
        widget.storyBibleRepository ?? StoryBibleRepository();
  }

  Future<void> _prepare() async {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    if (book == null) return;
    final job = controller.volumeJobFor(book);
    if (job.status == VolumePreparationStatus.preparing) return;
    final coordinator = VolumePreparationCoordinator(
      analysisProvider: _analysisProvider,
      entityProvider: _entityProvider,
      storyBibleRepository: _storyBibleRepository,
    );
    try {
      await coordinator.prepare(
        book: book,
        job: job,
        localStory: controller.storyFor,
        saveStory: controller.replaceStory,
        onChanged: controller.volumePreparationChanged,
      );
    } catch (error) {
      job
        ..status = VolumePreparationStatus.failed
        ..currentChapterId = null
        ..lastError = '$error';
      job.addEvent('Preparation stopped');
      controller.volumePreparationChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    if (book == null) {
      return const StoryTaleInfoPage(
        title: 'Animated Story',
        description: 'Choose a book before preparing Animated Story Mode.',
      );
    }
    final job = controller.volumeJobFor(book);
    final preparing = job.status == VolumePreparationStatus.preparing;
    final ready = job.status == VolumePreparationStatus.ready;
    final currentJob = job.currentChapterId == null
        ? null
        : job.chapter(job.currentChapterId!);
    return StoryTaleAppShell(
      title: 'Animated Story',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('${job.readyCount} of ${job.chapters.length} chapters ready'),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: job.progress),
          const SizedBox(height: 10),
          Text(_activityLabel(job, currentJob)),
          if (preparing &&
              job.stage == VolumePreparationStage.preparingAssets) ...[
            const SizedBox(height: 6),
            Text(
              '${job.assetReadyCount} ready • '
              '${job.assetNeedsReviewCount} need review • '
              '${job.assetTotal - job.assetReadyCount - job.assetNeedsReviewCount} '
              'remaining',
            ),
          ],
          const SizedBox(height: 12),
          if (preparing)
            OutlinedButton.icon(
              onPressed: () => controller.requestVolumePreparationPause(book),
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            )
          else if (!ready)
            FilledButton.icon(
              onPressed: _prepare,
              icon: Icon(
                job.status == VolumePreparationStatus.paused
                    ? Icons.play_arrow
                    : job.status == VolumePreparationStatus.failed
                    ? Icons.refresh
                    : Icons.auto_awesome,
              ),
              label: Text(
                job.status == VolumePreparationStatus.paused
                    ? 'Resume Preparation'
                    : job.status == VolumePreparationStatus.failed
                    ? 'Retry Preparation'
                    : 'Prepare Animated Volume',
              ),
            ),
          if (ready && job.assetNeedsReviewCount > 0)
            OutlinedButton.icon(
              onPressed: _prepare,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Missing Artwork'),
            ),
          if (job.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Preparation stopped. Open details for the error, then retry.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Text('Chapters', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final chapterJob in job.chapters)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_chapterIcon(chapterJob.status)),
              title: Text(chapterJob.title),
              subtitle: chapterJob.lastError == null
                  ? null
                  : const Text('Ready with safe local preview'),
              trailing: Text(_chapterStatus(chapterJob.status)),
              enabled: chapterJob.status == PreparationStatus.ready,
              onTap: chapterJob.status != PreparationStatus.ready
                  ? null
                  : () {
                      final chapter = controller.chapterById(
                        book,
                        chapterJob.chapterId,
                      );
                      if (chapter == null) return;
                      controller.openBook(book, chapter: chapter);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AnimatedStoryPage(),
                        ),
                      );
                    },
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('View details'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Elapsed'),
                trailing: Text(_durationLabel(job.elapsed)),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Merged story subjects'),
                trailing: Text('${job.entityCount}'),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Reusable backgrounds'),
                trailing: Text('${job.reusedRequirementCount}'),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Foreground subjects'),
                trailing: Text('${job.foregroundEntityCount}'),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Foreground variants'),
                trailing: Text('${job.foregroundAssetCount}'),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Ready artwork'),
                trailing: Text('${job.assetReadyCount}'),
              ),
              if (job.assetNeedsReviewCount > 0)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Artwork using safe fallback'),
                  trailing: Text('${job.assetNeedsReviewCount}'),
                ),
              if (job.lastError != null)
                SelectableText(job.lastError!, textAlign: TextAlign.left),
              for (final event in job.events.take(5))
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(event),
                  ),
                ),
            ],
          ),
          if (ready)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Preparation tools'),
              children: [
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Story Bible'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StoryBibleReviewPage(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.landscape_outlined),
                  title: const Text('Location backgrounds'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StoryBackgroundCatalogPage(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.pets_outlined),
                  title: const Text('Foreground assets'),
                  subtitle: Text(
                    '${job.foregroundApprovedCount} of '
                    '${job.foregroundAssetCount} approved',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StoryForegroundInventoryPage(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.accessibility_new),
                  title: const Text('Sprites'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SpriteReviewPage()),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _activityLabel(
    VolumePreparationJobData job,
    ChapterPreparationJobData? chapter,
  ) {
    return switch (job.status) {
      VolumePreparationStatus.notStarted =>
        'Prepare every chapter in this volume once.',
      VolumePreparationStatus.preparing =>
        job.stage == VolumePreparationStage.connectingStoryAssets
            ? 'Connecting prepared artwork to Chapter 1...'
            : job.stage == VolumePreparationStage.preparingAssets
            ? job.currentAssetLabel == null
                  ? 'Preparing reusable story artwork...'
                  : 'Preparing ${job.currentAssetLabel}...'
            : chapter == null
            ? 'Merging the volume inventory...'
            : 'Analyzing ${chapter.title}...',
      VolumePreparationStatus.paused => 'Preparation paused.',
      VolumePreparationStatus.ready => 'Animated volume preview is ready.',
      VolumePreparationStatus.failed => 'Preparation needs to be retried.',
    };
  }

  IconData _chapterIcon(PreparationStatus status) {
    return switch (status) {
      PreparationStatus.ready => Icons.check_circle_outline,
      PreparationStatus.preparing => Icons.hourglass_top,
      PreparationStatus.failed => Icons.error_outline,
      PreparationStatus.notStarted => Icons.circle_outlined,
    };
  }

  String _chapterStatus(PreparationStatus status) {
    return switch (status) {
      PreparationStatus.ready => 'Ready',
      PreparationStatus.preparing => 'Preparing',
      PreparationStatus.failed => 'Failed',
      PreparationStatus.notStarted => 'Waiting',
    };
  }

  String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class AnimatedStoryPage extends StatefulWidget {
  const AnimatedStoryPage({
    super.key,
    this.backgroundRepository,
    this.foregroundRepository,
  });

  final StoryBackgroundRepository? backgroundRepository;
  final StoryForegroundRepository? foregroundRepository;

  @override
  State<AnimatedStoryPage> createState() => _AnimatedStoryPageState();
}

class _AnimatedStoryPageState extends State<AnimatedStoryPage> {
  late final StoryBackgroundRepository _backgroundRepository;
  late final StoryForegroundRepository _foregroundRepository;
  int _shotIndex = 0;
  int _beatIndex = 0;
  bool _playing = false;
  bool _filipinoSubtitles = false;
  bool _music = true;
  String? _assetBookId;
  Set<String> _readyBackgroundIds = const {};
  Map<String, String> _backgroundIdByRequirement = const {};
  Set<String> _readyForegroundIds = const {};

  @override
  void initState() {
    super.initState();
    _backgroundRepository =
        widget.backgroundRepository ?? StoryBackgroundRepository();
    _foregroundRepository =
        widget.foregroundRepository ?? StoryForegroundRepository();
    StoryBackgroundRepository.revision.addListener(_assetCatalogChanged);
    StoryForegroundRepository.revision.addListener(_assetCatalogChanged);
    StoryAssetBinaryStore.revision.addListener(_assetCatalogChanged);
  }

  @override
  void dispose() {
    StoryBackgroundRepository.revision.removeListener(_assetCatalogChanged);
    StoryForegroundRepository.revision.removeListener(_assetCatalogChanged);
    StoryAssetBinaryStore.revision.removeListener(_assetCatalogChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bookId = StoryTaleScope.of(context).currentBook?.id;
    if (bookId == null || bookId == _assetBookId) return;
    _assetBookId = bookId;
    _loadAssets(bookId);
  }

  void _assetCatalogChanged() {
    final bookId = _assetBookId;
    if (bookId != null) _loadAssets(bookId);
  }

  Future<void> _loadAssets(String bookId) async {
    final backgrounds = await _backgroundRepository.loadReady(bookId);
    final foregrounds = await _foregroundRepository.loadReady(bookId);
    if (!mounted || _assetBookId != bookId) return;
    setState(() {
      _readyBackgroundIds = {for (final asset in backgrounds) asset.assetId};
      _backgroundIdByRequirement = {
        for (final asset in backgrounds) asset.key: asset.assetId,
      };
      _readyForegroundIds = {for (final asset in foregrounds) asset.assetId};
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    final chapter = controller.currentChapter;
    if (book == null || chapter == null) {
      return const StoryTaleInfoPage(
        title: 'Story Mode',
        description: 'Choose a book chapter before opening Story Mode.',
      );
    }
    final story = controller.storyFor(chapter);
    if (story.status != PreparationStatus.ready) {
      return StoryTaleInfoPage(
        title: 'Story Mode',
        description: '${chapter.title} has not been prepared yet.',
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const StoryPreparationPage()),
            ),
            child: const Text('Prepare Chapter'),
          ),
        ],
      );
    }
    final shots = story.shots;
    final shot = shots[_shotIndex];
    final backgroundRequirement = story.backgroundRequirementForShot(
      _shotIndex,
    );
    final backgroundAssetId = _readyBackgroundIds.contains(shot.backgroundId)
        ? shot.backgroundId
        : backgroundRequirement == null
        ? null
        : _backgroundIdByRequirement[backgroundRequirement.key];
    final backgroundBytes = backgroundAssetId == null
        ? null
        : StoryAssetBinaryStore.read(backgroundAssetId);
    final focusAssetBytes = <String, Uint8List>{};
    for (final layer in shot.focusAssetLayers) {
      if (!_readyForegroundIds.contains(layer.assetId)) continue;
      final bytes = StoryAssetBinaryStore.read(layer.assetId);
      if (bytes != null) focusAssetBytes[layer.assetId] = bytes;
    }
    final beat = shot.beats[_beatIndex];
    final subtitle = _filipinoSubtitles
        ? beat.filipinoText ?? 'Filipino: ${beat.originalText}'
        : beat.originalText;
    final media = MediaQuery.maybeOf(context);
    final reducedMotion =
        media?.disableAnimations == true || media?.accessibleNavigation == true;
    final transitionDuration = storyShotTransitionDuration(
      shot.transitionId,
      reducedMotion: reducedMotion,
    );

    return StoryTaleAppShell(
      title: '${book.title} • ${chapter.title}',
      actions: [
        IconButton(
          key: const Key('reload-story-backgrounds'),
          tooltip: 'Reload prepared artwork',
          onPressed: () => _loadAssets(book.id),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Table of contents',
          onPressed: () => _showContents(context),
          icon: const Icon(Icons.toc),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedSwitcher(
                    duration: transitionDuration,
                    reverseDuration: transitionDuration,
                    transitionBuilder: (child, animation) {
                      return buildStoryShotTransition(
                        transitionId: shot.transitionId,
                        reducedMotion: reducedMotion,
                        animation: animation,
                        child: child,
                      );
                    },
                    child: VisualNovelStage(
                      key: ValueKey('story-shot-${shot.id}'),
                      shot: shot,
                      speaker: beat.speakerId,
                      subtitle: subtitle,
                      backgroundBytes: backgroundBytes,
                      focusAssetBytes: focusAssetBytes,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                LinearProgressIndicator(value: _storyProgress(story)),
                Text(
                  'Cutscene ${story.cutsceneNumberForShot(_shotIndex)} • '
                  'Shot ${_shotIndex + 1} of ${shots.length} • '
                  'Line ${_beatIndex + 1} of ${shot.beats.length}',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('story-previous'),
                      tooltip: 'Previous line',
                      onPressed: _shotIndex == 0 && _beatIndex == 0
                          ? null
                          : () => _previous(story),
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filled(
                      onPressed: () => setState(() => _playing = !_playing),
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton(
                      key: const Key('story-next'),
                      tooltip: 'Next line',
                      onPressed: () => _next(story),
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('Filipino subtitles'),
                      selected: _filipinoSubtitles,
                      onSelected: (value) {
                        setState(() => _filipinoSubtitles = value);
                      },
                    ),
                    FilterChip(
                      label: const Text('Music'),
                      selected: _music,
                      onSelected: (value) => setState(() => _music = value),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.record_voice_over_outlined),
                      label: const Text('Voice'),
                      onPressed: () => _showVoiceSheet(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _previous(ChapterStoryData story) => setState(() {
    if (_beatIndex > 0) {
      _beatIndex--;
    } else {
      _shotIndex--;
      _beatIndex = story.shots[_shotIndex].beats.length - 1;
    }
    _playing = false;
  });

  void _next(ChapterStoryData story) {
    final shots = story.shots;
    if (_beatIndex < shots[_shotIndex].beats.length - 1) {
      setState(() {
        _beatIndex++;
        _playing = false;
      });
    } else if (_shotIndex < shots.length - 1) {
      setState(() {
        _shotIndex++;
        _beatIndex = 0;
        _playing = false;
      });
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChapterMoralPage()));
    }
  }

  double _storyProgress(ChapterStoryData story) {
    final completed = story.shots
        .take(_shotIndex)
        .fold<int>(0, (total, shot) => total + shot.beats.length);
    final total = story.shots.fold<int>(
      0,
      (sum, shot) => sum + shot.beats.length,
    );
    if (total == 0) return 0;
    return (completed + _beatIndex + 1) / total;
  }

  Future<void> _showContents(BuildContext context) async {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    if (book == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Chapter Story Modes')),
            ...book.chapters.map((chapter) {
              final story = controller.storyFor(chapter);
              return ChapterListTile(
                chapter: chapter,
                trailing: Chip(
                  label: Text(
                    story.status == PreparationStatus.ready
                        ? 'Ready'
                        : 'Prepare',
                  ),
                ),
                onTap: () {
                  controller.openBook(book, chapter: chapter);
                  Navigator.pop(sheetContext);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => story.status == PreparationStatus.ready
                          ? const AnimatedStoryPage()
                          : const StoryPreparationPage(),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showVoiceSheet(BuildContext context) {
    final voices = StoryTaleScope.of(context).voices;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: voices
              .map(
                (voice) => ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: Text(voice.name),
                  subtitle: Text(voice.role),
                  enabled: voice.status == PreparationStatus.ready,
                  onTap: () => Navigator.pop(context),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class ChapterMoralPage extends StatelessWidget {
  const ChapterMoralPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final chapter = controller.currentChapter;
    final moral = chapter == null
        ? 'Every story gives us something to remember.'
        : controller.storyFor(chapter).moral;
    return StoryTaleInfoPage(
      title: 'Chapter Moral',
      description: moral,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.replay),
          label: const Text('Return to Story'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Back to Library'),
        ),
      ],
    );
  }
}

class SpriteReviewPage extends StatefulWidget {
  const SpriteReviewPage({super.key});

  @override
  State<SpriteReviewPage> createState() => _SpriteReviewPageState();
}

class _SpriteReviewPageState extends State<SpriteReviewPage> {
  final _service = StoryArtworkService();
  final _processor = const SpriteLayerProcessor();
  final _spriteDetails = TextEditingController(
    text:
        'a kind young prince with short golden hair, a long blue coat, '
        'cream trousers, and brown boots',
  );
  final _backgroundDetails = TextEditingController(
    text:
        'a moonlit rose garden on a tiny asteroid with a gentle purple-blue '
        'sky and room for two character sprites',
  );
  _ArtworkMode _mode = _ArtworkMode.sprite;
  Uint8List? _generatedImage;
  SpriteLayers? _spriteLayers;
  _SpritePreview _spritePreview = _SpritePreview.rejoined;
  String? _error;
  bool _generating = false;

  @override
  void dispose() {
    _spriteDetails.dispose();
    _backgroundDetails.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _generatedImage = null;
      _spriteLayers = null;
      _error = null;
    });
    try {
      if (_mode == _ArtworkMode.sprite) {
        final master = await _service.generateSpriteMaster(_spriteDetails.text);
        final layers = _processor.process(master);
        if (mounted) {
          setState(() {
            _spriteLayers = layers;
            _spritePreview = _SpritePreview.rejoined;
          });
        }
      } else {
        final background = await _service.generateBackground(
          VisualNovelBackgroundBrief.fromApprovedLocation(
            locationId: 'preview',
            stateId: 'unspecified',
            place: 'Preview location',
            sourceBrief: _backgroundDetails.text,
          ),
        );
        if (mounted) setState(() => _generatedImage = background.bytes);
      }
    } on ArtworkGenerationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The story artwork could not be generated.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoryTaleAppShell(
      title: 'Review Story Artwork',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_ArtworkMode>(
            segments: const [
              ButtonSegment(
                value: _ArtworkMode.sprite,
                icon: Icon(Icons.face_retouching_natural_outlined),
                label: Text('Sprite'),
              ),
              ButtonSegment(
                value: _ArtworkMode.background,
                icon: Icon(Icons.landscape_outlined),
                label: Text('Background'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => setState(() {
              _mode = selection.first;
              _generatedImage = null;
              _spriteLayers = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          Text(
            _mode == _ArtworkMode.sprite
                ? 'Gemini Sprite Test'
                : 'Cloudflare Background Test',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _service.isConfigured
                ? _mode == _ArtworkMode.sprite
                      ? 'Ready. Gemini 3.1 Flash Image creates character sprites.'
                      : 'Ready. Cloudflare Workers AI creates chapter backgrounds.'
                : 'Token not loaded. Add it to .env and restart with the run script.',
          ),
          const SizedBox(height: 8),
          const Text(
            'The app calls the private Worker. Your Gemini API key stays on the '
            'server and is never added to Flutter.',
          ),
          if (_mode == _ArtworkMode.sprite) ...[
            const SizedBox(height: 8),
            const Text(
              'Gemini makes one master using all three references. StoryTale '
              'then removes the green background and splits that same image, '
              'so the head and body always fit when rejoined.',
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _mode == _ArtworkMode.sprite
                ? _spriteDetails
                : _backgroundDetails,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _mode == _ArtworkMode.sprite
                  ? 'Character appearance'
                  : 'Background scene description',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: _generating
                ? const Center(child: CircularProgressIndicator())
                : _previewImage != null
                ? Image.memory(_previewImage!, fit: BoxFit.contain)
                : Image.asset(_placeholderAsset, fit: BoxFit.contain),
          ),
          if (_mode == _ArtworkMode.sprite && _spriteLayers != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _SpritePreview.values
                  .map(
                    (preview) => ChoiceChip(
                      label: Text(preview.label),
                      selected: _spritePreview == preview,
                      onSelected: (_) {
                        setState(() => _spritePreview = preview);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  !_hasGeneratedArtwork
                      ? _mode == _ArtworkMode.sprite
                            ? 'Generate Master Sprite'
                            : 'Generate Background'
                      : 'Regenerate',
                ),
              ),
              OutlinedButton.icon(
                onPressed: !_hasGeneratedArtwork
                    ? null
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: Text(
                  _mode == _ArtworkMode.sprite
                      ? 'Accept Sprite'
                      : 'Accept Background',
                ),
              ),
              if (_mode == _ArtworkMode.sprite)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SpritePositionerPage(),
                    ),
                  ),
                  icon: const Icon(Icons.accessibility_new),
                  label: const Text('Open Sprite Studio'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String get _placeholderAsset {
    if (_mode == _ArtworkMode.background) {
      return 'assets/images/backgrounds/cloudflare_examples/'
          'moonlit-rose-garden.jpg';
    }
    return 'assets/images/characters/references/full-proportion.png';
  }

  bool get _hasGeneratedArtwork => _mode == _ArtworkMode.sprite
      ? _spriteLayers != null
      : _generatedImage != null;

  Uint8List? get _previewImage {
    if (_mode == _ArtworkMode.background) return _generatedImage;
    final layers = _spriteLayers;
    if (layers == null) return null;
    return switch (_spritePreview) {
      _SpritePreview.source => layers.source,
      _SpritePreview.head => layers.head,
      _SpritePreview.body => layers.body,
      _SpritePreview.rejoined => layers.rejoined,
    };
  }
}

enum _ArtworkMode { sprite, background }

enum _SpritePreview {
  source('Gemini source'),
  head('Head'),
  body('Body'),
  rejoined('Rejoined');

  const _SpritePreview(this.label);

  final String label;
}
