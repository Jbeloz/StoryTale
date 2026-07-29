import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../../../core/state/storytale_scope.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/story_artwork_service.dart';
import '../data/story_asset_binary_store.dart';
import '../data/story_asset_validator.dart';
import '../data/story_bible_repository.dart';
import '../data/story_foreground_repository.dart';

class StoryForegroundInventoryPage extends StatefulWidget {
  const StoryForegroundInventoryPage({
    super.key,
    this.artworkService,
    this.foregroundRepository,
    this.storyBibleRepository,
  });

  final StoryArtworkService? artworkService;
  final StoryForegroundRepository? foregroundRepository;
  final StoryBibleRepository? storyBibleRepository;

  @override
  State<StoryForegroundInventoryPage> createState() =>
      _StoryForegroundInventoryPageState();
}

class _StoryForegroundInventoryPageState
    extends State<StoryForegroundInventoryPage> {
  late final StoryForegroundRepository _foregroundRepository;
  late final StoryBibleRepository _storyBibleRepository;
  late final StoryArtworkService _artworkService;
  final _validator = const StoryAssetValidator();
  final Map<String, StoryForegroundReplacementData> _replacements = {};
  List<StoryForegroundAssetData> _assets = const [];
  String? _bookId;
  String? _workingAssetId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _artworkService = widget.artworkService ?? StoryArtworkService();
    _foregroundRepository =
        widget.foregroundRepository ?? StoryForegroundRepository();
    _storyBibleRepository =
        widget.storyBibleRepository ?? StoryBibleRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bookId = StoryTaleScope.of(context).currentBook?.id;
    if (bookId == null || bookId == _bookId) return;
    _bookId = bookId;
    _load(bookId);
  }

  @override
  void dispose() {
    for (final replacement in _replacements.values) {
      _foregroundRepository.discardReplacement(replacement);
    }
    super.dispose();
  }

  Future<void> _load(String bookId) async {
    setState(() => _loading = true);
    final bible = await _storyBibleRepository.load(bookId);
    final assets = await _foregroundRepository.sync(bible);
    if (!mounted || _bookId != bookId) return;
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = StoryTaleScope.of(context).currentBook;
    if (book == null) {
      return const StoryTaleInfoPage(
        title: 'Foreground Assets',
        description: 'Choose a book before viewing its shared assets.',
      );
    }
    return StoryTaleAppShell(
      title: 'Foreground Assets',
      actions: [
        IconButton(
          tooltip: 'Reload',
          onPressed: _loading || _bookId == null ? null : () => _load(_bookId!),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _content(book.title),
    );
  }

  Widget _content(String bookTitle) {
    if (_assets.isEmpty) {
      return StoryTaleEmptyState(
        title: 'No foreground assets required',
        message:
            'Only approved animals, creatures, plants, and props that speak, '
            'recur, change state, or matter visually are listed here.',
        actionLabel: 'Go back',
        onAction: () => Navigator.of(context).pop(),
        icon: Icons.pets_outlined,
      );
    }
    final entityCount = _assets.map((asset) => asset.entityId).toSet().length;
    final approved = _assets
        .where((asset) => asset.status == StoryForegroundAssetStatus.approved)
        .length;
    final needsReview = _assets
        .where(
          (asset) => asset.status == StoryForegroundAssetStatus.needsReview,
        )
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bookTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Volume preparation accepts valid assets automatically. Review is '
          'optional unless an item failed or needs attention.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('$entityCount subjects')),
            Chip(label: Text('${_assets.length} variants')),
            Chip(label: Text('$approved ready')),
            if (needsReview > 0) Chip(label: Text('$needsReview need review')),
          ],
        ),
        const SizedBox(height: 8),
        for (final entityId in _entityIds)
          _entityCard(
            _assets.where((asset) => asset.entityId == entityId).toList(),
          ),
      ],
    );
  }

  List<String> get _entityIds {
    final seen = <String>{};
    return [
      for (final asset in _assets)
        if (seen.add(asset.entityId)) asset.entityId,
    ];
  }

  Widget _entityCard(List<StoryForegroundAssetData> assets) {
    final entity = assets.first;
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(child: Icon(_icon(entity))),
        title: Text(entity.entityName),
        subtitle: Text(
          '${_label(entity)} • ${entity.reasons.join(', ')} • '
          '${entity.chapterIds.length} chapter'
          '${entity.chapterIds.length == 1 ? '' : 's'}',
        ),
        children: [for (final asset in assets) _assetTile(asset)],
      ),
    );
  }

  Widget _assetTile(StoryForegroundAssetData asset) {
    final replacement = _replacements[asset.assetId];
    final ready =
        asset.status == StoryForegroundAssetStatus.approved && asset.hasBytes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(asset.variantId),
            subtitle: Text('${asset.assetId}\n${_status(asset.status)}'),
            trailing: Icon(
              ready ? Icons.verified_outlined : Icons.error_outline,
            ),
          ),
          if (ready)
            _assetPreview('Current asset', asset.bytes)
          else
            const Text(
              'A safe placeholder remains active until this is ready.',
            ),
          if (replacement != null)
            _assetPreview('Replacement preview', replacement.bytes),
          const SizedBox(height: 10),
          _assetActions(asset, replacement, ready),
        ],
      ),
    );
  }

  Widget _assetPreview(String label, Uint8List bytes) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Container(
            key: Key('foreground-preview-$label'),
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetActions(
    StoryForegroundAssetData asset,
    StoryForegroundReplacementData? replacement,
    bool ready,
  ) {
    if (_workingAssetId == asset.assetId) {
      return const LinearProgressIndicator();
    }
    if (replacement != null) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            key: Key('replace-foreground-${asset.assetId}'),
            onPressed: () => _applyReplacement(asset, replacement),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Replace'),
          ),
          TextButton.icon(
            key: Key('reuse-foreground-${asset.assetId}'),
            onPressed: () => _reuseExisting(asset, replacement),
            icon: const Icon(Icons.undo),
            label: const Text('Reuse current'),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          key: Key(
            '${ready ? 'regenerate' : 'retry'}-foreground-${asset.assetId}',
          ),
          onPressed: _workingAssetId == null ? () => _generate(asset) : null,
          icon: Icon(ready ? Icons.refresh : Icons.replay),
          label: Text(ready ? 'Regenerate' : 'Retry'),
        ),
        OutlinedButton.icon(
          key: Key('choose-foreground-${asset.assetId}'),
          onPressed: _workingAssetId == null
              ? () => _chooseReplacement(asset)
              : null,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Replace PNG'),
        ),
      ],
    );
  }

  Future<void> _generate(StoryForegroundAssetData asset) async {
    setState(() => _workingAssetId = asset.assetId);
    try {
      final generated = await _artworkService.generateForeground(asset);
      final replacement = _createReplacement(
        asset,
        bytes: generated.bytes,
        mimeType: generated.mimeType,
        width: generated.width,
        height: generated.height,
        prompt: generated.prompt,
      );
      await _acceptOrReview(asset, replacement);
    } on ArtworkGenerationException catch (error) {
      await _handleFailure(asset, error.message);
    } catch (_) {
      await _handleFailure(
        asset,
        'The foreground image could not be generated.',
      );
    } finally {
      if (mounted) setState(() => _workingAssetId = null);
    }
  }

  Future<void> _chooseReplacement(StoryForegroundAssetData asset) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final bytes = result.files.single.bytes;
    final decoded = bytes == null ? null : image.decodePng(bytes);
    if (bytes == null || decoded == null) {
      _message('Choose a valid PNG file.');
      return;
    }
    setState(() => _workingAssetId = asset.assetId);
    try {
      final replacement = _createReplacement(
        asset,
        bytes: bytes,
        mimeType: 'image/png',
        width: decoded.width,
        height: decoded.height,
        prompt: 'User-selected replacement PNG.',
      );
      await _acceptOrReview(asset, replacement);
    } finally {
      if (mounted) setState(() => _workingAssetId = null);
    }
  }

  StoryForegroundReplacementData _createReplacement(
    StoryForegroundAssetData asset, {
    required Uint8List bytes,
    required String mimeType,
    required int width,
    required int height,
    required String prompt,
  }) {
    final createdAt = DateTime.now().toUtc();
    final candidateId = StoryForegroundAssetData.candidateId(
      asset.assetId,
      createdAt,
    );
    StoryAssetBinaryStore.write(candidateId, bytes);
    return StoryForegroundReplacementData(
      candidateAssetId: candidateId,
      mimeType: mimeType,
      width: width,
      height: height,
      generationPrompt: prompt,
      generatedAt: createdAt.toIso8601String(),
    );
  }

  Future<void> _acceptOrReview(
    StoryForegroundAssetData asset,
    StoryForegroundReplacementData replacement,
  ) async {
    final prepared = asset.copyWith(
      status: StoryForegroundAssetStatus.approved,
      mimeType: replacement.mimeType,
      width: replacement.width,
      height: replacement.height,
      generationPrompt: replacement.generationPrompt,
      generatedAt: replacement.generatedAt,
      clearImage: true,
      clearValidationError: true,
    );
    final error = _validator.validateForeground(prepared, replacement.bytes);
    if (error != null) {
      _foregroundRepository.discardReplacement(replacement);
      await _handleFailure(asset, error);
      return;
    }
    final hasReadyAsset =
        asset.status == StoryForegroundAssetStatus.approved && asset.hasBytes;
    if (!hasReadyAsset) {
      _assets = await _foregroundRepository.applyReplacement(
        asset,
        replacement,
      );
      _message('${asset.entityName} ${asset.variantId} is ready.');
      return;
    }
    final old = _replacements[asset.assetId];
    if (old != null) _foregroundRepository.discardReplacement(old);
    if (mounted) {
      setState(() => _replacements[asset.assetId] = replacement);
      _message('Replacement ready. Choose Replace or Reuse current.');
    }
  }

  Future<void> _applyReplacement(
    StoryForegroundAssetData asset,
    StoryForegroundReplacementData replacement,
  ) async {
    setState(() => _workingAssetId = asset.assetId);
    try {
      _assets = await _foregroundRepository.applyReplacement(
        asset,
        replacement,
      );
      _replacements.remove(asset.assetId);
      _message('Replacement applied without changing the asset ID.');
    } finally {
      if (mounted) setState(() => _workingAssetId = null);
    }
  }

  void _reuseExisting(
    StoryForegroundAssetData asset,
    StoryForegroundReplacementData replacement,
  ) {
    _foregroundRepository.discardReplacement(replacement);
    setState(() => _replacements.remove(asset.assetId));
    _message('Current asset kept.');
  }

  Future<void> _handleFailure(
    StoryForegroundAssetData asset,
    String message,
  ) async {
    if (asset.status == StoryForegroundAssetStatus.approved && asset.hasBytes) {
      _message('$message Current asset kept.');
      return;
    }
    await _markNeedsReview(asset, message);
  }

  Future<void> _markNeedsReview(
    StoryForegroundAssetData asset,
    String message,
  ) async {
    _assets = await _foregroundRepository.save(
      asset.copyWith(
        status: StoryForegroundAssetStatus.needsReview,
        validationError: message,
      ),
    );
    _message(message);
  }

  IconData _icon(StoryForegroundAssetData asset) {
    return switch (asset.entityKind.name) {
      'animal' => Icons.pets_outlined,
      'creature' => Icons.catching_pokemon_outlined,
      'plant' => Icons.local_florist_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }

  String _label(StoryForegroundAssetData asset) {
    final name = asset.entityKind.name;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  String _status(StoryForegroundAssetStatus status) {
    return switch (status) {
      StoryForegroundAssetStatus.required => 'Required',
      StoryForegroundAssetStatus.generated => 'Generated',
      StoryForegroundAssetStatus.approved => 'Ready',
      StoryForegroundAssetStatus.needsReview => 'Needs review',
      StoryForegroundAssetStatus.rejected => 'Rejected',
    };
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
