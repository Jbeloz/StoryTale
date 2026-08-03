import '../../../shared/models/storytale_models.dart';
import 'character_design_brief.dart';
import 'chapter_story_asset_connector.dart';
import 'story_analysis_contract.dart';
import 'story_analysis_service.dart';
import 'story_artwork_service.dart';
import 'story_asset_binary_store.dart';
import 'story_asset_validator.dart';
import 'story_background_repository.dart';
import 'story_bible_models.dart';
import 'story_bible_repository.dart';
import 'story_entity_service.dart';
import 'story_foreground_repository.dart';
import 'story_human_repository.dart';
import 'sprite_layer_processor.dart';
import 'visual_novel_background_brief.dart';
import 'volume_preparation_models.dart';

class VolumePreparationCoordinator {
  VolumePreparationCoordinator({
    required this.analysisProvider,
    required this.entityProvider,
    required this.storyBibleRepository,
    StoryArtworkService? artworkService,
    StoryBackgroundRepository? backgroundRepository,
    StoryForegroundRepository? foregroundRepository,
    StoryHumanRepository? humanRepository,
    StoryAssetValidator? assetValidator,
  }) : artworkService = artworkService ?? StoryArtworkService(),
       backgroundRepository =
           backgroundRepository ?? StoryBackgroundRepository(),
       foregroundRepository =
           foregroundRepository ?? StoryForegroundRepository(),
       humanRepository = humanRepository ?? StoryHumanRepository(),
       assetValidator = assetValidator ?? const StoryAssetValidator();

  final StoryAnalysisProvider analysisProvider;
  final StoryEntityProvider entityProvider;
  final StoryBibleRepository storyBibleRepository;
  final StoryArtworkService artworkService;
  final StoryBackgroundRepository backgroundRepository;
  final StoryForegroundRepository foregroundRepository;
  final StoryHumanRepository humanRepository;
  final StoryAssetValidator assetValidator;
  final _rateGate = _ArtworkRateGate();

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
      ..lastError = null
      ..currentAssetLabel = null
      ..assetTotal = 0
      ..assetReadyCount = 0
      ..assetNeedsReviewCount = 0
      ..backgroundReadyCount = 0
      ..foregroundApprovedCount = 0
      ..humanReadyCount = 0;
    job.addEvent('Preparing ${book.chapters.length} chapters');
    onChanged();

    var bible = entityProvider.isConfigured || analysisProvider.isConfigured
        ? await storyBibleRepository.load(book.id)
        : BookStoryBibleData.empty(book.id);
    for (final chapter in book.chapters) {
      final chapterJob = job.chapter(chapter.id);
      if (chapterJob.status == PreparationStatus.ready) continue;
      if (_pause(job, onChanged)) return;

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

    final backgroundItems = _backgroundItems(book, localStory);
    var foregroundAssets = await foregroundRepository.sync(bible);
    var humanAssets = await humanRepository.sync(bible);
    job
      ..stage = VolumePreparationStage.preparingAssets
      ..backgroundAssetCount = backgroundItems.length
      ..foregroundEntityCount = foregroundAssets
          .map((asset) => asset.entityId)
          .toSet()
          .length
      ..foregroundAssetCount = foregroundAssets.length
      ..humanEntityCount = humanAssets.length
      ..assetTotal =
          backgroundItems.length + foregroundAssets.length + humanAssets.length;
    job.addEvent('Preparing ${job.assetTotal} reusable assets');
    onChanged();

    bible = await _prepareBackgrounds(
      book: book,
      bible: bible,
      items: backgroundItems,
      job: job,
      onChanged: onChanged,
    );
    if (job.status == VolumePreparationStatus.paused) return;

    final foregroundResult = await _prepareForegrounds(
      bible: bible,
      assets: foregroundAssets,
      job: job,
      onChanged: onChanged,
    );
    bible = foregroundResult.bible;
    foregroundAssets = foregroundResult.assets;
    if (job.status == VolumePreparationStatus.paused) return;

    final humanResult = await _prepareHumans(
      bible: bible,
      assets: humanAssets,
      job: job,
      onChanged: onChanged,
    );
    bible = humanResult.bible;
    humanAssets = humanResult.assets;
    if (job.status == VolumePreparationStatus.paused) return;

    await storyBibleRepository.save(bible);
    job
      ..stage = VolumePreparationStage.connectingStoryAssets
      ..currentAssetLabel = 'Chapter 1 story';
    job.addEvent('Connecting prepared artwork to Chapter 1');
    onChanged();

    if (book.chapters.isNotEmpty) {
      final chapter = book.chapters.first;
      final backgrounds = await backgroundRepository.loadReady(
        book.id,
        chapterId: chapter.id,
      );
      final readyForegrounds = await foregroundRepository.loadReady(
        book.id,
        chapterId: chapter.id,
      );
      var sourceStory = localStory(chapter);
      if (analysisProvider.isConfigured && backgrounds.isNotEmpty) {
        try {
          sourceStory = await analysisProvider.analyze(
            chapter: chapter,
            catalog: StoryAnalysisCatalog.fromPreparedAssets(
              bible: bible,
              chapterId: chapter.id,
              backgrounds: backgrounds,
              foregrounds: readyForegrounds,
            ),
          );
        } catch (_) {
          job.addEvent('Chapter 1 kept its safe narration plan');
        }
      }
      final connected = const ChapterStoryAssetConnector().connect(
        chapter: chapter,
        story: sourceStory,
        bible: bible,
        backgrounds: backgrounds,
        foregrounds: readyForegrounds,
      )..status = PreparationStatus.ready;
      saveStory(chapter, connected);
      final connectedForegroundIds = {
        for (final shot in connected.shots)
          for (final layer in shot.focusAssetLayers) layer.assetId,
      };
      final connectedWithBytes = connectedForegroundIds
          .where(StoryAssetBinaryStore.contains)
          .length;
      job.addEvent(
        'Chapter 1 foreground trace: ${readyForegrounds.length} ready, '
        '${connectedForegroundIds.length} linked, '
        '$connectedWithBytes available to the player',
      );
      final missingForegrounds = readyForegrounds
          .where((asset) => !connectedForegroundIds.contains(asset.assetId))
          .map((asset) => asset.entityName)
          .toSet();
      if (missingForegrounds.isNotEmpty) {
        job.addEvent(
          'Not linked outside supported source: '
          '${missingForegrounds.join(', ')}',
        );
      }
      job.addEvent('Prepared artwork is connected to Chapter 1');
    }

    job
      ..foregroundApprovedCount = foregroundAssets
          .where((asset) => asset.status == StoryForegroundAssetStatus.approved)
          .length
      ..humanReadyCount = humanAssets
          .where(
            (asset) =>
                asset.status == StoryHumanAssetStatus.approved &&
                asset.hasReadyBytes,
          )
          .length
      ..currentAssetLabel = null
      ..stage = VolumePreparationStage.ready
      ..status = VolumePreparationStatus.ready
      ..finishedAt = DateTime.now();
    job.addEvent(
      '${job.assetReadyCount} assets ready, '
      '${job.assetNeedsReviewCount} need review',
    );
    job.addEvent('Animated volume preview is ready');
    onChanged();
  }

  Future<BookStoryBibleData> _prepareBackgrounds({
    required BookData book,
    required BookStoryBibleData bible,
    required List<_BackgroundItem> items,
    required VolumePreparationJobData job,
    required void Function() onChanged,
  }) async {
    final saved = {
      for (final asset in await backgroundRepository.load(book.id))
        asset.key: asset,
    };
    var updatedBible = bible;
    for (final item in items) {
      if (_pause(job, onChanged)) return updatedBible;
      final existing = saved[item.requirement.key];
      if (existing != null &&
          existing.approved &&
          existing.isVisualNovelSize &&
          existing.hasBytes) {
        job.assetReadyCount++;
        job.backgroundReadyCount++;
        continue;
      }

      job.currentAssetLabel = 'Background: ${item.requirement.locationId}';
      onChanged();
      final location = _locationFor(updatedBible, item.requirement.locationId);
      if (location == null) {
        await _saveBackgroundFailure(
          book: book,
          item: item,
          message: 'The location needs a specific approved background brief.',
        );
        _failedAsset(
          job,
          'Background needs a better location brief',
          onChanged,
        );
        continue;
      }
      if (!artworkService.isConfigured) {
        await _saveBackgroundFailure(
          book: book,
          item: item,
          message: 'The image service token is not configured.',
        );
        _failedAsset(job, 'Background is waiting for image setup', onChanged);
        continue;
      }

      try {
        await _rateGate.waitForSlot();
        final brief = VisualNovelBackgroundBrief.fromApprovedLocation(
          locationId: item.requirement.locationId,
          stateId: item.requirement.stateId,
          place: location.name,
          sourceBrief: location.backgroundBrief,
          parentSetting: location.parentSetting,
        );
        final generated = await artworkService.generateBackground(brief);
        final error = assetValidator.validateBackground(
          bytes: generated.bytes,
          mimeType: generated.mimeType,
          width: generated.width,
          height: generated.height,
          chapterIds: item.chapterIds,
        );
        if (error != null) throw StateError(error);

        final assetId = StoryBackgroundAssetData.stableId(
          bookId: book.id,
          locationId: item.requirement.locationId,
          stateId: item.requirement.stateId,
        );
        StoryAssetBinaryStore.write(assetId, generated.bytes);
        final asset = StoryBackgroundAssetData(
          assetId: assetId,
          bookId: book.id,
          locationId: item.requirement.locationId,
          stateId: item.requirement.stateId,
          prompt: generated.prompt,
          createdAt: DateTime.now().toUtc().toIso8601String(),
          approved: true,
          mimeType: generated.mimeType,
          width: generated.width,
          height: generated.height,
          brief: brief.toJson(),
          chapterIds: item.chapterIds,
        );
        await backgroundRepository.save(asset);
        updatedBible = _registerAsset(
          updatedBible,
          item.requirement.locationId,
          assetId,
        );
        job.assetReadyCount++;
        job.backgroundReadyCount++;
        job.addEvent('${location.name} background is ready');
      } catch (error) {
        await _saveBackgroundFailure(book: book, item: item, message: '$error');
        _failedAsset(job, 'Background needs review', onChanged);
        continue;
      }
      onChanged();
    }
    return updatedBible;
  }

  Future<_ForegroundResult> _prepareForegrounds({
    required BookStoryBibleData bible,
    required List<StoryForegroundAssetData> assets,
    required VolumePreparationJobData job,
    required void Function() onChanged,
  }) async {
    var updatedBible = bible;
    var updatedAssets = [...assets];
    for (final asset in assets) {
      if (_pause(job, onChanged)) {
        return _ForegroundResult(updatedBible, updatedAssets);
      }
      if (asset.status == StoryForegroundAssetStatus.approved &&
          asset.hasBytes &&
          asset.chapterIds.isNotEmpty) {
        job.assetReadyCount++;
        continue;
      }

      job.currentAssetLabel = '${asset.entityName}: ${asset.variantId}';
      onChanged();
      if (!artworkService.isConfigured) {
        updatedAssets = await foregroundRepository.save(
          asset.copyWith(
            status: StoryForegroundAssetStatus.needsReview,
            validationError: 'The image service token is not configured.',
          ),
        );
        _failedAsset(
          job,
          '${asset.entityName} is waiting for image setup',
          onChanged,
        );
        continue;
      }

      try {
        await _rateGate.waitForSlot();
        final generated = await artworkService.generateForeground(asset);
        final generatedAsset = asset.copyWith(
          status: StoryForegroundAssetStatus.approved,
          mimeType: generated.mimeType,
          width: generated.width,
          height: generated.height,
          generationPrompt: generated.prompt,
          generatedAt: DateTime.now().toUtc().toIso8601String(),
          clearImage: true,
          clearValidationError: true,
        );
        final error = assetValidator.validateForeground(
          generatedAsset,
          generated.bytes,
        );
        if (error != null) throw StateError(error);

        StoryAssetBinaryStore.write(asset.assetId, generated.bytes);
        updatedAssets = await foregroundRepository.save(generatedAsset);
        updatedBible = _registerAsset(
          updatedBible,
          asset.entityId,
          asset.assetId,
        );
        job.assetReadyCount++;
        job.addEvent('${asset.entityName} ${asset.variantId} is ready');
      } catch (error) {
        updatedAssets = await foregroundRepository.save(
          asset.copyWith(
            status: StoryForegroundAssetStatus.needsReview,
            validationError: '$error',
            clearImage: true,
          ),
        );
        _failedAsset(job, '${asset.entityName} needs review', onChanged);
        continue;
      }
      onChanged();
    }
    return _ForegroundResult(updatedBible, updatedAssets);
  }

  Future<_HumanResult> _prepareHumans({
    required BookStoryBibleData bible,
    required List<StoryHumanAssetData> assets,
    required VolumePreparationJobData job,
    required void Function() onChanged,
  }) async {
    var updatedBible = bible;
    var updatedAssets = [...assets];
    const processor = SpriteLayerProcessor();
    for (final asset in assets) {
      if (_pause(job, onChanged)) {
        return _HumanResult(updatedBible, updatedAssets);
      }
      if (asset.status == StoryHumanAssetStatus.approved &&
          asset.hasReadyBytes) {
        job.assetReadyCount++;
        job.humanReadyCount++;
        continue;
      }

      job.currentAssetLabel = 'Character: ${asset.name}';
      onChanged();
      if (!artworkService.isConfigured) {
        updatedAssets = await humanRepository.save(
          asset.copyWith(
            status: StoryHumanAssetStatus.needsReview,
            validationError: 'The image service token is not configured.',
          ),
        );
        _failedAsset(
          job,
          '${asset.name} is waiting for image setup',
          onChanged,
        );
        continue;
      }

      try {
        final prompt = _humanPrompt(asset);
        final generated = await artworkService.generateSpriteMaster(prompt);
        final layers = processor.processRig(generated);
        if (!layers.validation.isValid) {
          throw StateError(layers.validation.errors.join(' '));
        }

        StoryAssetBinaryStore.write(asset.masterAssetId, layers.source);
        StoryAssetBinaryStore.write(asset.rejoinedAssetId, layers.rejoined);
        for (final entry in layers.parts.entries) {
          StoryAssetBinaryStore.write(
            asset.partAssetIds[entry.key]!,
            entry.value,
          );
        }
        final readyAsset = asset.copyWith(
          status: StoryHumanAssetStatus.approved,
          width: layers.width,
          height: layers.height,
          generationPrompt: prompt,
          generatedAt: DateTime.now().toUtc().toIso8601String(),
          rigMetadata: StoryHumanRigMetadata.fromProcessedLayers(layers),
          packageVersion: 2,
          packageValidated: true,
          generationProvider: artworkService.spriteProvider,
          generationModel: artworkService.spriteModel,
          clearValidationError: true,
        );
        updatedAssets = await humanRepository.save(readyAsset);
        updatedBible = _registerHuman(updatedBible, readyAsset);
        job.assetReadyCount++;
        job.humanReadyCount++;
        job.addEvent('${asset.name} reusable character is ready');
      } catch (error) {
        updatedAssets = await humanRepository.save(
          asset.copyWith(
            status: StoryHumanAssetStatus.needsReview,
            validationError: '$error',
          ),
        );
        _failedAsset(job, '${asset.name} needs review', onChanged);
        continue;
      }
      onChanged();
    }
    return _HumanResult(updatedBible, updatedAssets);
  }

  String _humanPrompt(StoryHumanAssetData asset) {
    return CharacterDesignBrief(
      bookId: asset.bookId,
      characterId: asset.entityId,
      canonicalName: asset.name,
      actorProfileId: asset.actorProfileId,
      sourceDescription: asset.description,
    ).generationPrompt;
  }

  Future<void> _saveBackgroundFailure({
    required BookData book,
    required _BackgroundItem item,
    required String message,
  }) {
    return backgroundRepository
        .save(
          StoryBackgroundAssetData(
            assetId: StoryBackgroundAssetData.stableId(
              bookId: book.id,
              locationId: item.requirement.locationId,
              stateId: item.requirement.stateId,
            ),
            bookId: book.id,
            locationId: item.requirement.locationId,
            stateId: item.requirement.stateId,
            prompt: '',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            chapterIds: item.chapterIds,
            validationError: message,
          ),
        )
        .then((_) {});
  }

  void _failedAsset(
    VolumePreparationJobData job,
    String event,
    void Function() onChanged,
  ) {
    job.assetNeedsReviewCount++;
    job.addEvent(event);
    onChanged();
  }

  bool _pause(VolumePreparationJobData job, void Function() onChanged) {
    if (!job.pauseRequested) return false;
    job
      ..status = VolumePreparationStatus.paused
      ..currentChapterId = null
      ..currentAssetLabel = null;
    job.addEvent('Preparation paused');
    onChanged();
    return true;
  }

  List<_BackgroundItem> _backgroundItems(
    BookData book,
    ChapterStoryData Function(ChapterData chapter) storyFor,
  ) {
    final items = <String, _BackgroundItem>{};
    for (final chapter in book.chapters) {
      for (final requirement in storyFor(chapter).backgroundRequirements) {
        final existing = items[requirement.key];
        items[requirement.key] = _BackgroundItem(
          requirement,
          {...?existing?.chapterIds, chapter.id}.toList(growable: false),
        );
      }
    }
    return items.values.toList(growable: false);
  }

  _LocationBrief? _locationFor(BookStoryBibleData bible, String locationId) {
    for (final entity in bible.entities) {
      if (entity.entityId == locationId &&
          entity.kind == StoryEntityKind.location &&
          entity.approved &&
          entity.sceneLocation &&
          (entity.backgroundBrief?.trim().isNotEmpty ?? false)) {
        return _LocationBrief(
          entity.canonicalName,
          entity.backgroundBrief!,
          entity.parentSetting,
        );
      }
    }
    for (final location in StoryAnalysisCatalog.prototype.locations) {
      if (location.id == locationId) {
        return _LocationBrief(
          location.name,
          location.backgroundBrief,
          location.parentSetting,
        );
      }
    }
    return null;
  }

  BookStoryBibleData _registerAsset(
    BookStoryBibleData bible,
    String entityId,
    String assetId,
  ) {
    return BookStoryBibleData(
      bookId: bible.bookId,
      version: bible.version,
      entities: [
        for (final entity in bible.entities)
          if (entity.entityId == entityId)
            entity.copyWith(assetIds: {...entity.assetIds, assetId}.toList())
          else
            entity,
      ],
    );
  }

  BookStoryBibleData _registerHuman(
    BookStoryBibleData bible,
    StoryHumanAssetData asset,
  ) {
    final assetIds = [
      asset.masterAssetId,
      asset.rejoinedAssetId,
      ...asset.partAssetIds.values,
    ];
    return BookStoryBibleData(
      bookId: bible.bookId,
      version: bible.version,
      entities: [
        for (final entity in bible.entities)
          if (entity.entityId == asset.entityId)
            entity.copyWith(
              actorProfileId: asset.actorProfileId,
              rigId: asset.rigId,
              faceProfileId: asset.faceProfileId,
              voiceId: asset.voiceId,
              lockedAppearance: true,
              assetIds: {...entity.assetIds, ...assetIds}.toList(),
            )
          else
            entity,
      ],
    );
  }

  int _requirementCount(
    BookData book,
    ChapterStoryData Function(ChapterData chapter) storyFor,
  ) {
    return _backgroundItems(book, storyFor).length;
  }
}

class _BackgroundItem {
  const _BackgroundItem(this.requirement, this.chapterIds);

  final StoryBackgroundRequirementData requirement;
  final List<String> chapterIds;
}

class _LocationBrief {
  const _LocationBrief(this.name, this.backgroundBrief, this.parentSetting);

  final String name;
  final String backgroundBrief;
  final String? parentSetting;
}

class _ForegroundResult {
  const _ForegroundResult(this.bible, this.assets);

  final BookStoryBibleData bible;
  final List<StoryForegroundAssetData> assets;
}

class _HumanResult {
  const _HumanResult(this.bible, this.assets);

  final BookStoryBibleData bible;
  final List<StoryHumanAssetData> assets;
}

class _ArtworkRateGate {
  final List<DateTime> _requests = [];

  Future<void> waitForSlot() async {
    final now = DateTime.now();
    _requests.removeWhere(
      (request) => now.difference(request) >= const Duration(seconds: 60),
    );
    if (_requests.length >= 3) {
      final wait =
          const Duration(seconds: 61) - now.difference(_requests.first);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _requests.removeAt(0);
    }
    _requests.add(DateTime.now());
  }
}
