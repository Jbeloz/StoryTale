import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../../data/face_local_repository.dart';
import '../../data/face_profile_catalog.dart';
import '../../data/sprite_face_catalog.dart';
import 'sprite_face_view.dart';

class SpriteFaceEditor extends StatefulWidget {
  const SpriteFaceEditor({
    required this.headAsset,
    required this.legacyCatalog,
    required this.selectedExpressionId,
    required this.onLegacyExpressionSelected,
    required this.onPreviewChanged,
    super.key,
  });

  final String headAsset;
  final SpriteFaceCatalog legacyCatalog;
  final String selectedExpressionId;
  final ValueChanged<String> onLegacyExpressionSelected;
  final ValueChanged<SpriteFaceOverlayData?> onPreviewChanged;

  @override
  State<SpriteFaceEditor> createState() => _SpriteFaceEditorState();
}

class _SpriteFaceEditorState extends State<SpriteFaceEditor> {
  static const _catalogAsset =
      'assets/images/characters/face_profiles/catalog.json';

  SpriteFaceProfileCatalog? _catalog;
  SpriteFaceProfileBundle? _bundle;
  final _repository = FaceLocalRepository();
  final _customSets = <String, List<SpriteFaceSet>>{};
  final _localParts = <String, LocalSpriteFacePart>{};
  String _profileId = 'default';
  String _setId = 'neutral';
  String _tab = 'sets';
  SpriteFacePartType _partType = SpriteFacePartType.eyes;
  String? _partId;
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
      final local = await _repository.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _bundle = bundle;
        _localParts
          ..clear()
          ..addEntries(local.parts.map((part) => MapEntry(part.key, part)));
        _customSets
          ..clear()
          ..addAll(local.sets);
        _setId = widget.selectedExpressionId;
        _partId = _partIds(_partType).firstOrNull;
        _loading = false;
      });
      _notifyPreview();
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
                _selectedSetReady ? Icons.check_circle : Icons.pending_outlined,
                size: 16,
              ),
              label: Text(
                _profileId == 'default'
                    ? 'Legacy ready'
                    : _selectedSetReady
                    ? 'Set ready'
                    : '${_installedCount(profile)}/$_expectedCount parts',
              ),
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
            ),
          ],
          selected: {_tab},
          onSelectionChanged: (value) => setState(() => _tab = value.first),
        ),
        const SizedBox(height: 10),
        if (_tab == 'sets')
          _setsPanel(profile, selectedSet, custom)
        else
          _partsPanel(profile),
      ],
    );
  }

  Widget _setsPanel(
    SpriteFaceProfile profile,
    SpriteFaceSet? selectedSet,
    bool custom,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                _profileId == 'default'
                    ? 'The original five faces remain available.'
                    : _selectedSetReady
                    ? '${profile.label} is composed from the imported parts.'
                    : 'Import the missing PNG parts to show ${profile.label} on the character.',
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
          'Custom sets and imported parts are saved locally on this device.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _partsPanel(SpriteFaceProfile profile) {
    final types = _partTypes;
    final ids = _partIds(_partType);
    final selectedId = ids.contains(_partId) ? _partId : ids.firstOrNull;
    final selected = selectedId == null
        ? null
        : _localPart(_partType, selectedId);
    final custom =
        selectedId != null && !_expectedIds(_partType).contains(selectedId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<SpriteFacePartType>(
          key: const Key('facePartTypeSelector'),
          segments: [
            for (final type in types)
              ButtonSegment(value: type, label: Text(type.label)),
          ],
          selected: {_partType},
          onSelectionChanged: (value) {
            final type = value.first;
            setState(() {
              _partType = type;
              _partId = _partIds(type).firstOrNull;
            });
          },
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 92,
              child: _partPreview(_partType, selectedId),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected == null
                    ? 'Select a slot, then import its transparent PNG.'
                    : '${selected.label} is stored locally and ready to use.',
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
            for (final id in ids)
              ChoiceChip(
                key: Key('facePart-${_partType.name}-$id'),
                avatar: Icon(
                  _localPart(_partType, id) != null
                      ? Icons.check_circle
                      : Icons.download_outlined,
                  size: 16,
                ),
                label: Text(_partLabel(_partType, id)),
                selected: selectedId == id,
                onSelected: (_) => setState(() => _partId = id),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: const Key('importFacePartButton'),
              onPressed: selectedId == null
                  ? null
                  : () => _importPart(
                      type: _partType,
                      id: selectedId,
                      label: _partLabel(_partType, selectedId),
                    ),
              icon: const Icon(Icons.upload_file),
              label: Text(selected == null ? 'Import PNG' : 'Replace PNG'),
            ),
            OutlinedButton.icon(
              key: const Key('addFacePartButton'),
              onPressed: _addPart,
              icon: const Icon(Icons.add),
              label: const Text('Add Part'),
            ),
            OutlinedButton.icon(
              key: const Key('renameFacePartButton'),
              onPressed: selected != null && custom ? _renamePart : null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Rename'),
            ),
            OutlinedButton.icon(
              key: const Key('deleteFacePartButton'),
              onPressed: selected != null && custom ? _deletePart : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'PNG only • ${profile.canvasWidth} × ${profile.canvasHeight} • transparent • maximum 2 MB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  List<SpriteFaceSet> get _allSets => [
    ...?_bundle?.sets.sets,
    ...?_customSets[_profileId],
  ];

  SpriteFaceSet? get _selectedSet {
    for (final set in _allSets) {
      if (set.id == _setId) return set;
    }
    return _allSets.isEmpty ? null : _allSets.first;
  }

  bool _isDraft(String id) {
    return _customSets[_profileId]?.any((set) => set.id == id) ?? false;
  }

  List<SpriteFacePartType> get _partTypes {
    final types = [
      SpriteFacePartType.eyes,
      SpriteFacePartType.nose,
      SpriteFacePartType.mouth,
    ];
    if (_expectedIds(SpriteFacePartType.details).isNotEmpty ||
        _partsFor(SpriteFacePartType.details).isNotEmpty) {
      types.add(SpriteFacePartType.details);
    }
    return types;
  }

  Set<String> _expectedIds(SpriteFacePartType type) {
    final sets = _bundle?.sets.sets ?? const <SpriteFaceSet>[];
    return switch (type) {
      SpriteFacePartType.eyes => {for (final set in sets) set.eyes},
      SpriteFacePartType.nose => {for (final set in sets) set.nose},
      SpriteFacePartType.mouth => {for (final set in sets) set.mouth},
      SpriteFacePartType.details => {
        for (final set in sets)
          for (final detail in set.details) detail,
      },
    };
  }

  List<LocalSpriteFacePart> _partsFor(SpriteFacePartType type) {
    return _localParts.values
        .where((part) => part.profileId == _profileId && part.type == type)
        .toList();
  }

  List<String> _partIds(SpriteFacePartType type) {
    return {
      ..._expectedIds(type),
      ..._partsFor(type).map((part) => part.id),
    }.toList();
  }

  LocalSpriteFacePart? _localPart(SpriteFacePartType type, String id) {
    return _localParts['$_profileId|${type.storageName}|$id'];
  }

  String _partLabel(SpriteFacePartType type, String id) {
    return _localPart(type, id)?.label ?? _displayName(id);
  }

  int get _expectedCount =>
      SpriteFacePartType.values.expand(_expectedIds).length;

  int _installedCount(SpriteFaceProfile profile) {
    if (profile.isReady) return _expectedCount;
    return SpriteFacePartType.values.fold(
      0,
      (total, type) =>
          total +
          _expectedIds(type).where((id) => _localPart(type, id) != null).length,
    );
  }

  bool get _selectedSetReady {
    if (_profileId == 'default') return true;
    final selected = _selectedSet;
    return selected != null && _overlayFor(selected) != null;
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
        _partType = SpriteFacePartType.eyes;
        _partId = _partIds(_partType).firstOrNull;
        _loading = false;
      });
      _notifyPreview();
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
    _notifyPreview();
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

    final overlay = _overlayFor(set);
    if (overlay != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(widget.headAsset, fit: BoxFit.fill),
          SpriteFaceOverlayView(data: overlay),
        ],
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

  Widget _partPreview(SpriteFacePartType type, String? id) {
    final part = id == null ? null : _localPart(type, id);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(widget.headAsset, fit: BoxFit.fill),
        if (part != null)
          Image.memory(
            part.bytes,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          )
        else
          const Center(child: Icon(Icons.upload_file, size: 26)),
      ],
    );
  }

  SpriteFaceOverlayData? _overlayFor(SpriteFaceSet set) {
    final profile = _bundle!.profile;
    final layers = <SpriteFaceLayer>[];
    final parts = [
      (SpriteFacePartType.eyes, set.eyes),
      (SpriteFacePartType.nose, set.nose),
      (SpriteFacePartType.mouth, set.mouth),
      for (final detail in set.details) (SpriteFacePartType.details, detail),
    ];
    for (final entry in parts) {
      final local = _localPart(entry.$1, entry.$2);
      if (local != null) {
        layers.add(SpriteFaceLayer.memory(local.bytes));
        continue;
      }
      if (!profile.isReady) return null;
      layers.add(
        SpriteFaceLayer.asset(_bundledAsset(profile, entry.$1, entry.$2)),
      );
    }
    return SpriteFaceOverlayData(
      profileId: _profileId,
      setId: set.id,
      layers: layers,
    );
  }

  String _bundledAsset(
    SpriteFaceProfile profile,
    SpriteFacePartType type,
    String id,
  ) {
    final directory = switch (type) {
      SpriteFacePartType.eyes => profile.parts.eyes,
      SpriteFacePartType.nose => profile.parts.noses,
      SpriteFacePartType.mouth => profile.parts.mouths,
      SpriteFacePartType.details => profile.parts.details,
    };
    return profile.parts.asset(directory, id);
  }

  void _notifyPreview() {
    final selected = _selectedSet;
    final preview = _profileId == 'default'
        ? null
        : selected == null
        ? SpriteFaceOverlayData(
            profileId: _profileId,
            setId: 'neutral',
            layers: const [],
          )
        : _overlayFor(selected) ??
              SpriteFaceOverlayData(
                profileId: _profileId,
                setId: selected.id,
                layers: const [],
              );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPreviewChanged(preview);
    });
  }

  Future<void> _newSet() async {
    final created = await _showSetMaker();
    if (created == null || !mounted) return;
    setState(() {
      _customSets.putIfAbsent(_profileId, () => []).add(created);
      _setId = created.id;
    });
    await _persist();
    _notifyPreview();
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
                    values: _partValues(
                      SpriteFacePartType.eyes,
                      (set) => set.eyes,
                    ),
                    onChanged: (value) => setDialogState(() => eyes = value),
                  ),
                  _partPicker(
                    key: const Key('faceNosePicker'),
                    label: 'Nose',
                    value: nose,
                    values: _partValues(
                      SpriteFacePartType.nose,
                      (set) => set.nose,
                    ),
                    onChanged: (value) => setDialogState(() => nose = value),
                  ),
                  _partPicker(
                    key: const Key('faceMouthPicker'),
                    label: 'Mouth',
                    value: mouth,
                    values: _partValues(
                      SpriteFacePartType.mouth,
                      (set) => set.mouth,
                    ),
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

  List<String> _partValues(
    SpriteFacePartType type,
    String Function(SpriteFaceSet set) read,
  ) {
    final bundled = {for (final set in _bundle!.sets.sets) read(set)};
    return {...bundled, ..._partsFor(type).map((part) => part.id)}.toList();
  }

  Future<void> _duplicateSet() async {
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
      _customSets.putIfAbsent(_profileId, () => []).add(copy);
      _setId = copy.id;
    });
    await _persist();
    _notifyPreview();
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
    final drafts = _customSets[_profileId]!;
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
    await _persist();
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
      _customSets[_profileId]!.removeWhere((set) => set.id == selected.id);
      _setId = _bundle!.profile.defaultSetId;
    });
    await _persist();
    _notifyPreview();
  }

  Future<void> _addPart() async {
    var name = '';
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${_partType.label} Part'),
        content: TextFormField(
          key: const Key('newFacePartNameInput'),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Part name'),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('continueFacePartImportButton'),
            onPressed: () => Navigator.pop(context, name.trim()),
            child: const Text('Choose PNG'),
          ),
        ],
      ),
    );
    if (label == null || label.length < 2 || !mounted) return;
    final id = _createPartId(_partType, label);
    await _importPart(type: _partType, id: id, label: label);
  }

  Future<void> _importPart({
    required SpriteFacePartType type,
    required String id,
    required String label,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      _message('The PNG could not be loaded.');
      return;
    }
    final problem = _pngProblem(bytes);
    if (problem != null) {
      _message(problem);
      return;
    }

    final part = LocalSpriteFacePart(
      profileId: _profileId,
      type: type,
      id: id,
      label: label,
      bytes: bytes,
    );
    setState(() {
      _localParts[part.key] = part;
      _partType = type;
      _partId = id;
    });
    await _persist();
    _notifyPreview();
    _message('$label imported.');
  }

  String? _pngProblem(Uint8List bytes) {
    if (bytes.length > 2 * 1024 * 1024) {
      return 'Use a PNG smaller than 2 MB.';
    }
    final decoded = image.decodePng(bytes);
    if (decoded == null) return 'Choose a valid PNG file.';
    final profile = _bundle!.profile;
    if (decoded.width != profile.canvasWidth ||
        decoded.height != profile.canvasHeight) {
      return 'The PNG must be ${profile.canvasWidth} × ${profile.canvasHeight}.';
    }
    final hasClearPixel = decoded.data.any(
      (pixel) => image.getAlpha(pixel) < 255,
    );
    final hasVisiblePixel = decoded.data.any(
      (pixel) => image.getAlpha(pixel) > 0,
    );
    if (decoded.channels != image.Channels.rgba || !hasClearPixel) {
      return 'The PNG needs a transparent background.';
    }
    if (!hasVisiblePixel) return 'The PNG is completely empty.';
    return null;
  }

  Future<void> _renamePart() async {
    final oldId = _partId!;
    final oldPart = _localPart(_partType, oldId)!;
    var value = oldPart.label;
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Part'),
        content: TextFormField(
          key: const Key('renameFacePartInput'),
          initialValue: oldPart.label,
          autofocus: true,
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (label == null || label.length < 2 || !mounted) return;
    final newId = _createPartId(_partType, label, ignoreId: oldId);
    final renamed = LocalSpriteFacePart(
      profileId: _profileId,
      type: _partType,
      id: newId,
      label: label,
      bytes: oldPart.bytes,
    );
    setState(() {
      _localParts.remove(oldPart.key);
      _localParts[renamed.key] = renamed;
      _partId = newId;
      final sets = _customSets[_profileId] ?? const <SpriteFaceSet>[];
      _customSets[_profileId] = [
        for (final set in sets) _replaceSetPart(set, _partType, oldId, newId),
      ];
    });
    await _persist();
    _notifyPreview();
  }

  Future<void> _deletePart() async {
    final id = _partId!;
    final usedBy = _allSets
        .where((set) => _setUsesPart(set, _partType, id))
        .map((set) => set.label)
        .toList();
    if (usedBy.isNotEmpty) {
      _message('This part is used by: ${usedBy.join(', ')}.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete face part?'),
        content: Text('${_partLabel(_partType, id)} will be removed locally.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmDeleteFacePartButton'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _localParts.remove('$_profileId|${_partType.storageName}|$id');
      _partId = _partIds(_partType).firstOrNull;
    });
    await _persist();
    _notifyPreview();
  }

  bool _setUsesPart(SpriteFaceSet set, SpriteFacePartType type, String id) {
    return switch (type) {
      SpriteFacePartType.eyes => set.eyes == id,
      SpriteFacePartType.nose => set.nose == id,
      SpriteFacePartType.mouth => set.mouth == id,
      SpriteFacePartType.details => set.details.contains(id),
    };
  }

  SpriteFaceSet _replaceSetPart(
    SpriteFaceSet set,
    SpriteFacePartType type,
    String oldId,
    String newId,
  ) {
    return SpriteFaceSet(
      id: set.id,
      label: set.label,
      eyes: type == SpriteFacePartType.eyes && set.eyes == oldId
          ? newId
          : set.eyes,
      nose: type == SpriteFacePartType.nose && set.nose == oldId
          ? newId
          : set.nose,
      mouth: type == SpriteFacePartType.mouth && set.mouth == oldId
          ? newId
          : set.mouth,
      details: [
        for (final detail in set.details)
          if (type == SpriteFacePartType.details && detail == oldId)
            newId
          else
            detail,
      ],
    );
  }

  Future<void> _persist() async {
    try {
      await _repository.save(
        SpriteFaceLocalData(
          parts: _localParts.values.toList(),
          sets: {
            for (final entry in _customSets.entries)
              if (entry.value.isNotEmpty) entry.key: entry.value,
          },
        ),
      );
    } catch (_) {
      if (mounted) _message('Local face storage is currently unavailable.');
    }
  }

  String _createPartId(
    SpriteFacePartType type,
    String name, {
    String? ignoreId,
  }) {
    var base = _safeId(name, fallback: 'custom_part');
    final used = _partIds(type).where((id) => id != ignoreId).toSet();
    var id = base;
    var suffix = 2;
    while (used.contains(id)) {
      id = '${base}_$suffix';
      suffix++;
    }
    return id;
  }

  String _createSetId(String name) {
    final safeBase = _safeId(name, fallback: 'custom_set');
    final ids = _allSets.map((set) => set.id).toSet();
    if (!ids.contains(safeBase)) return safeBase;
    var suffix = 2;
    while (ids.contains('${safeBase}_$suffix')) {
      suffix++;
    }
    return '${safeBase}_$suffix';
  }

  String _safeId(String name, {required String fallback}) {
    final id = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('^_+|_+\$'), '');
    return id.isEmpty ? fallback : id;
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

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
