import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/character_design_brief.dart';
import '../data/character_sheet_contract.dart';
import '../data/character_sheet_generation.dart';
import '../data/character_sheet_package.dart';
import '../data/character_sheet_processor.dart';
import '../data/sprite_appearance.dart';
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
import 'story_human_catalog_page.dart';
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
                title: const Text('Book characters'),
                trailing: Text(
                  '${job.humanReadyCount}/${job.humanEntityCount}',
                ),
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
                  title: const Text('Book characters'),
                  subtitle: Text(
                    '${job.humanReadyCount} of '
                    '${job.humanEntityCount} ready',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StoryHumanCatalogPage(),
                    ),
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
  final _sheetProcessor = CharacterSheetProcessor();
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
  // Character Sheet is the live contract. Sprite is the Phase 7G whole-character
  // master, which was rejected because splitting it cannot recover the exact
  // StoryTale geometry, and both cost the same paid request. Landing on the
  // rejected one is how a restart turns a Character Sheet run into a legacy one.
  _ArtworkMode _mode = _ArtworkMode.characterSheet;

  /// Skips the six face and four pose compositions while we are iterating on
  /// what the provider draws.
  ///
  /// On by default because the proof pass is most of the cost of a run and
  /// blocks this thread, and because it cannot hide a bad result: a package
  /// without proofs can never be `ready`, and it says so in its own errors.
  bool _skipSheetProofs = true;

  /// The local admin server `tool/run_storytale.ps1` starts beside the app, the
  /// same one Sprite Studio saves poses and appearance through.
  static const _adminUrl = 'http://127.0.0.1:52828';
  Uint8List? _generatedImage;
  CharacterSheetGenerationResult? _characterSheetResult;
  CharacterSheetPackage? _characterSheetPackage;
  _CharacterSheetReviewGroup _sheetReviewGroup =
      _CharacterSheetReviewGroup.sheet;
  String _sheetFaceId = 'neutral';
  String _sheetPoseId = 'neutral';
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
      _characterSheetResult = null;
      _characterSheetPackage = null;
      _sheetReviewGroup = _CharacterSheetReviewGroup.sheet;
      _sheetFaceId = 'neutral';
      _sheetPoseId = 'neutral';
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
      } else if (_mode == _ArtworkMode.characterSheet) {
        final appearance = await const SpriteAppearanceRepository().load();
        final actor = SpriteAppearanceCatalog.actor(appearance.actorId);
        final request = CharacterSheetGenerationRequest(
          brief: CharacterDesignBrief(
            bookId: 'developer-preview',
            characterId: 'manual-character-sheet',
            canonicalName: 'Preview character',
            actorProfileId: actor.id,
            sourceDescription: _spriteDetails.text,
          ),
          skinTone: appearance.skinTone,
          frontHairId: appearance.frontHairId,
          backHairId: appearance.hairStyleId,
          outfitRequirements: _spriteDetails.text,
        );
        final contract = await CharacterSheetContractRepository().load();
        final cached = CharacterSheetPackageStore.read(
          request.fingerprint(contract),
        );
        if (cached != null && cached.validation.isValid) {
          if (mounted) {
            setState(() {
              _characterSheetResult = cached.generation;
              _characterSheetPackage = cached;
              _sheetReviewGroup = _CharacterSheetReviewGroup.sheet;
              _sheetFaceId = 'neutral';
              _sheetPoseId = 'neutral';
              _generatedImage = cached.neutralProofBytes;
              _error = null;
            });
          }
          return;
        }
        final result = await _service.generateCharacterSheet(request);
        // Show what came back before cutting and composing it. Processing runs
        // on this thread and takes seconds, and the reason to look at a paid
        // sheet is usually that something went wrong, so waiting for the whole
        // proof pass hides the only image that explains why.
        if (mounted) {
          setState(() {
            _characterSheetResult = result;
            _sheetReviewGroup = _CharacterSheetReviewGroup.sheet;
            _generatedImage = result.bytes;
          });
        }
        final package = await _sheetProcessor.process(
          request: request,
          generation: result,
          composeProofs: !_skipSheetProofs,
        );
        await _saveSheetDiagnostics(result, package.validation.toJson());
        if (mounted) {
          setState(() {
            _characterSheetPackage = package;
            _sheetFaceId = 'neutral';
            _sheetPoseId = 'neutral';
            _error = package.validation.isValid
                ? null
                : package.validation.errorMessage;
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
    } on CharacterSheetProcessingException catch (error) {
      // The sheet was still paid for, so keep it even though it never reached a
      // package. A sheet that breaks the processor is the most useful one to
      // have on disk, not the least.
      final result = _characterSheetResult;
      if (result != null) {
        await _saveSheetDiagnostics(result, {'processingError': error.message});
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The story artwork could not be generated.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Writes the paid sheet, the prompt that bought it, and its validation report
  /// to disk through the local admin server.
  ///
  /// Every character-sheet request costs money, and until this the result lived
  /// only in the browser tab that made it: a defect could be diagnosed from a
  /// screenshot or not at all, and re-measuring one meant paying again.
  ///
  /// Never fails the run. The sheet is already on screen and already paid for,
  /// so a missing admin server must not turn a usable result into an error —
  /// the same rule the pose and appearance saves follow.
  Future<void> _saveSheetDiagnostics(
    CharacterSheetGenerationResult result,
    Map<String, dynamic> report,
  ) async {
    try {
      await http.post(
        Uri.parse('$_adminUrl/character-sheet-diagnostics'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestId': result.requestId.isEmpty
              ? result.requestFingerprint
              : result.requestId,
          'requestFingerprint': result.requestFingerprint,
          'contract': '${result.contractId}@${result.contractVersion}',
          'provider': result.provider,
          'model': result.model,
          'generatedAt': result.generatedAt,
          'mimeType': result.mimeType,
          'width': result.width,
          'height': result.height,
          'prompt': result.prompt,
          'sheetBase64': base64Encode(result.bytes),
          'report': report,
        }),
      );
    } catch (_) {
      // Local admin offline. The result stays on screen either way.
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
                value: _ArtworkMode.characterSheet,
                icon: Icon(Icons.grid_view_outlined),
                label: Text('Sheet'),
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
              _characterSheetResult = null;
              _characterSheetPackage = null;
              _sheetReviewGroup = _CharacterSheetReviewGroup.sheet;
              _sheetFaceId = 'neutral';
              _sheetPoseId = 'neutral';
              _spriteLayers = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          Text(switch (_mode) {
            _ArtworkMode.sprite => 'Legacy Gemini Sprite Test',
            _ArtworkMode.characterSheet => 'Character Sheet V4 Request',
            _ArtworkMode.background => 'Cloudflare Background Test',
          }, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            _service.isConfigured
                ? _mode == _ArtworkMode.background
                      ? 'Ready. Cloudflare Workers AI creates chapter backgrounds.'
                      : 'Ready. Gemini 3.1 Flash Image creates character artwork.'
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
              'Legacy Phase 7G path, kept for comparison only. Gemini draws a '
              'whole character and StoryTale splits it, which means the head '
              'and body are generated rather than the locked rig parts. It was '
              'rejected for exactly that reason, and it still costs a paid '
              'request. Use Character Sheet for real work.',
            ),
          ],
          if (_mode == _ArtworkMode.characterSheet) ...[
            const SizedBox(height: 8),
            const Text(
              'Uses the current Sprite Studio actor, skin tone, front hair, '
              'and selected Short, Medium, Long, or None back-hair slot. It '
              'sends the locked guide, neutral reference, and three masks in '
              'one paid request and never retries automatically.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _skipSheetProofs,
              onChanged: _generating
                  ? null
                  : (value) =>
                        setState(() => _skipSheetProofs = value ?? false),
              title: const Text('Testing: skip face and pose proofs'),
              subtitle: const Text(
                'Cuts the sheet and stops. Much faster, but the package can '
                'never be accepted. Turn this off for an acceptance run.',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _mode != _ArtworkMode.background
                ? _spriteDetails
                : _backgroundDetails,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _mode != _ArtworkMode.background
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
          if (_mode == _ArtworkMode.characterSheet) ...[
            const SizedBox(height: 12),
            _characterSheetReviewPanel(context, _characterSheetPackage),
          ],
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
          if (_mode == _ArtworkMode.characterSheet &&
              _characterSheetResult != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_characterSheetResult!.contractId}@'
              '${_characterSheetResult!.contractVersion} • '
              '${_characterSheetResult!.provider} • '
              '${_characterSheetResult!.model}\n'
              'Request ${_characterSheetResult!.requestId} • '
              'Fingerprint '
              '${_characterSheetResult!.requestFingerprint.substring(0, 12)}…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_characterSheetPackage != null) ...[
              const SizedBox(height: 6),
              Text(
                _characterSheetPackage!.validation.isValid
                    ? '${_characterSheetPackage!.nonEmptyLayerCount} '
                          'transparent layers packaged • four pose proofs '
                          'assembled locally'
                    : 'Package needs attention • the safe locked-template '
                          'proof is shown',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
                onPressed:
                    _generating ||
                        (_mode == _ArtworkMode.characterSheet &&
                            (_characterSheetPackage?.validation.isValid ??
                                false))
                    ? null
                    : _generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  _mode == _ArtworkMode.characterSheet &&
                          (_characterSheetPackage?.validation.isValid ?? false)
                      ? 'Ready Package Reused'
                      : !_hasGeneratedArtwork
                      ? switch (_mode) {
                          _ArtworkMode.sprite => 'Generate Legacy Master',
                          _ArtworkMode.characterSheet =>
                            'Generate Character Sheet',
                          _ArtworkMode.background => 'Generate Background',
                        }
                      : 'Regenerate',
                ),
              ),
              OutlinedButton.icon(
                onPressed: !_hasGeneratedArtwork
                    ? null
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: Text(switch (_mode) {
                  _ArtworkMode.sprite => 'Accept Sprite',
                  _ArtworkMode.characterSheet => 'Keep Sheet Preview',
                  _ArtworkMode.background => 'Accept Background',
                }),
              ),
              if (_mode != _ArtworkMode.background)
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Sprite Studio'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _characterSheetReviewPanel(
    BuildContext context,
    CharacterSheetPackage? package,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Package proof', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in _CharacterSheetReviewGroup.values)
                ChoiceChip(
                  label: Text(group.label),
                  selected: _sheetReviewGroup == group,
                  onSelected: (_) => setState(() {
                    _sheetReviewGroup = group;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (package == null)
            const Text(
              'No accepted package yet. These read-only groups populate after '
              'one sheet is generated and processed. Viewing them never sends '
              'a provider request.',
            )
          else ...[
            if (_sheetReviewGroup == _CharacterSheetReviewGroup.faces) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final faceId in const [
                    'neutral',
                    'talking',
                    'happy',
                    'sad',
                    'angry',
                    'surprised',
                  ])
                    ChoiceChip(
                      label: Text(
                        package.validation.proofsByFace[faceId]?.label ??
                            faceId,
                      ),
                      selected: _sheetFaceId == faceId,
                      onSelected: (_) => setState(() {
                        _sheetFaceId = faceId;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_sheetReviewGroup == _CharacterSheetReviewGroup.poses) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final poseId in const [
                    'neutral',
                    'talking',
                    'pointing',
                    'walking',
                  ])
                    ChoiceChip(
                      label: Text(
                        package.validation.proofsByPose[poseId]?.label ??
                            poseId,
                      ),
                      selected: _sheetPoseId == poseId,
                      onSelected: (_) => setState(() {
                        _sheetPoseId = poseId;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            _characterSheetGroupDetails(context, package),
          ],
        ],
      ),
    );
  }

  Widget _characterSheetGroupDetails(
    BuildContext context,
    CharacterSheetPackage package,
  ) {
    final theme = Theme.of(context);
    switch (_sheetReviewGroup) {
      case _CharacterSheetReviewGroup.sheet:
        final generation = package.generation;
        final kilobytes = (package.sourceBytes.lengthInBytes / 1024).round();
        // Per-region rejection counts, worst first. The headline error gives one
        // sheet-wide percentage; this says which cells it came from, which is
        // the difference between "the provider redrew the body" and "one mask is
        // wrong".
        List<MapEntry<String, int>> worstOf(Map<String, int> counts) =>
            counts.entries.where((entry) => entry.value > 0).toList()
              ..sort((left, right) => right.value.compareTo(left.value));
        String line(String label, Map<String, int> counts) {
          final worst = worstOf(counts);
          if (worst.isEmpty) return '';
          return '\n$label: '
              '${worst.take(6).map((entry) => '${entry.key} ${entry.value}').join(', ')}';
        }

        // Two different failures, never merged into one list. "Repainted" is
        // damage to locked geometry; "drawn outside its window" is a part drawn
        // in the wrong place, which is what put a whole trouser leg above the
        // leg cells.
        final repainted = line(
          'Locked geometry repainted by cell',
          package.validation.rejectedPixelsByRegion,
        );
        final overspill = line(
          'Drawn outside its window by cell',
          package.validation.overspillPixelsByRegion,
        );
        return Text(
          'Exactly as returned, before cleaning • '
          '${generation.width}x${generation.height} ${generation.mimeType} • '
          '$kilobytes KB'
          '${repainted.isEmpty && overspill.isEmpty ? '\nEvery cell stayed inside its window and left the locked geometry alone.' : '$repainted$overspill'}',
          style: theme.textTheme.bodySmall,
        );
      case _CharacterSheetReviewGroup.character:
        return Text(
          package.validation.isValid
              ? '${package.characterName} • package ready • all six faces and '
                    'four poses passed'
              : '${package.characterName} • needs attention • safe locked '
                    'template shown',
        );
      case _CharacterSheetReviewGroup.layers:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final layer in package.layerMetadata.values)
              Chip(
                label: Text(
                  '${layer.regionId}: '
                  '${layer.empty ? 'Empty' : '${layer.visiblePixelCount} px'}',
                ),
              ),
          ],
        );
      case _CharacterSheetReviewGroup.faces:
        final proof = package.validation.proofsByFace[_sheetFaceId];
        if (proof == null) return const Text(_skippedProofsNotice);
        return Text(
          '${proof.label} • ${proof.width}x${proof.height} • '
          '${proof.visiblePixelCount} visible pixels • '
          '${proof.valid ? 'passed' : 'needs attention'}',
        );
      case _CharacterSheetReviewGroup.hair:
        final front = package.layerMetadata['front_hair'];
        if (front == null) return const Text('No front-hair layer was cut.');
        final back = package.selectedBackHairRegion == 'none'
            ? null
            : package.layerMetadata[package.selectedBackHairRegion];
        return Text(
          'Front: ${front.empty ? 'missing' : package.frontHairId} • '
          'Back: ${back == null ? 'None' : back.regionId} • native canvases '
          'preserved',
        );
      case _CharacterSheetReviewGroup.poses:
        final proof = package.validation.proofsByPose[_sheetPoseId];
        if (proof == null) return const Text(_skippedProofsNotice);
        return Text(
          '${proof.label} • ${proof.width}x${proof.height} • '
          '${proof.visiblePixelCount} visible pixels • '
          '${proof.valid ? 'passed' : 'needs attention'}',
        );
      case _CharacterSheetReviewGroup.details:
        return Text(
          '${package.contract.contractId}@${package.contract.contractVersion} • '
          '${package.generation.provider} • ${package.generation.model}\n'
          'Design ${package.generation.requestFingerprint.substring(0, 12)}… • '
          'geometry ${package.contract.lockedRig.geometryHash.substring(0, 12)}…\n'
          'Locked assets ${package.validation.lockedAssetsValid ? 'passed' : 'failed'} • '
          'identity ${package.validation.identityValid ? 'passed' : 'failed'} • '
          'faces ${package.validation.faceProofValid ? 'passed' : 'failed'} • '
          'poses ${package.validation.poseProofValid ? 'passed' : 'failed'}\n'
          '${package.validation.errors.isEmpty ? 'No validation errors.' : package.validation.errorMessage}',
          style: theme.textTheme.bodySmall,
        );
    }
  }

  String get _placeholderAsset {
    if (_mode == _ArtworkMode.background) {
      return 'assets/images/backgrounds/cloudflare_examples/'
          'moonlit-rose-garden.jpg';
    }
    if (_mode == _ArtworkMode.characterSheet) {
      // The canonical guide of the active contract, so the placeholder shows
      // the layout a request would actually send. Follow
      // CharacterSheetContractRepository.assetPath when that changes.
      return 'assets/images/characters/generation_templates/humanoid_v1/'
          'character_sheet_v4/guide_default_medium.png';
    }
    return 'assets/images/characters/references/full-proportion.png';
  }

  bool get _hasGeneratedArtwork => switch (_mode) {
    _ArtworkMode.sprite => _spriteLayers != null,
    _ArtworkMode.characterSheet =>
      _characterSheetPackage?.validation.isValid ?? false,
    _ArtworkMode.background => _generatedImage != null,
  };

  Uint8List? get _previewImage {
    if (_mode == _ArtworkMode.characterSheet) {
      final package = _characterSheetPackage;
      if (package == null) return _generatedImage;
      return switch (_sheetReviewGroup) {
        _CharacterSheetReviewGroup.sheet => package.sourceBytes,
        _CharacterSheetReviewGroup.character => package.neutralProofBytes,
        _CharacterSheetReviewGroup.layers => package.cleanBytes,
        _CharacterSheetReviewGroup.faces =>
          package.facePreviewBytesByExpression[_sheetFaceId] ??
              package.neutralProofBytes,
        _CharacterSheetReviewGroup.hair =>
          package.layerBytes['front_hair'] ?? package.neutralProofBytes,
        _CharacterSheetReviewGroup.poses =>
          package.previewBytesByPose[_sheetPoseId] ?? package.neutralProofBytes,
        _CharacterSheetReviewGroup.details => package.neutralProofBytes,
      };
    }
    if (_mode != _ArtworkMode.sprite) return _generatedImage;
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

enum _ArtworkMode { sprite, characterSheet, background }

/// Shown wherever a proof would be, when the testing switch skipped the pass.
const _skippedProofsNotice =
    'Face and pose proofs were skipped for testing. Turn the switch off and '
    'generate again to see them.';

enum _CharacterSheetReviewGroup {
  /// The exact bytes the provider returned, before any cleaning or composition.
  ///
  /// First because it is the only view that shows what the provider actually
  /// did. Every other group shows something StoryTale derived, and on a failed
  /// package the character view falls back to the safe locked template, which
  /// looks identical no matter what came back.
  sheet('Sheet'),
  character('Character'),
  layers('Layers'),
  faces('Faces'),
  hair('Hair'),
  poses('Poses'),
  details('Details');

  const _CharacterSheetReviewGroup(this.label);

  final String label;
}

enum _SpritePreview {
  source('Gemini source'),
  head('Head'),
  body('Body'),
  rejoined('Rejoined');

  const _SpritePreview(this.label);

  final String label;
}
