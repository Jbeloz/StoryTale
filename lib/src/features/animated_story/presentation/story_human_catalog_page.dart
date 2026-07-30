import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/story_bible_repository.dart';
import '../data/story_human_repository.dart';

class StoryHumanCatalogPage extends StatefulWidget {
  const StoryHumanCatalogPage({
    super.key,
    this.humanRepository,
    this.storyBibleRepository,
  });

  final StoryHumanRepository? humanRepository;
  final StoryBibleRepository? storyBibleRepository;

  @override
  State<StoryHumanCatalogPage> createState() => _StoryHumanCatalogPageState();
}

class _StoryHumanCatalogPageState extends State<StoryHumanCatalogPage> {
  late final StoryHumanRepository _humanRepository;
  late final StoryBibleRepository _storyBibleRepository;
  List<StoryHumanAssetData> _assets = const [];
  String? _bookId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _humanRepository = widget.humanRepository ?? StoryHumanRepository();
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
    final assets = await _humanRepository.sync(bible);
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
        title: 'Book Characters',
        description: 'Choose a book before viewing its reusable characters.',
      );
    }
    return StoryTaleAppShell(
      title: 'Book Characters',
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
        title: 'No approved human characters',
        message:
            'Approved people found during volume analysis will appear here.',
        actionLabel: 'Go back',
        onAction: () => Navigator.of(context).pop(),
        icon: Icons.people_outline,
      );
    }
    final ready = _assets.where((asset) => asset.hasReadyBytes).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bookTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Each approved person has one locked reusable identity for every '
          'chapter. This catalog is read-only.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('${_assets.length} characters')),
            Chip(label: Text('$ready ready')),
          ],
        ),
        const SizedBox(height: 8),
        for (final asset in _assets) _characterCard(asset),
      ],
    );
  }

  Widget _characterCard(StoryHumanAssetData asset) {
    final ready =
        asset.status == StoryHumanAssetStatus.approved && asset.hasReadyBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(ready ? Icons.check : Icons.person_outline),
              ),
              title: Text(asset.name),
              subtitle: Text(
                '${asset.actorProfileId} profile • '
                '${asset.chapterIds.length} chapter'
                '${asset.chapterIds.length == 1 ? '' : 's'}',
              ),
              trailing: Text(ready ? 'Ready' : 'Needs review'),
            ),
            if (ready)
              Container(
                height: 260,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.memory(asset.masterBytes, fit: BoxFit.contain),
              ),
            const SizedBox(height: 8),
            Text(asset.description),
            if (asset.validationError != null) ...[
              const SizedBox(height: 6),
              Text(
                asset.validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
