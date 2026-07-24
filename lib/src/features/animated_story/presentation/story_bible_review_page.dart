import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/story_bible_models.dart';
import '../data/story_bible_repository.dart';

class StoryBibleReviewPage extends StatefulWidget {
  const StoryBibleReviewPage({super.key, this.repository});

  final StoryBibleRepository? repository;

  @override
  State<StoryBibleReviewPage> createState() => _StoryBibleReviewPageState();
}

class _StoryBibleReviewPageState extends State<StoryBibleReviewPage> {
  late final StoryBibleRepository _repository;
  BookStoryBibleData? _bible;
  String? _bookId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StoryBibleRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bookId = StoryTaleScope.of(context).currentBook?.id;
    if (_bookId == bookId) return;
    _bookId = bookId;
    if (bookId != null) _load(bookId);
  }

  Future<void> _load(String bookId) async {
    setState(() => _loading = true);
    final bible = await _repository.load(bookId);
    if (!mounted || _bookId != bookId) return;
    setState(() {
      _bible = bible;
      _loading = false;
    });
  }

  Future<void> _save(List<StoryEntityData> entities) async {
    final bible = _bible;
    if (bible == null) return;
    final updated = BookStoryBibleData(
      bookId: bible.bookId,
      version: bible.version,
      entities: entities,
    );
    await _repository.save(updated);
    if (mounted) setState(() => _bible = updated);
  }

  Future<void> _replace(StoryEntityData updated) {
    return _save([
      for (final entity in _bible?.entities ?? const <StoryEntityData>[])
        if (entity.entityId == updated.entityId) updated else entity,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final book = StoryTaleScope.of(context).currentBook;
    if (book == null) {
      return const StoryTaleInfoPage(
        title: 'Story Bible',
        description: 'Choose a book before reviewing its story subjects.',
      );
    }
    return StoryTaleAppShell(
      title: 'Story Bible',
      actions: [
        IconButton(
          tooltip: 'Reload',
          onPressed: _loading ? null : () => _load(book.id),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(book.title),
    );
  }

  Widget _buildContent(String bookTitle) {
    final entities = _bible?.entities ?? const <StoryEntityData>[];
    if (entities.isEmpty) {
      return StoryTaleEmptyState(
        title: 'No story subjects yet',
        message:
            'Prepare a chapter first. Gemini candidates will appear here '
            'for review before artwork is generated.',
        actionLabel: 'Go back',
        onAction: () => Navigator.of(context).pop(),
        icon: Icons.auto_stories_outlined,
      );
    }
    final approved = entities.where((entity) => entity.approved).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bookTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Approve only subjects that match the book. Pending subjects cannot '
          'assign images or appear in the final story catalog.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${entities.length} subjects')),
                Chip(label: Text('$approved approved')),
                Chip(label: Text('${entities.length - approved} pending')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final kind in StoryEntityKind.values) ...[
          if (entities.any((entity) => entity.kind == kind))
            StoryTaleSectionHeader(title: kind.groupLabel),
          for (final entity in entities.where((item) => item.kind == kind))
            _entityCard(entity),
        ],
      ],
    );
  }

  Widget _entityCard(StoryEntityData entity) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(child: Icon(entity.kind.icon)),
        title: Text(entity.canonicalName),
        subtitle: Text(
          '${entity.kind.label} • '
          '${entity.automaticallyApproved
              ? 'Approved automatically'
              : entity.approved
              ? 'Approved'
              : 'Pending review'}',
        ),
        trailing: Icon(
          entity.approved ? Icons.verified : Icons.pending_outlined,
          color: entity.approved ? theme.colorScheme.primary : null,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entity.description),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(label: Text(entity.importance.label)),
              if (entity.recurring) const Chip(label: Text('Recurring')),
              if (entity.speaker) const Chip(label: Text('Speaks')),
              if (entity.automaticallyApproved)
                const Chip(label: Text('Auto-approved')),
              Chip(
                label: Text('${(entity.confidence * 100).round()}% confidence'),
              ),
            ],
          ),
          if (entity.parentSetting?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text('Parent setting: ${entity.parentSetting}'),
          ],
          if (entity.backgroundBrief?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text('Background: ${entity.backgroundBrief}'),
          ],
          if (entity.aliases.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Aliases: ${entity.aliases.join(', ')}'),
          ],
          const SizedBox(height: 4),
          Text('First seen: ${entity.firstSeenChapterId}'),
          if (entity.unresolvedNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Needs checking: ${entity.unresolvedNotes.join(' • ')}',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _replace(
                  entity.copyWith(
                    approved: !entity.approved,
                    automaticallyApproved: false,
                  ),
                ),
                icon: Icon(
                  entity.approved ? Icons.undo : Icons.check_circle_outline,
                ),
                label: Text(entity.approved ? 'Mark pending' : 'Approve'),
              ),
              OutlinedButton.icon(
                onPressed: () => _edit(entity),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              if (!entity.approved)
                OutlinedButton.icon(
                  onPressed: () => _merge(entity),
                  icon: const Icon(Icons.merge),
                  label: const Text('Merge'),
                ),
              if (!entity.approved)
                TextButton.icon(
                  onPressed: () => _delete(entity),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(StoryEntityData entity) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: entity.canonicalName);
    final aliases = TextEditingController(text: entity.aliases.join(', '));
    final description = TextEditingController(text: entity.description);
    var kind = entity.kind;
    var importance = entity.importance;
    var recurring = entity.recurring;
    var speaker = entity.speaker;

    final updated = await showDialog<StoryEntityData>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit story subject'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: aliases,
                      decoration: const InputDecoration(
                        labelText: 'Aliases',
                        hintText: 'Comma-separated names',
                      ),
                    ),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      minLines: 2,
                      maxLines: 4,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<StoryEntityKind>(
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        for (final value in StoryEntityKind.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: entity.assetIds.isNotEmpty
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => kind = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<StoryEntityImportance>(
                      initialValue: importance,
                      decoration: const InputDecoration(
                        labelText: 'Importance',
                      ),
                      items: [
                        for (final value in StoryEntityImportance.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => importance = value);
                        }
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Recurring subject'),
                      value: recurring,
                      onChanged: (value) =>
                          setDialogState(() => recurring = value ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Speaking subject'),
                      value: speaker,
                      onChanged: (value) =>
                          setDialogState(() => speaker = value ?? false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  entity.copyWith(
                    kind: kind,
                    canonicalName: name.text.trim(),
                    aliases: _commaList(aliases.text),
                    description: description.text.trim(),
                    importance: importance,
                    recurring: recurring,
                    speaker: speaker,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    aliases.dispose();
    description.dispose();
    if (updated != null) await _replace(updated);
  }

  Future<void> _merge(StoryEntityData source) async {
    final targets = (_bible?.entities ?? const <StoryEntityData>[])
        .where(
          (entity) =>
              entity.entityId != source.entityId && entity.kind == source.kind,
        )
        .toList();
    if (targets.isEmpty) {
      _message(
        'There is no other ${source.kind.label.toLowerCase()} to merge.',
      );
      return;
    }
    final target = await showDialog<StoryEntityData>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Merge ${source.canonicalName} into'),
        children: [
          for (final entity in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entity),
              child: ListTile(
                leading: Icon(entity.kind.icon),
                title: Text(entity.canonicalName),
                subtitle: Text(entity.approved ? 'Approved' : 'Pending'),
              ),
            ),
        ],
      ),
    );
    if (target == null) return;
    final merged = target.mergeCandidate(source);
    await _save([
      for (final entity in _bible!.entities)
        if (entity.entityId != source.entityId)
          entity.entityId == target.entityId ? merged : entity,
    ]);
    _message(
      '${source.canonicalName} was merged into ${target.canonicalName}.',
    );
  }

  Future<void> _delete(StoryEntityData entity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pending subject?'),
        content: Text(
          '${entity.canonicalName} will be removed from this book’s story bible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _save(
      _bible!.entities
          .where((item) => item.entityId != entity.entityId)
          .toList(),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  static List<String> _commaList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
}

extension on StoryEntityKind {
  String get label => switch (this) {
    StoryEntityKind.human => 'Human',
    StoryEntityKind.animal => 'Animal',
    StoryEntityKind.creature => 'Creature',
    StoryEntityKind.plant => 'Plant',
    StoryEntityKind.prop => 'Prop',
    StoryEntityKind.location => 'Location',
  };

  String get groupLabel => switch (this) {
    StoryEntityKind.human => 'People',
    StoryEntityKind.animal => 'Animals',
    StoryEntityKind.creature => 'Creatures',
    StoryEntityKind.plant => 'Plants',
    StoryEntityKind.prop => 'Props',
    StoryEntityKind.location => 'Locations',
  };

  IconData get icon => switch (this) {
    StoryEntityKind.human => Icons.person_outline,
    StoryEntityKind.animal => Icons.pets_outlined,
    StoryEntityKind.creature => Icons.auto_awesome_outlined,
    StoryEntityKind.plant => Icons.local_florist_outlined,
    StoryEntityKind.prop => Icons.inventory_2_outlined,
    StoryEntityKind.location => Icons.landscape_outlined,
  };
}

extension on StoryEntityImportance {
  String get label => switch (this) {
    StoryEntityImportance.background => 'Background',
    StoryEntityImportance.supporting => 'Supporting',
    StoryEntityImportance.focus => 'Visual focus',
  };
}
