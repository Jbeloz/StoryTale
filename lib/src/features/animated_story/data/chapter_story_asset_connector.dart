import '../../../shared/models/storytale_models.dart';
import 'story_asset_binary_store.dart';
import 'story_background_repository.dart';
import 'story_bible_models.dart';
import 'story_foreground_repository.dart';

class ChapterStoryAssetConnector {
  const ChapterStoryAssetConnector();

  ChapterStoryData connect({
    required ChapterData chapter,
    required ChapterStoryData story,
    required BookStoryBibleData bible,
    required List<StoryBackgroundAssetData> backgrounds,
    required List<StoryForegroundAssetData> foregrounds,
  }) {
    final readyBackgrounds = {
      for (final asset in backgrounds)
        if (asset.approved && asset.isVisualNovelSize && asset.hasBytes)
          asset.key: asset,
    };
    final readyForegrounds = [
      for (final asset in foregrounds)
        if (asset.status == StoryForegroundAssetStatus.approved &&
            asset.hasBytes &&
            (asset.chapterIds.isEmpty || asset.chapterIds.contains(chapter.id)))
          asset,
    ];
    final entities = {
      for (final entity in bible.entities)
        if (entity.approved) entity.entityId: entity,
    };
    final readyForegroundIds = {
      for (final asset in readyForegrounds) asset.assetId,
    };
    final supportedHumanIds = {
      for (final entity in entities.values)
        if (entity.kind == StoryEntityKind.human &&
            entity.assetIds.any(StoryAssetBinaryStore.contains))
          entity.entityId,
    };
    final supportedSpeakers = <String>{'Narrator'};
    for (final entity in entities.values) {
      final hasReadyForeground = readyForegrounds.any(
        (asset) => asset.entityId == entity.entityId,
      );
      if (entity.speaker &&
          (hasReadyForeground || supportedHumanIds.contains(entity.entityId))) {
        supportedSpeakers
          ..add(entity.entityId)
          ..add(entity.canonicalName)
          ..addAll(entity.aliases);
      }
    }

    final cutscenes = [
      for (final cutscene in story.cutscenes)
        StoryCutsceneData(
          id: cutscene.id,
          locationId: cutscene.locationId,
          timeOfDay: cutscene.timeOfDay,
          backgroundStateId: cutscene.backgroundStateId,
          shots: [
            for (final shot in cutscene.shots)
              _connectShot(
                shot: shot,
                cutscene: cutscene,
                entities: entities,
                readyBackgrounds: readyBackgrounds,
                readyForegrounds: readyForegrounds,
                readyForegroundIds: readyForegroundIds,
                supportedHumanIds: supportedHumanIds,
                supportedSpeakers: supportedSpeakers,
              ),
          ],
        ),
    ];
    return ChapterStoryData(
      chapterId: story.chapterId,
      moral: story.moral,
      cutscenes: cutscenes,
      status: story.status,
    );
  }

  StoryShotPlanData _connectShot({
    required StoryShotPlanData shot,
    required StoryCutsceneData cutscene,
    required Map<String, StoryEntityData> entities,
    required Map<String, StoryBackgroundAssetData> readyBackgrounds,
    required List<StoryForegroundAssetData> readyForegrounds,
    required Set<String> readyForegroundIds,
    required Set<String> supportedHumanIds,
    required Set<String> supportedSpeakers,
  }) {
    final background =
        readyBackgrounds['${cutscene.locationId}::'
            '${cutscene.backgroundStateId}'];
    final blockIds = {for (final beat in shot.beats) ...beat.sourceBlockIds};
    final sourceText = shot.beats
        .map((beat) => beat.originalText)
        .join(' ')
        .toLowerCase();
    final matches = <StoryForegroundAssetData>[];

    for (final layer in shot.focusAssetLayers) {
      final asset = readyForegrounds
          .where((candidate) => candidate.assetId == layer.assetId)
          .firstOrNull;
      final entity = asset == null ? null : entities[asset.entityId];
      if (asset != null &&
          entity != null &&
          _isSourceSupported(entity, blockIds, sourceText)) {
        matches.add(asset);
      }
    }
    for (final asset in readyForegrounds) {
      if (matches.any((item) => item.entityId == asset.entityId)) continue;
      final entity = entities[asset.entityId];
      if (entity == null || !_isSourceSupported(entity, blockIds, sourceText)) {
        continue;
      }
      final variants = readyForegrounds
          .where((item) => item.entityId == asset.entityId)
          .toList(growable: false);
      final chosen = _preferredVariant(
        variants,
        entity: entity,
        shot: shot,
        sourceText: sourceText,
      );
      if (chosen != null) matches.add(chosen);
    }
    final selected = matches
        .where((asset) => readyForegroundIds.contains(asset.assetId))
        .take(2)
        .toList(growable: false);

    return StoryShotPlanData(
      id: shot.id,
      layoutId: shot.layoutId,
      backgroundId: background?.assetId ?? shot.backgroundId,
      transitionId: shot.transitionId,
      camera: shot.camera,
      backgroundPath: shot.backgroundPath,
      beats: [
        for (final beat in shot.beats)
          StoryBeatData(
            id: beat.id,
            speakerId: supportedSpeakers.contains(beat.speakerId)
                ? beat.speakerId
                : 'Narrator',
            originalText: beat.originalText,
            sourceBlockIds: beat.sourceBlockIds,
            filipinoText: beat.filipinoText,
            audioAssetId: beat.audioAssetId,
            actionId: beat.actionId,
          ),
      ],
      characterLayers: [
        for (final layer in shot.characterLayers)
          if (supportedHumanIds.contains(layer.characterId)) layer,
      ],
      focusAssetLayers: List.generate(selected.length, (index) {
        final asset = selected[index];
        final previous = shot.focusAssetLayers
            .where((layer) => layer.assetId == asset.assetId)
            .firstOrNull;
        return StoryFocusAssetLayerData(
          entityId: asset.entityId,
          assetId: asset.assetId,
          variantId: asset.variantId,
          stagePosition:
              previous?.stagePosition ??
              (selected.length == 1
                  ? 'center'
                  : index == 0
                  ? 'left'
                  : 'right'),
          scale:
              previous?.scale ??
              (shot.layoutId == 'object_detail' ? 'close' : 'medium'),
          depth: previous?.depth ?? 'normal',
          movement:
              previous?.movement ?? _movementFor(entities[asset.entityId]),
        );
      }),
    );
  }

  String _movementFor(StoryEntityData? entity) {
    if (entity == null) return 'idle';
    return switch (entity.kind) {
      StoryEntityKind.animal || StoryEntityKind.creature => 'gentle_bob',
      _ => 'idle',
    };
  }

  StoryForegroundAssetData? _preferredVariant(
    List<StoryForegroundAssetData> assets, {
    required StoryEntityData entity,
    required StoryShotPlanData shot,
    required String sourceText,
  }) {
    final speaking = shot.beats.any(
      (beat) =>
          beat.speakerId == entity.entityId ||
          beat.speakerId == entity.canonicalName ||
          entity.aliases.contains(beat.speakerId),
    );
    if (speaking) {
      final talking = _variant(assets, 'talking');
      if (talking != null) return talking;
    }
    for (final asset in assets) {
      if (asset.variantId != 'normal' &&
          asset.variantId != 'neutral' &&
          sourceText.contains(asset.variantId.replaceAll('_', ' '))) {
        return asset;
      }
    }
    return _variant(assets, 'normal') ??
        _variant(assets, 'neutral') ??
        assets.firstOrNull;
  }

  StoryForegroundAssetData? _variant(
    List<StoryForegroundAssetData> assets,
    String variantId,
  ) {
    for (final asset in assets) {
      if (asset.variantId == variantId) return asset;
    }
    return null;
  }

  bool _isSourceSupported(
    StoryEntityData entity,
    Set<String> blockIds,
    String sourceText,
  ) {
    if (entity.sourceBlockIds.any(blockIds.contains)) return true;
    for (final name in [entity.canonicalName, ...entity.aliases]) {
      final normalized = name.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (RegExp(
        '(^|[^a-z0-9])${RegExp.escape(normalized)}([^a-z0-9]|\$)',
      ).hasMatch(sourceText)) {
        return true;
      }
    }
    return false;
  }
}
