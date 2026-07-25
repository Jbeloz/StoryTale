import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/story_artwork_service.dart';
import '../data/story_background_repository.dart';
import '../data/story_bible_models.dart';
import '../data/story_bible_repository.dart';

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

  BookStoryBibleData? _bible;
  List<StoryBackgroundAssetData> _assets = const [];
  List<StoryBackgroundRequirementData> _requirements = const [];
  String? _bookId;
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
    if (book == null || chapter == null || _bookId == book.id) return;
    _bookId = book.id;
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
      return _assetFor(requirement)?.approved == true;
    }).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bookTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Generate one reusable background for each location and meaningful '
          'place state required by this chapter. Generated images must be '
          'approved before Story Mode can use their asset IDs.',
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
    final asset = _assetFor(requirement);
    final working = _workingKey == requirement.key;
    final canGenerate =
        location?.approved == true &&
        location?.sceneLocation == true &&
        (location?.backgroundBrief?.trim().isNotEmpty ?? false);
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
              title: Text(location?.canonicalName ?? requirement.locationId),
              subtitle: Text('State: ${requirement.stateId}'),
              trailing: Icon(
                asset?.approved == true
                    ? Icons.verified
                    : asset == null
                    ? Icons.image_not_supported_outlined
                    : Icons.pending_outlined,
              ),
            ),
            if (location?.backgroundBrief?.trim().isNotEmpty ?? false)
              Text(location!.backgroundBrief!),
            if (asset != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(asset.bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                asset.assetId,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
                    onPressed: canGenerate
                        ? () => _generate(requirement, location!)
                        : null,
                    icon: Icon(
                      asset == null
                          ? Icons.auto_awesome_outlined
                          : Icons.refresh,
                    ),
                    label: Text(asset == null ? 'Generate' : 'Regenerate'),
                  ),
                  if (asset != null)
                    OutlinedButton.icon(
                      onPressed: () => _setApproval(asset, !asset.approved),
                      icon: Icon(
                        asset.approved
                            ? Icons.undo
                            : Icons.check_circle_outline,
                      ),
                      label: Text(asset.approved ? 'Mark pending' : 'Approve'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(
    StoryBackgroundRequirementData requirement,
    StoryEntityData location,
  ) async {
    setState(() => _workingKey = requirement.key);
    try {
      final prompt = _promptFor(location, requirement.stateId);
      final bytes = await _artworkService.generateBackground(prompt);
      final asset = StoryBackgroundAssetData(
        assetId: StoryBackgroundAssetData.stableId(
          bookId: _bookId!,
          locationId: requirement.locationId,
          stateId: requirement.stateId,
        ),
        bookId: _bookId!,
        locationId: requirement.locationId,
        stateId: requirement.stateId,
        prompt: prompt,
        imageBase64: base64Encode(bytes),
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      _assets = await _backgroundRepository.save(asset);
      await _syncLocationAsset(asset, approved: false);
      _message('Background generated. Review it before approval.');
    } on ArtworkGenerationException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('The location background could not be generated.');
    } finally {
      if (mounted) setState(() => _workingKey = null);
    }
  }

  Future<void> _setApproval(
    StoryBackgroundAssetData asset,
    bool approved,
  ) async {
    setState(() => _workingKey = asset.key);
    final updated = asset.copyWith(approved: approved);
    _assets = await _backgroundRepository.save(updated);
    await _syncLocationAsset(updated, approved: approved);
    if (mounted) {
      setState(() => _workingKey = null);
      _message(
        approved ? 'Background approved.' : 'Background marked pending.',
      );
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

  StoryEntityData? _locationFor(String locationId) {
    for (final entity in _bible?.entities ?? const <StoryEntityData>[]) {
      if (entity.entityId == locationId &&
          entity.kind == StoryEntityKind.location) {
        return entity;
      }
    }
    return null;
  }

  StoryBackgroundAssetData? _assetFor(
    StoryBackgroundRequirementData requirement,
  ) {
    for (final asset in _assets) {
      if (asset.key == requirement.key) return asset;
    }
    return null;
  }

  String _promptFor(StoryEntityData location, String stateId) {
    return [
      location.backgroundBrief!,
      'Location: ${location.canonicalName}.',
      if (location.parentSetting?.trim().isNotEmpty ?? false)
        'Wider setting: ${location.parentSetting}.',
      'Required visual state: $stateId.',
      'Keep the place recognizable when another state of it is generated.',
    ].join(' ');
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
