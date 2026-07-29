import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/story_artwork_service.dart';
import '../data/story_asset_binary_store.dart';
import '../data/story_asset_validator.dart';
import '../data/story_background_repository.dart';
import '../data/story_analysis_contract.dart';
import '../data/story_bible_models.dart';
import '../data/story_bible_repository.dart';
import '../data/visual_novel_background_brief.dart';

class StoryBackgroundCatalogPage extends StatefulWidget {
  const StoryBackgroundCatalogPage({
    super.key,
    this.artworkService,
    this.backgroundRepository,
    this.storyBibleRepository,
  });

  final StoryArtworkService? artworkService;
  final StoryBackgroundRepository? backgroundRepository;
  final StoryBibleRepository? storyBibleRepository;

  @override
  State<StoryBackgroundCatalogPage> createState() =>
      _StoryBackgroundCatalogPageState();
}

class _StoryBackgroundCatalogPageState
    extends State<StoryBackgroundCatalogPage> {
  late final StoryArtworkService _artworkService;
  late final StoryBackgroundRepository _backgroundRepository;
  late final StoryBibleRepository _storyBibleRepository;
  final _validator = const StoryAssetValidator();

  BookStoryBibleData? _bible;
  List<StoryBackgroundAssetData> _assets = const [];
  List<StoryBackgroundRequirementData> _requirements = const [];
  String? _bookId;
  String? _chapterId;
  String? _workingKey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _artworkService = widget.artworkService ?? StoryArtworkService();
    _backgroundRepository =
        widget.backgroundRepository ?? StoryBackgroundRepository();
    _storyBibleRepository =
        widget.storyBibleRepository ?? StoryBibleRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    final chapter = controller.currentChapter;
    if (book == null || chapter == null) return;
    if (_bookId == book.id && _chapterId == chapter.id) return;
    _bookId = book.id;
    _chapterId = chapter.id;
    _load(book.id, controller.storyFor(chapter).backgroundRequirements);
  }

  Future<void> _load(
    String bookId,
    List<StoryBackgroundRequirementData> requirements,
  ) async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _storyBibleRepository.load(bookId),
      _backgroundRepository.load(bookId),
    ]);
    if (!mounted || _bookId != bookId) return;
    setState(() {
      _bible = results[0] as BookStoryBibleData;
      _assets = results[1] as List<StoryBackgroundAssetData>;
      _requirements = requirements;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = StoryTaleScope.of(context).currentBook;
    if (book == null) {
      return const StoryTaleInfoPage(
        title: 'Location Backgrounds',
        description: 'Choose a book before preparing its backgrounds.',
      );
    }
    return StoryTaleAppShell(
      title: 'Location Backgrounds',
      actions: [
        IconButton(
          tooltip: 'Reload',
          onPressed: _loading || _bookId == null
              ? null
              : () => _load(_bookId!, _requirements),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(book.title),
    );
  }

  Widget _buildContent(String bookTitle) {
    if (_requirements.isEmpty) {
      return StoryTaleEmptyState(
        title: 'No required backgrounds yet',
        message:
            'Prepare the chapter first. Its approved locations will appear '
            'here in story order.',
        actionLabel: 'Go back',
        onAction: () => Navigator.of(context).pop(),
        icon: Icons.landscape_outlined,
      );
    }
    final approved = _requirements.where((requirement) {
      return _approvedAssetFor(requirement) != null;
    }).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bookTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Volume preparation creates and validates each required background '
          'automatically. This page is for review and optional replacements.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${_requirements.length} required')),
                Chip(label: Text('$approved approved')),
                Chip(
                  label: Text('${_requirements.length - approved} remaining'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final requirement in _requirements) _backgroundCard(requirement),
      ],
    );
  }

  Widget _backgroundCard(StoryBackgroundRequirementData requirement) {
    final location = _locationFor(requirement.locationId);
    final approvedAsset = _approvedAssetFor(requirement);
    final candidate = _pendingAssetFor(requirement);
    final working = _workingKey == requirement.key;
    final canGenerate = location != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.landscape_outlined),
              ),
              title: Text(location?.name ?? requirement.locationId),
              subtitle: Text('State: ${requirement.stateId}'),
              trailing: Icon(
                approvedAsset != null
                    ? Icons.verified
                    : candidate == null
                    ? Icons.image_not_supported_outlined
                    : Icons.pending_outlined,
              ),
            ),
            if (location != null) ...[
              Text(location.backgroundBrief),
              if (location.builtIn) ...[
                const SizedBox(height: 8),
                const Chip(label: Text('Built-in preview location')),
              ],
            ],
            if (approvedAsset != null)
              _assetPreview('Approved background', approvedAsset),
            if (candidate != null)
              _assetPreview('Replacement candidate', candidate),
            if (!canGenerate) ...[
              const SizedBox(height: 8),
              const Text(
                'This location needs an approved, specific background brief '
                'before an image can be generated.',
              ),
            ],
            const SizedBox(height: 12),
            if (working)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: Key('generate-background-${requirement.key}'),
                    onPressed: canGenerate
                        ? () => _generate(requirement, location)
                        : null,
                    icon: Icon(
                      candidate?.validationError != null
                          ? Icons.replay
                          : approvedAsset == null
                          ? Icons.auto_awesome_outlined
                          : Icons.refresh,
                    ),
                    label: Text(
                      candidate?.validationError != null
                          ? 'Retry'
                          : approvedAsset == null
                          ? 'Generate'
                          : 'Regenerate',
                    ),
                  ),
                  if (candidate != null) ...[
                    if (candidate.validationError == null)
                      OutlinedButton.icon(
                        key: Key('replace-background-${requirement.key}'),
                        onPressed: () => _replaceCandidate(candidate),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Replace'),
                      ),
                    TextButton.icon(
                      key: Key('reuse-background-${requirement.key}'),
                      onPressed: () => _reuseApproved(candidate),
                      icon: const Icon(Icons.undo),
                      label: Text(
                        approvedAsset == null ? 'Discard' : 'Reuse current',
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _assetPreview(String label, StoryBackgroundAssetData asset) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black12,
                child: asset.hasBytes
                    ? Image.memory(asset.bytes, fit: BoxFit.contain)
                    : const Center(child: Text('Safe placeholder in use')),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${asset.width}x${asset.height} • ${asset.mimeType}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SelectableText(
            asset.assetId,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _generate(
    StoryBackgroundRequirementData requirement,
    _BackgroundLocation location,
  ) async {
    setState(() => _workingKey = requirement.key);
    try {
      final previousCandidate = _pendingAssetFor(requirement);
      if (previousCandidate != null) {
        StoryAssetBinaryStore.remove(previousCandidate.assetId);
      }
      final hadApproved = _approvedAssetFor(requirement) != null;
      final brief = VisualNovelBackgroundBrief.fromApprovedLocation(
        locationId: requirement.locationId,
        stateId: requirement.stateId,
        place: location.name,
        sourceBrief: location.backgroundBrief,
        parentSetting: location.parentSetting,
      );
      final generated = await _artworkService.generateBackground(brief);
      final createdAt = DateTime.now().toUtc();
      final candidateId = StoryBackgroundAssetData.candidateId(
        bookId: _bookId!,
        locationId: requirement.locationId,
        stateId: requirement.stateId,
        createdAt: createdAt,
      );
      StoryAssetBinaryStore.write(candidateId, generated.bytes);
      final asset = StoryBackgroundAssetData(
        assetId: candidateId,
        bookId: _bookId!,
        locationId: requirement.locationId,
        stateId: requirement.stateId,
        prompt: generated.prompt,
        createdAt: createdAt.toIso8601String(),
        mimeType: generated.mimeType,
        width: generated.width,
        height: generated.height,
        brief: brief.toJson(),
        chapterIds: [if (_chapterId != null) _chapterId!],
      );
      final validationError = _validator.validateBackground(
        bytes: generated.bytes,
        mimeType: generated.mimeType,
        width: generated.width,
        height: generated.height,
        chapterIds: asset.chapterIds,
      );
      if (validationError != null) {
        _assets = await _backgroundRepository.saveCandidate(
          asset.copyWith(validationError: validationError),
        );
        _message(validationError);
        return;
      }
      _assets = await _backgroundRepository.saveCandidate(asset);
      if (hadApproved) {
        _message('Replacement ready. Choose Replace or Reuse current.');
        return;
      }
      _assets = await _backgroundRepository.approveCandidate(asset);
      final approved = _assets.firstWhere(
        (item) => item.key == asset.key && item.approved,
      );
      await _syncLocationAsset(approved, approved: true);
      _message('Background is ready.');
    } on ArtworkGenerationException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('The location background could not be generated.');
    } finally {
      if (mounted) setState(() => _workingKey = null);
    }
  }

  Future<void> _replaceCandidate(StoryBackgroundAssetData candidate) async {
    setState(() => _workingKey = candidate.key);
    _assets = await _backgroundRepository.approveCandidate(candidate);
    final approved = _assets.firstWhere(
      (asset) => asset.key == candidate.key && asset.approved,
    );
    await _syncLocationAsset(approved, approved: true);
    if (mounted) {
      setState(() => _workingKey = null);
      _message('Replacement applied without changing the asset ID.');
    }
  }

  Future<void> _reuseApproved(StoryBackgroundAssetData candidate) async {
    setState(() => _workingKey = candidate.key);
    _assets = await _backgroundRepository.rejectCandidate(candidate);
    if (mounted) {
      setState(() => _workingKey = null);
      _message('Current background kept.');
    }
  }

  Future<void> _syncLocationAsset(
    StoryBackgroundAssetData asset, {
    required bool approved,
  }) async {
    final bible = _bible;
    if (bible == null) return;
    final entities = [
      for (final entity in bible.entities)
        if (entity.entityId == asset.locationId)
          entity.copyWith(
            assetIds: approved
                ? {...entity.assetIds, asset.assetId}.toList()
                : entity.assetIds
                      .where((assetId) => assetId != asset.assetId)
                      .toList(),
          )
        else
          entity,
    ];
    final updated = BookStoryBibleData(
      bookId: bible.bookId,
      version: bible.version,
      entities: entities,
    );
    await _storyBibleRepository.save(updated);
    _bible = updated;
  }

  _BackgroundLocation? _locationFor(String locationId) {
    for (final entity in _bible?.entities ?? const <StoryEntityData>[]) {
      if (entity.entityId == locationId &&
          entity.kind == StoryEntityKind.location) {
        if (!entity.approved ||
            !entity.sceneLocation ||
            !(entity.backgroundBrief?.trim().isNotEmpty ?? false)) {
          return null;
        }
        return _BackgroundLocation(
          name: entity.canonicalName,
          backgroundBrief: entity.backgroundBrief!,
          parentSetting: entity.parentSetting,
        );
      }
    }
    for (final location in StoryAnalysisCatalog.prototype.locations) {
      if (location.id == locationId) {
        return _BackgroundLocation(
          name: location.name,
          backgroundBrief: location.backgroundBrief,
          parentSetting: location.parentSetting,
          builtIn: true,
        );
      }
    }
    return null;
  }

  StoryBackgroundAssetData? _approvedAssetFor(
    StoryBackgroundRequirementData requirement,
  ) {
    for (final asset in _assets) {
      if (asset.key == requirement.key &&
          asset.approved &&
          asset.isVisualNovelSize &&
          asset.hasBytes) {
        return asset;
      }
    }
    return null;
  }

  StoryBackgroundAssetData? _pendingAssetFor(
    StoryBackgroundRequirementData requirement,
  ) {
    for (final asset in _assets.reversed) {
      if (asset.key == requirement.key && !asset.approved) return asset;
    }
    return null;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _BackgroundLocation {
  const _BackgroundLocation({
    required this.name,
    required this.backgroundBrief,
    this.parentSetting,
    this.builtIn = false,
  });

  final String name;
  final String backgroundBrief;
  final String? parentSetting;
  final bool builtIn;
}
