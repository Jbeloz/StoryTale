import 'package:flutter/material.dart';

import '../../data/face_profile_catalog.dart';
import '../../data/sprite_face_catalog.dart';
import 'sprite_face_view.dart';

class SpriteFaceEditor extends StatefulWidget {
  const SpriteFaceEditor({
    required this.headAsset,
    required this.legacyCatalog,
    required this.selectedExpressionId,
    required this.onLegacyExpressionSelected,
    super.key,
  });

  final String headAsset;
  final SpriteFaceCatalog legacyCatalog;
  final String selectedExpressionId;
  final ValueChanged<String> onLegacyExpressionSelected;

  @override
  State<SpriteFaceEditor> createState() => _SpriteFaceEditorState();
}

class _SpriteFaceEditorState extends State<SpriteFaceEditor> {
  static const _catalogAsset =
      'assets/images/characters/face_profiles/catalog.json';

  SpriteFaceProfileCatalog? _catalog;
  SpriteFaceProfileBundle? _bundle;
  final _drafts = <String, List<SpriteFaceSet>>{};
  String _profileId = 'default';
  String _setId = 'neutral';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SpriteFaceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_profileId == 'default' &&
        oldWidget.selectedExpressionId != widget.selectedExpressionId) {
      _setId = widget.selectedExpressionId;
    }
  }

  Future<void> _load() async {
    try {
      final catalog = await SpriteFaceProfileCatalog.load(_catalogAsset);
      final bundle = await catalog.loadProfile(_profileId);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _bundle = bundle;
        _setId = widget.selectedExpressionId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The modular face catalog could not load.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _catalog == null || _bundle == null) {
      return Text(_error ?? 'The face catalog is unavailable.');
    }

    final profile = _bundle!.profile;
    final selectedSet = _selectedSet;
    final custom = selectedSet != null && _isDraft(selectedSet.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                key: const Key('faceProfileSelector'),
                value: _profileId,
                isExpanded: true,
                items: [
                  for (final entry in _catalog!.profiles)
                    DropdownMenuItem(value: entry.id, child: Text(entry.label)),
                ],
                onChanged: (value) {
                  if (value != null) _selectProfile(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              avatar: Icon(
                profile.isReady ? Icons.check_circle : Icons.pending_outlined,
                size: 16,
              ),
              label: Text(profile.isReady ? 'Ready' : 'Needs parts'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'sets',
              icon: Icon(Icons.face_retouching_natural),
              label: Text('Sets'),
            ),
            ButtonSegment(
              value: 'parts',
              icon: Icon(Icons.layers_outlined),
              label: Text('Parts'),
              enabled: false,
            ),
          ],
          selected: const {'sets'},
          onSelectionChanged: (_) {},
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 92,
              child: _preview(selectedSet, showUnavailable: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                profile.isReady
                    ? 'Select a reusable set or create your own.'
                    : _profileId == 'default'
                    ? 'Current full-face images stay active until the modular parts are imported.'
                    : '${profile.label} is preview-only until its PNG parts are imported.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final set in _allSets)
              ChoiceChip(
                key: Key(
                  _profileId == 'default'
                      ? 'face-${set.id}'
                      : 'face-$_profileId-${set.id}',
                ),
                avatar: SizedBox.square(dimension: 32, child: _preview(set)),
                label: Text(set.label),
                selected: _setId == set.id,
                onSelected: (_) => _selectSet(set),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: const Key('newFaceSetButton'),
              onPressed: _newSet,
              icon: const Icon(Icons.add),
              label: const Text('New Set'),
            ),
            OutlinedButton.icon(
              key: const Key('duplicateFaceSetButton'),
              onPressed: selectedSet == null ? null : _duplicateSet,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate'),
            ),
            OutlinedButton.icon(
              key: const Key('renameFaceSetButton'),
              onPressed: custom ? _renameSet : null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Rename'),
            ),
            OutlinedButton.icon(
              key: const Key('deleteFaceSetButton'),
              onPressed: custom ? _deleteSet : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'New sets are session drafts until local import and storage are added in Part 7D.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  List<SpriteFaceSet> get _allSets => [
    ...?_bundle?.sets.sets,
    ...?_drafts[_profileId],
  ];

  SpriteFaceSet? get _selectedSet {
    for (final set in _allSets) {
      if (set.id == _setId) return set;
    }
    return _allSets.isEmpty ? null : _allSets.first;
  }

  bool _isDraft(String id) {
    return _drafts[_profileId]?.any((set) => set.id == id) ?? false;
  }

  Future<void> _selectProfile(String profileId) async {
    setState(() {
      _profileId = profileId;
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await _catalog!.loadProfile(profileId);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _setId = profileId == 'default'
            ? widget.selectedExpressionId
            : bundle.profile.defaultSetId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The selected face profile could not load.';
        _loading = false;
      });
    }
  }

  void _selectSet(SpriteFaceSet set) {
    setState(() => _setId = set.id);
    if (_profileId == 'default' &&
        widget.legacyCatalog.expressionsById.containsKey(set.id)) {
      widget.onLegacyExpressionSelected(set.id);
    }
  }

  Widget _preview(SpriteFaceSet? set, {bool showUnavailable = false}) {
    final bundle = _bundle;
    if (bundle == null || set == null) return const SizedBox.shrink();

    if (_profileId == 'default' &&
        widget.legacyCatalog.expressionsById.containsKey(set.id)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(widget.headAsset, fit: BoxFit.fill),
          Image.asset(
            widget.legacyCatalog.expressionsById[set.id]!.asset,
            fit: BoxFit.fill,
          ),
        ],
      );
    }

    if (bundle.profile.isReady) {
      return SpriteFaceView(
        headAsset: widget.headAsset,
        composition: bundle.compositionFromSet(set),
      );
    }

    final reference = bundle.profile.approvedReference;
    if (set.id == 'neutral' && reference != null) {
      return Image.asset(reference, fit: BoxFit.fill);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(widget.headAsset, fit: BoxFit.fill),
        if (showUnavailable)
          const Center(child: Icon(Icons.hourglass_empty, size: 26)),
      ],
    );
  }

  Future<void> _newSet() async {
    final created = await _showSetMaker();
    if (created == null || !mounted) return;
    setState(() {
      _drafts.putIfAbsent(_profileId, () => []).add(created);
      _setId = created.id;
    });
  }

  Future<SpriteFaceSet?> _showSetMaker() async {
    final base = _selectedSet ?? _bundle!.sets.sets.first;
    var name = '';
    var eyes = base.eyes;
    var nose = base.nose;
    var mouth = base.mouth;
    String? error;

    final result = await showDialog<SpriteFaceSet>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final draft = SpriteFaceSet(
            id: 'preview',
            label: name.trim().isEmpty ? 'New Set' : name.trim(),
            eyes: eyes,
            nose: nose,
            mouth: mouth,
            details: base.details,
          );
          return AlertDialog(
            title: const Text('Set Maker'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 120,
                    child: _preview(draft, showUnavailable: true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('faceSetNameInput'),
                    autofocus: true,
                    onChanged: (value) => setDialogState(() => name = value),
                    decoration: InputDecoration(
                      labelText: 'Set name',
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _partPicker(
                    key: const Key('faceEyesPicker'),
                    label: 'Eyes',
                    value: eyes,
                    values: _partValues((set) => set.eyes),
                    onChanged: (value) => setDialogState(() => eyes = value),
                  ),
                  _partPicker(
                    key: const Key('faceNosePicker'),
                    label: 'Nose',
                    value: nose,
                    values: _partValues((set) => set.nose),
                    onChanged: (value) => setDialogState(() => nose = value),
                  ),
                  _partPicker(
                    key: const Key('faceMouthPicker'),
                    label: 'Mouth',
                    value: mouth,
                    values: _partValues((set) => set.mouth),
                    onChanged: (value) => setDialogState(() => mouth = value),
                  ),
                  if (!_bundle!.profile.isReady)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'The composed preview activates after this profile\'s PNG parts are imported.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('saveFaceSetButton'),
                onPressed: () {
                  final safeName = name.trim();
                  if (safeName.length < 2) {
                    setDialogState(
                      () => error = 'Use at least two characters.',
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    SpriteFaceSet(
                      id: _createSetId(safeName),
                      label: safeName,
                      eyes: eyes,
                      nose: nose,
                      mouth: mouth,
                      details: base.details,
                    ),
                  );
                },
                child: const Text('Save Set'),
              ),
            ],
          );
        },
      ),
    );
    return result;
  }

  Widget _partPicker({
    required Key key,
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(_displayName(item))),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  List<String> _partValues(String Function(SpriteFaceSet set) read) {
    return {for (final set in _bundle!.sets.sets) read(set)}.toList();
  }

  void _duplicateSet() {
    final selected = _selectedSet!;
    final label = '${selected.label} Copy';
    final copy = SpriteFaceSet(
      id: _createSetId(label),
      label: label,
      eyes: selected.eyes,
      nose: selected.nose,
      mouth: selected.mouth,
      details: selected.details,
    );
    setState(() {
      _drafts.putIfAbsent(_profileId, () => []).add(copy);
      _setId = copy.id;
    });
  }

  Future<void> _renameSet() async {
    final selected = _selectedSet!;
    var editedName = selected.label;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Set'),
        content: TextFormField(
          key: const Key('renameFaceSetInput'),
          initialValue: selected.label,
          autofocus: true,
          onChanged: (value) => editedName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editedName.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name == null || name.length < 2 || !mounted) return;
    final drafts = _drafts[_profileId]!;
    final index = drafts.indexWhere((set) => set.id == selected.id);
    setState(() {
      drafts[index] = SpriteFaceSet(
        id: selected.id,
        label: name,
        eyes: selected.eyes,
        nose: selected.nose,
        mouth: selected.mouth,
        details: selected.details,
      );
    });
  }

  Future<void> _deleteSet() async {
    final selected = _selectedSet!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete face set?'),
        content: Text('${selected.label} will be removed from this session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmDeleteFaceSetButton'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _drafts[_profileId]!.removeWhere((set) => set.id == selected.id);
      _setId = _bundle!.profile.defaultSetId;
    });
  }

  String _createSetId(String name) {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('^_+|_+\$'), '');
    final safeBase = base.isEmpty ? 'custom_set' : base;
    final ids = _allSets.map((set) => set.id).toSet();
    if (!ids.contains(safeBase)) return safeBase;
    var suffix = 2;
    while (ids.contains('${safeBase}_$suffix')) {
      suffix++;
    }
    return '${safeBase}_$suffix';
  }

  String _displayName(String id) {
    return id
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
