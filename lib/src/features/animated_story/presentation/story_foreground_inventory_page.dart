import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/story_bible_repository.dart';
import '../data/story_foreground_repository.dart';

class StoryForegroundInventoryPage extends StatefulWidget {
  const StoryForegroundInventoryPage({
    super.key,
    this.foregroundRepository,
    this.storyBibleRepository,
  });

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
  List<StoryForegroundAssetData> _assets = const [];
  String? _bookId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bookTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'One shared asset record is reused everywhere the same story '
          'subject appears. Image generation is added in the next phase.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('$entityCount subjects')),
            Chip(label: Text('${_assets.length} variants')),
            Chip(label: Text('$approved approved')),
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
        children: [
          for (final asset in assets)
            ListTile(
              dense: true,
              title: Text(asset.variantId),
              subtitle: Text(asset.assetId),
              trailing: Text(_status(asset.status)),
            ),
        ],
      ),
    );
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
      StoryForegroundAssetStatus.generated => 'Review',
      StoryForegroundAssetStatus.approved => 'Approved',
      StoryForegroundAssetStatus.rejected => 'Rejected',
    };
  }
}
