import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../shared/widgets/storytale_components.dart';
import '../data/pose_repository.dart';
import '../data/sprite_appearance.dart';
import '../data/sprite_face_catalog.dart';
import '../data/sprite_rig.dart';
import 'widgets/sprite_face_editor.dart';
import 'widgets/sprite_face_view.dart';
import 'widgets/sprite_rig_view.dart';

class SpritePositionerPage extends StatefulWidget {
  const SpritePositionerPage({
    this.initialRig,
    this.initialPoses,
    this.initialPartBytes,
    this.initialTitle,
    super.key,
  });

  final SpriteRigDefinition? initialRig;
  final Map<String, SpriteRigPose>? initialPoses;
  final Map<String, Uint8List>? initialPartBytes;
  final String? initialTitle;

  @override
  State<SpritePositionerPage> createState() => _SpritePositionerPageState();
}

class _SpritePositionerPageState extends State<SpritePositionerPage> {
  static const _rigAsset = 'assets/images/characters/rigs/humanoid_v1/rig.json';
  static const _faceCatalogAsset =
      'assets/images/characters/rigs/humanoid_v1/faces/catalog.json';
  static const _adminUrl = 'http://127.0.0.1:52828';
  static const _builtInPoses = {
    'neutral': 'assets/images/characters/rigs/humanoid_v1/poses/neutral.json',
    'talking': 'assets/images/characters/rigs/humanoid_v1/poses/talking.json',
    'pointing': 'assets/images/characters/rigs/humanoid_v1/poses/pointing.json',
    'walking': 'assets/images/characters/rigs/humanoid_v1/poses/walking.json',
  };
  static const _builtInLabels = {
    'neutral': 'Idle',
    'talking': 'Talking',
    'pointing': 'Pointing',
    'walking': 'Walking',
  };
  final _poseRepository = PoseRepository();
  final _appearanceRepository = const SpriteAppearanceRepository();
  final _injectedPoses = <String, SpriteRigPose>{};
  SpriteRigDefinition? _rig;
  SpriteFaceCatalog? _faceCatalog;
  SpriteFaceOverlayData? _faceOverlay;
  SpriteAppearanceSelection _appearance = const SpriteAppearanceSelection();
  SpriteRigPose? _pose;
  SpriteRigPose? _initialPose;
  final _sessionDrafts = <String, SpriteRigPose>{};
  final _customPoses = <SpriteRigPose>[];
  final _persistedCustomIds = <String>{};
  final _projectPoseIds = <String>{};
  String? _selectedPartId;
  String? _error;
  String _selectedPoseId = 'neutral';
  bool _showAnchors = false;
  bool _showHitboxes = false;
  bool _showBones = true;
  bool _boneMode = false;
  bool _dragEnabled = false;
  bool _dragHistoryRecorded = false;
  bool _savingDefault = false;
  double _zoom = 1;
  final _savedDefaults = <String, SpriteRigPose>{};
  final _undoStack = <SpriteRigPose>[];
  final _redoStack = <SpriteRigPose>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_usesInjectedSource) {
      _loadInjectedSource();
      return;
    }
    try {
      final results = await Future.wait([
        SpriteRigDefinition.load(_rigAsset),
        SpriteRigPose.load(_builtInPoses[_selectedPoseId]!),
        SpriteFaceCatalog.load(_faceCatalogAsset),
        _poseRepository.loadProjectPoses(),
        _poseRepository.loadAll(),
        _appearanceRepository.load(),
      ]);
      if (!mounted) return;
      final rig = results[0] as SpriteRigDefinition;
      final catalog = results[2] as SpriteFaceCatalog;
      final projectPoses = results[3] as List<SpriteRigPose>;
      final localPoses = results[4] as List<SpriteRigPose>;
      final appearance = results[5] as SpriteAppearanceSelection;
      final customPoses = {
        for (final pose in projectPoses) pose.id: pose,
        for (final pose in localPoses) pose.id: pose,
      }.values.toList();
      final loadedPose = SpriteLayerPolicy.normalize(
        results[1] as SpriteRigPose,
      );
      final pose = _applyAppearance(
        loadedPose.withFaceExpression(
          catalog.resolveId(loadedPose.faceExpressionId),
        ),
        appearance,
        rig: rig,
      );
      setState(() {
        _rig = rig;
        _faceCatalog = catalog;
        _appearance = appearance;
        _pose = pose;
        _initialPose = pose;
        _customPoses
          ..clear()
          ..addAll(customPoses)
          ..sort(
            (left, right) => left.displayName.compareTo(right.displayName),
          );
        _persistedCustomIds
          ..clear()
          ..addAll(localPoses.map((value) => value.id));
        _projectPoseIds
          ..clear()
          ..addAll(projectPoses.map((value) => value.id));
        _selectedPartId = rig.partsById.containsKey('upper_arm_right')
            ? 'upper_arm_right'
            : rig.parts.first.id;
      });
    } catch (error, stackTrace) {
      debugPrint('Sprite Studio load failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = 'The humanoid rig could not load.');
    }
  }

  void _loadInjectedSource() {
    final rig = widget.initialRig!;
    final suppliedPoses = widget.initialPoses;
    _injectedPoses
      ..clear()
      ..addAll(
        suppliedPoses == null || suppliedPoses.isEmpty
            ? {
                'neutral': SpriteRigPose(
                  id: 'neutral',
                  name: 'Idle',
                  rigId: rig.id,
                ),
              }
            : suppliedPoses,
      );
    final selectedId = _injectedPoses.containsKey('neutral')
        ? 'neutral'
        : _injectedPoses.keys.first;
    final pose = _normalizePose(_injectedPoses[selectedId]!);
    _injectedPoses[selectedId] = pose;
    setState(() {
      _rig = rig;
      _faceCatalog = null;
      _selectedPoseId = selectedId;
      _pose = pose;
      _initialPose = pose;
      _selectedPartId = rig.partsById.containsKey('upper_arm_right')
          ? 'upper_arm_right'
          : rig.parts.first.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rig = _rig;
    final pose = _pose;
    final title = widget.initialTitle ?? 'Sprite Studio';
    if (_error != null) {
      return StoryTaleInfoPage(title: title, description: _error!);
    }
    if (rig == null || pose == null) {
      return StoryTaleAppShell(
        title: title,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StoryTaleAppShell(
      title: title,
      actions: [
        IconButton(
          key: const Key('undoButton'),
          tooltip: 'Undo last pose change',
          onPressed: _undoStack.isEmpty ? null : _undo,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          key: const Key('redoButton'),
          tooltip: 'Redo last pose change',
          onPressed: _redoStack.isEmpty ? null : _redo,
          icon: const Icon(Icons.redo),
        ),
        IconButton(
          tooltip: 'Reset selected pose',
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop =
              constraints.maxWidth >= 900 && constraints.maxHeight >= 600;
          return desktop
              ? _desktopEditor(rig, pose)
              : _mobileEditor(rig, pose, constraints);
        },
      ),
    );
  }

  Widget _desktopEditor(SpriteRigDefinition rig, SpriteRigPose pose) {
    return Column(
      key: const Key('desktopStudio'),
      children: [
        _poseSelector(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(flex: 3, child: _canvasPanel(rig, pose)),
                const SizedBox(width: 16),
                SizedBox(width: 420, child: _inspectorPanel(rig, pose)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileEditor(
    SpriteRigDefinition rig,
    SpriteRigPose pose,
    BoxConstraints constraints,
  ) {
    return Stack(
      key: const Key('mobileStudio'),
      children: [
        SizedBox(
          height: constraints.maxHeight * 0.48,
          child: Column(
            children: [
              _poseSelector(compact: true),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: _canvasPanel(rig, pose),
                ),
              ),
            ],
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.53,
          minChildSize: 0.42,
          maxChildSize: 0.82,
          snap: true,
          snapSizes: const [0.42, 0.53, 0.82],
          builder: (context, controller) {
            return Material(
              key: const Key('spriteInspector'),
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (_selectedPartId == null) ...[
                    Expanded(child: _noSelectionMessage()),
                  ] else ...[
                    _selectionSummary(rig, pose),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.all(12),
                        child: _inspectorSections(rig, pose),
                      ),
                    ),
                  ],
                  _saveBar(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _poseSelector({bool compact = false}) {
    final poseItems = <({String id, String name})>[
      for (final entry in _availableBuiltInLabels.entries)
        (id: entry.key, name: entry.value),
      for (final pose in _customPoses) (id: pose.id, name: pose.displayName),
    ];
    return SizedBox(
      height: compact ? 54 : 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: 8,
        ),
        children: [
          if (!compact) ...[
            const Center(child: Text('Pose')),
            const SizedBox(width: 12),
          ],
          for (final item in poseItems) ...[
            ChoiceChip(
              key: Key('pose-${item.id}'),
              label: Text(
                '${item.name}${item.id == _selectedPoseId && _isDirty ? ' *' : ''}',
              ),
              selected: _selectedPoseId == item.id,
              onSelected: (_) => _selectPose(item.id),
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            key: const Key('newPoseButton'),
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('New Pose'),
            onPressed: _newPose,
          ),
        ],
      ),
    );
  }

  Widget _canvasPanel(SpriteRigDefinition rig, SpriteRigPose pose) {
    final selected = rig.partsById[_selectedPartId];
    final canDragSelected =
        selected != null && !_boneMode && (_dragEnabled || !selected.hasBone);
    return DecoratedBox(
      key: const Key('spriteCanvas'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fitScale = math.min(
                    constraints.maxWidth / rig.canvasSize.width,
                    constraints.maxHeight / rig.canvasSize.height,
                  );
                  final scale = fitScale * _zoom;
                  return ClipRect(
                    child: Center(
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: SizedBox(
                          width: rig.canvasSize.width * scale,
                          height: rig.canvasSize.height * scale,
                          child: GestureDetector(
                            onPanStart: canDragSelected
                                ? (_) => _dragHistoryRecorded = false
                                : null,
                            onPanUpdate: canDragSelected
                                ? (details) => _dragSelected(details, scale)
                                : null,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: SpriteRigView(
                                rig: rig,
                                pose: pose,
                                skinTone: _colorFromHex(_appearance.skinTone),
                                partBytes: widget.initialPartBytes,
                                faceCatalog: _faceCatalog,
                                faceOverlay: _faceOverlay,
                                showAnchors: _showAnchors,
                                showHitboxes: _showHitboxes,
                                showBones: _showBones,
                                boneMode: _boneMode,
                                selectedPartId: _selectedPartId,
                                onPartSelected: _selectPart,
                                onBoneDragStarted: _rememberPose,
                                onPartTransformChanged: _updatePart,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _fitView,
                    icon: const Icon(Icons.fit_screen, size: 18),
                    label: const Text('Fit'),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: _zoom <= 0.6 ? null : () => _changeZoom(-0.2),
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${(_zoom * 100).round()}%',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: _zoom >= 2 ? null : () => _changeZoom(0.2),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Reset view',
                    onPressed: _fitView,
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inspectorPanel(SpriteRigDefinition rig, SpriteRigPose pose) {
    return DecoratedBox(
      key: const Key('spriteInspector'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          if (_selectedPartId == null) ...[
            Expanded(child: _noSelectionMessage()),
          ] else ...[
            _selectionSummary(rig, pose),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: _inspectorSections(rig, pose),
              ),
            ),
          ],
          _saveBar(),
        ],
      ),
    );
  }

  Widget _noSelectionMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No body part selected.\nClick a visible part to select it.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _selectionSummary(SpriteRigDefinition rig, SpriteRigPose pose) {
    final selected = rig.partsById[_selectedPartId]!;
    final transform = pose.transformFor(selected.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(selected.id),
            initialValue: selected.id,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Selected body part',
              border: OutlineInputBorder(),
            ),
            items: rig.parts
                .map(
                  (part) =>
                      DropdownMenuItem(value: part.id, child: Text(part.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) _selectPart(value);
            },
          ),
          const SizedBox(height: 7),
          Text(
            'Rotation ${transform.rotation.round()}°  •  '
            'X ${transform.offsetX.round()}  •  Y ${transform.offsetY.round()}'
            '${selected.hasBone ? '' : '  •  Size ${(transform.scale * 100).round()}%'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _inspectorSections(SpriteRigDefinition rig, SpriteRigPose pose) {
    final selected = rig.partsById[_selectedPartId]!;
    final transform = pose.transformFor(selected.id);
    final selectedLayer = SpriteLayerPolicy.effectiveLayer(selected, transform);
    final layerLocked = SpriteLayerPolicy.isLocked(selected.id);
    final layers = rig.parts.map(_effectiveLayer);
    final backLayer = layers.reduce(math.min);
    final frontLayer = layers.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_usesInjectedSource)
          _section('Appearance', [_appearanceSelector()]),
        if (selected.id == 'back_hair')
          _section('Back hair parts', [
            _backHairSelector(),
            const SizedBox(height: 8),
            const Text(
              'Each actor and hair style keeps its own saved position and size.',
            ),
          ]),
        if (_faceCatalog != null)
          Visibility(
            visible: !_isHairSlot(selected.id),
            maintainState: true,
            child: _section('Face', [_faceSelector(rig, pose)]),
          ),
        _section('Bones', [
          SwitchListTile(
            key: const Key('showBonesSwitch'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show bones'),
            subtitle: const Text('Editor guides only; never saved as artwork.'),
            value: _showBones,
            onChanged: (value) {
              setState(() {
                _showBones = value;
                if (!value) _boneMode = false;
              });
            },
          ),
          SwitchListTile(
            key: const Key('boneModeSwitch'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Bone mode'),
            subtitle: Text(
              selected.parentId == null
                  ? 'Drag the root handle to move the connected rig.'
                  : 'Drag the selected bone handle to rotate this part.',
            ),
            value: _boneMode,
            onChanged: (value) {
              setState(() {
                _boneMode = value;
                if (value) {
                  _showBones = true;
                  _dragEnabled = false;
                }
              });
            },
          ),
        ]),
        _section('Transform', [
          _transformControl(
            id: 'rotation',
            label: 'Rotation',
            value: transform.rotation,
            min: selected.rotationRange?.min ?? -180,
            max: selected.rotationRange?.max ?? 180,
            suffix: '°',
            onSliderStart: _rememberPose,
            onChanged: (value) => _setRotation(value),
          ),
          _transformControl(
            id: 'x',
            label: 'Horizontal offset',
            value: transform.offsetX,
            min: _isHairSlot(selected.id) ? -180 : -80,
            max: _isHairSlot(selected.id) ? 180 : 80,
            onSliderStart: _rememberPose,
            onChanged: (value) => _setHorizontalOffset(value),
          ),
          _transformControl(
            id: 'y',
            label: 'Vertical offset',
            value: transform.offsetY,
            min: _isHairSlot(selected.id) ? -180 : -80,
            max: _isHairSlot(selected.id) ? 180 : 80,
            onSliderStart: _rememberPose,
            onChanged: (value) => _setVerticalOffset(value),
          ),
          if (!selected.hasBone)
            _transformControl(
              id: 'scale',
              label: 'Size',
              value: transform.scale * 100,
              min: _isHairSlot(selected.id) ? 30 : 50,
              max: _isHairSlot(selected.id) ? 250 : 180,
              suffix: '%',
              onSliderStart: _rememberPose,
              onChanged: (value) => _setScale(value / 100),
            ),
          if (!selected.hasBone)
            Text(
              '${selected.parentId == null ? '' : 'Attached to ${rig.partsById[selected.parentId]?.label ?? selected.parentId}. '}'
              '${_isHairSlot(selected.id) ? 'This hair fit is shared by ${SpriteAppearanceCatalog.actor(_appearance.actorId).label} across every pose. ' : 'Drag it directly to adjust only this attachment. '}'
              'Use Save project default to keep its position and size.',
            ),
        ]),
        _section('Layers', [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show joint anchors'),
            value: _showAnchors,
            onChanged: (value) => setState(() => _showAnchors = value),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show body-part hitboxes'),
            value: _showHitboxes,
            onChanged: (value) => setState(() => _showHitboxes = value),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Drag body parts'),
            subtitle: const Text('Off keeps selection enabled without moving.'),
            value: _dragEnabled,
            onChanged: (value) {
              setState(() {
                _dragEnabled = value;
                if (value) _boneMode = false;
              });
            },
          ),
          Text('Layer order: $selectedLayer'),
          if (layerLocked)
            const Text(
              'Fixed body layer: saved poses keep the approved overlap order.',
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: layerLocked || selectedLayer == backLayer
                      ? null
                      : _sendToBack,
                  icon: const Icon(Icons.vertical_align_bottom),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: layerLocked || selectedLayer == frontLayer
                      ? null
                      : _bringToFront,
                  icon: const Icon(Icons.vertical_align_top),
                  label: const Text('Front'),
                ),
              ),
            ],
          ),
        ]),
        _section('Pose', [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _sessionDrafts.containsKey(_selectedPoseId)
                    ? _loadSaved
                    : null,
                icon: const Icon(Icons.restore),
                label: const Text('Load session'),
              ),
              OutlinedButton.icon(
                key: const Key('renamePoseButton'),
                onPressed: _isBuiltIn ? null : _renamePose,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Rename'),
              ),
              OutlinedButton.icon(
                key: const Key('duplicatePoseButton'),
                onPressed: _duplicatePose,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Duplicate'),
              ),
              OutlinedButton.icon(
                key: const Key('deletePoseButton'),
                onPressed: _isBuiltIn ? null : _deletePose,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
              OutlinedButton.icon(
                onPressed: _copyJson,
                icon: const Icon(Icons.copy),
                label: const Text('Copy JSON'),
              ),
              OutlinedButton.icon(
                key: const Key('saveProjectDefaultButton'),
                onPressed: _savingDefault ? null : _saveAsDefault,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: Text(
                  _savingDefault ? 'Saving...' : 'Save project default',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isBuiltIn
                ? 'Built-in poses can be duplicated, but not renamed or deleted.'
                : 'Custom poses are stored locally on this device.',
          ),
        ]),
      ],
    );
  }

  Widget _faceSelector(SpriteRigDefinition rig, SpriteRigPose pose) {
    final catalog = _faceCatalog!;
    final headAsset = rig.partsById[catalog.headPartId]!.asset;
    return SpriteFaceEditor(
      headAsset: headAsset,
      legacyCatalog: catalog,
      selectedExpressionId: pose.faceExpressionId,
      selectedProfileId: pose.faceProfileId,
      selectedSetId: pose.faceSetId,
      onSelectionChanged: _setFaceSelection,
      onPreviewChanged: (value) {
        if (_faceOverlay == value) return;
        setState(() => _faceOverlay = value);
      },
    );
  }

  Widget _appearanceSelector() {
    final selectedActor = SpriteAppearanceCatalog.actor(_appearance.actorId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('actorAppearanceSelector'),
          initialValue: selectedActor.id,
          decoration: const InputDecoration(
            labelText: 'Actor template',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final actor in SpriteAppearanceCatalog.actors)
              DropdownMenuItem(value: actor.id, child: Text(actor.label)),
          ],
          onChanged: (value) {
            if (value != null) _setActorAppearance(value);
          },
        ),
        const SizedBox(height: 10),
        const Text('Fitted hair'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final style in SpriteAppearanceCatalog.hairStyles)
              ChoiceChip(
                key: Key('hairStyle-${style.id}'),
                avatar: _backHairAsset(style).isNotEmpty
                    ? Image.asset(
                        _backHairAsset(style),
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      )
                    : const Icon(Icons.block, size: 20),
                label: Text(style.label),
                selected: _appearance.hairStyleId == style.id,
                onSelected: (_) => _setHairStyle(style.id),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('skinToneButton'),
                onPressed: _chooseSkinTone,
                icon: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _colorFromHex(_appearance.skinTone),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: const SizedBox.square(dimension: 20),
                ),
                label: Text('Skin  ${_appearance.skinTone}'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('resetSkinToneButton'),
              onPressed: _appearance.skinTone == selectedActor.defaultSkinTone
                  ? null
                  : () => _setSkinTone(selectedActor.defaultSkinTone),
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${selectedActor.label} appearance is shared by every pose and saved on this device.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _backHairSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final style in SpriteAppearanceCatalog.hairStyles)
          ChoiceChip(
            key: Key('backHair${style.label}'),
            showCheckmark: false,
            label: SizedBox(
              width: 62,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_backHairAsset(style).isNotEmpty)
                    Image.asset(
                      _backHairAsset(style),
                      width: 54,
                      height: 54,
                      fit: BoxFit.contain,
                    )
                  else
                    const SizedBox(
                      width: 54,
                      height: 54,
                      child: Icon(Icons.block),
                    ),
                  const SizedBox(height: 4),
                  Text(style.label),
                ],
              ),
            ),
            selected: _appearance.hairStyleId == style.id,
            onSelected: (_) => _setHairStyle(style.id),
          ),
      ],
    );
  }

  String _backHairAsset(SpriteHairStyle style) {
    return SpriteAppearanceCatalog.backHairAsset(_appearance.actorId, style.id);
  }

  void _setActorAppearance(String actorId) {
    final actor = SpriteAppearanceCatalog.actor(actorId);
    final appearance = _appearance.copyWith(actorId: actor.id);
    setState(() {
      _appearance = appearance;
      _pose = _applyAppearance(_pose!, appearance, resetFace: true);
    });
    _persistAppearance();
  }

  void _setHairStyle(String styleId) {
    if (_appearance.hairStyleId == styleId) return;
    final appearance = _appearance.copyWith(hairStyleId: styleId);
    setState(() {
      _appearance = appearance;
      _pose = _applyAppearance(_pose!, appearance);
    });
    _persistAppearance();
  }

  Future<void> _chooseSkinTone() async {
    var selected = _colorFromHex(_appearance.skinTone);
    var hsv = HSVColor.fromColor(selected);
    final controller = TextEditingController(text: _hexFromColor(selected));
    final chosen = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void update(HSVColor value) {
            hsv = value;
            selected = hsv.toColor();
            controller.text = _hexFromColor(selected);
            setDialogState(() {});
          }

          return AlertDialog(
            title: const Text('Choose skin color'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: selected,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SkinColorField(
                    color: selected,
                    onChanged: (value) {
                      selected = value;
                      hsv = HSVColor.fromColor(value);
                      controller.text = _hexFromColor(value);
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Hue'),
                  Slider(
                    value: hsv.hue,
                    min: 0,
                    max: 360,
                    onChanged: (value) => update(hsv.withHue(value)),
                  ),
                  TextField(
                    key: const Key('skinToneHexInput'),
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Hex color',
                      hintText: '#F2D2B6',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      selected = _colorFromHex(value);
                      hsv = HSVColor.fromColor(selected);
                      controller.text = _hexFromColor(selected);
                      setDialogState(() {});
                    },
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
                key: const Key('applySkinToneButton'),
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (chosen == null || !mounted) return;
    _setSkinTone(_hexFromColor(chosen));
  }

  void _setSkinTone(String skinTone) {
    final appearance = _appearance.copyWith(skinTone: skinTone);
    setState(() => _appearance = appearance);
    _persistAppearance();
  }

  SpriteRigPose _applyAppearance(
    SpriteRigPose pose,
    SpriteAppearanceSelection appearance, {
    SpriteRigDefinition? rig,
    bool resetFace = false,
  }) {
    final targetRig = rig ?? _rig;
    if (targetRig == null) return pose;
    final actor = SpriteAppearanceCatalog.actor(appearance.actorId);
    var result = pose;
    if (targetRig.partsById.containsKey('front_hair')) {
      result = result.withPartAsset(
        'front_hair',
        SpriteAppearanceCatalog.frontHairAsset(
          actor.id,
          appearance.frontHairId,
        ),
      );
    }
    if (targetRig.partsById.containsKey('back_hair')) {
      result = result.withPartAsset(
        'back_hair',
        SpriteAppearanceCatalog.backHairAsset(
          appearance.actorId,
          appearance.hairStyleId,
        ),
      );
    }
    for (final partId in const ['front_hair', 'back_hair']) {
      if (!targetRig.partsById.containsKey(partId)) continue;
      final fit = appearance.hairFitForPart(partId);
      result = result.update(
        partId,
        result
            .transformFor(partId)
            .copyWith(
              offsetX: fit.offsetX,
              offsetY: fit.offsetY,
              scale: fit.scale,
            ),
      );
    }
    if (_faceCatalog != null || rig != null) {
      final setId = resetFace
          ? 'neutral'
          : pose.faceSetId ?? pose.faceExpressionId;
      result = result.withFaceSelection(actor.faceProfileId, setId);
      if (resetFace) result = result.withFaceExpression('neutral');
    }
    return result;
  }

  void _persistAppearance() {
    _appearanceRepository.save(_appearance).catchError((_) {});
  }

  Color _colorFromHex(String source) {
    final cleaned = source.trim().replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null || cleaned.length != 6) {
      return const Color(0xFFF2EDEF);
    }
    return Color(0xFF000000 | value);
  }

  String _hexFromColor(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _transformControl({
    required String id,
    required String label,
    required double value,
    required double min,
    required double max,
    required VoidCallback onSliderStart,
    required ValueChanged<double> onChanged,
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChangeStart: (_) => onSliderStart(),
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 82,
                child: KeyedSubtree(
                  key: ValueKey('$id-$_selectedPartId-${value.round()}'),
                  child: TextFormField(
                    key: Key('${id}Input'),
                    initialValue: value.round().toString(),
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: suffix,
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (text) {
                      final next = double.tryParse(text);
                      if (next == null) return;
                      _rememberPose();
                      onChanged(next.clamp(min, max));
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save session'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                key: const Key('savePoseButton'),
                onPressed: _isBuiltIn ? null : _savePose,
                icon: const Icon(Icons.save_as_outlined),
                label: const Text('Save Pose'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fitView() => setState(() => _zoom = 1);

  void _changeZoom(double change) {
    setState(() => _zoom = (_zoom + change).clamp(0.6, 2));
  }

  void _update(SpritePartTransform transform) {
    final partId = _selectedPartId;
    if (partId == null) return;
    setState(() {
      _pose = _pose!.update(partId, transform);
      _captureHairFit(partId, transform);
    });
  }

  void _updatePart(String partId, SpritePartTransform transform) {
    final part = _rig!.partsById[partId]!;
    final hair = _isHairSlot(partId);
    final offsetLimit = hair ? 180.0 : 80.0;
    final safe = transform.copyWith(
      rotation: part.clampRotation(transform.rotation),
      offsetX: transform.offsetX.clamp(-offsetLimit, offsetLimit),
      offsetY: transform.offsetY.clamp(-offsetLimit, offsetLimit),
      scale: transform.scale.clamp(hair ? 0.3 : 0.5, hair ? 2.5 : 1.8),
    );
    setState(() {
      _pose = _pose!.update(partId, safe);
      _captureHairFit(partId, safe);
    });
  }

  void _setRotation(double value) {
    final part = _rig!.partsById[_selectedPartId!]!;
    _update(
      _pose!
          .transformFor(_selectedPartId!)
          .copyWith(rotation: part.clampRotation(value)),
    );
  }

  void _setHorizontalOffset(double value) {
    _update(_pose!.transformFor(_selectedPartId!).copyWith(offsetX: value));
  }

  void _setVerticalOffset(double value) {
    _update(_pose!.transformFor(_selectedPartId!).copyWith(offsetY: value));
  }

  void _setScale(double value) {
    final hair = _isHairSlot(_selectedPartId!);
    _update(
      _pose!
          .transformFor(_selectedPartId!)
          .copyWith(scale: value.clamp(hair ? 0.3 : 0.5, hair ? 2.5 : 1.8)),
    );
  }

  void _setFaceSelection(String profileId, String setId) {
    if (_pose!.faceProfileId == profileId && _pose!.faceSetId == setId) return;
    _rememberPose();
    var pose = _pose!.withFaceSelection(profileId, setId);
    if (profileId == 'default' &&
        _faceCatalog!.expressionsById.containsKey(setId)) {
      pose = pose.withFaceExpression(setId);
    }
    final actor = SpriteAppearanceCatalog.actorForProfile(profileId);
    final appearance = _appearance.copyWith(actorId: actor.id);
    pose = _applyAppearance(pose, appearance);
    setState(() {
      _pose = pose;
      _appearance = appearance;
    });
    _persistAppearance();
  }

  void _selectPart(String? partId) {
    if (_selectedPartId == partId) return;
    setState(() => _selectedPartId = partId);
  }

  void _moveSelected(double dx, double dy) {
    final partId = _selectedPartId;
    if (partId == null) return;
    final current = _pose!.transformFor(partId);
    final limit = _isHairSlot(partId) ? 180.0 : 80.0;
    _update(
      current.copyWith(
        offsetX: (current.offsetX + dx).clamp(-limit, limit),
        offsetY: (current.offsetY + dy).clamp(-limit, limit),
      ),
    );
  }

  void _dragSelected(DragUpdateDetails details, double scale) {
    if (_selectedPartId == null) return;
    if (!_dragHistoryRecorded) {
      _rememberPose();
      _dragHistoryRecorded = true;
    }
    _moveSelected(details.delta.dx / scale, details.delta.dy / scale);
  }

  int _effectiveLayer(SpriteRigPart part) {
    return SpriteLayerPolicy.effectiveLayer(part, _pose!.transformFor(part.id));
  }

  void _bringToFront() {
    if (SpriteLayerPolicy.isLocked(_selectedPartId!)) return;
    final top = _rig!.parts.map(_effectiveLayer).reduce(math.max);
    final current = _pose!.transformFor(_selectedPartId!);
    if ((current.layer ?? _rig!.partsById[_selectedPartId]!.z) == top) return;
    _rememberPose();
    _update(current.copyWith(layer: top + 1));
  }

  void _sendToBack() {
    if (SpriteLayerPolicy.isLocked(_selectedPartId!)) return;
    final back = _rig!.parts.map(_effectiveLayer).reduce(math.min);
    final current = _pose!.transformFor(_selectedPartId!);
    if ((current.layer ?? _rig!.partsById[_selectedPartId]!.z) == back) return;
    _rememberPose();
    _update(current.copyWith(layer: back - 1));
  }

  bool get _usesInjectedSource => widget.initialRig != null;

  Map<String, String> get _availableBuiltInLabels {
    if (!_usesInjectedSource) return _builtInLabels;
    return {
      for (final entry in _injectedPoses.entries)
        entry.key: entry.value.displayName,
    };
  }

  bool _isBuiltInPose(String id) {
    return _usesInjectedSource
        ? _injectedPoses.containsKey(id)
        : _builtInPoses.containsKey(id);
  }

  bool get _isBuiltIn => _isBuiltInPose(_selectedPoseId);

  String get _neutralPoseId {
    if (_usesInjectedSource) {
      return _injectedPoses.containsKey('neutral')
          ? 'neutral'
          : _injectedPoses.keys.first;
    }
    return 'neutral';
  }

  Future<SpriteRigPose> _loadBuiltInPose(String id) async {
    final saved = _savedDefaults[id];
    if (saved != null) {
      return _applyAppearance(_normalizePose(saved), _appearance);
    }
    if (_usesInjectedSource) return _normalizePose(_injectedPoses[id]!);
    return _applyAppearance(
      _normalizePose(await SpriteRigPose.load(_builtInPoses[id]!)),
      _appearance,
    );
  }

  bool get _isDirty =>
      _pose != null &&
      _initialPose != null &&
      _pose!.toPrettyJson() != _initialPose!.toPrettyJson();

  Iterable<String> _poseNames({String? excludeId}) sync* {
    for (final entry in _availableBuiltInLabels.entries) {
      if (entry.key != excludeId) yield entry.value;
    }
    for (final pose in _customPoses) {
      if (pose.id != excludeId) yield pose.displayName;
    }
  }

  Iterable<String> get _poseIds sync* {
    yield* _availableBuiltInLabels.keys;
    yield* _customPoses.map((pose) => pose.id);
  }

  void _replaceCustom(SpriteRigPose pose) {
    final index = _customPoses.indexWhere((value) => value.id == pose.id);
    if (index == -1) {
      _customPoses.add(pose);
    } else {
      _customPoses[index] = pose;
    }
    _customPoses.sort(
      (left, right) => left.displayName.compareTo(right.displayName),
    );
  }

  Future<String?> _askPoseName({
    required String title,
    String initialName = '',
    String? excludeId,
  }) async {
    final controller = TextEditingController(text: initialName);
    String? error;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            key: const Key('poseNameInput'),
            controller: controller,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: 'Pose name',
              errorText: error,
            ),
            onSubmitted: (_) {
              final message = SpritePoseRules.nameError(
                controller.text,
                _poseNames(excludeId: excludeId),
              );
              if (message == null) {
                Navigator.pop(context, controller.text.trim());
              } else {
                setDialogState(() => error = message);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirmPoseNameButton'),
              onPressed: () {
                final message = SpritePoseRules.nameError(
                  controller.text,
                  _poseNames(excludeId: excludeId),
                );
                if (message == null) {
                  Navigator.pop(context, controller.text.trim());
                } else {
                  setDialogState(() => error = message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    return name;
  }

  Future<bool> _confirmUnsavedChanges() async {
    if (!_isDirty) return true;
    final action = await showDialog<_UnsavedPoseAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save pose changes?'),
        content: Text(
          'Save changes to ${_pose!.displayName} before continuing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsavedPoseAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsavedPoseAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _UnsavedPoseAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (action == null || action == _UnsavedPoseAction.cancel) return false;
    if (action == _UnsavedPoseAction.save) {
      if (_isBuiltIn) {
        _save();
      } else {
        await _savePose();
      }
    } else {
      _discardCurrentChanges();
    }
    return true;
  }

  void _discardCurrentChanges() {
    final initial = _initialPose!;
    setState(() {
      _pose = initial;
      _captureHairFits(initial);
      if (!_isBuiltIn) _replaceCustom(initial);
      _undoStack.clear();
      _redoStack.clear();
    });
  }

  Future<void> _selectPose(String id) async {
    if (id == _selectedPoseId || !await _confirmUnsavedChanges()) return;

    late final SpriteRigPose storedPose;
    if (_isBuiltInPose(id)) {
      storedPose = await _loadBuiltInPose(id);
    } else {
      storedPose = _applyAppearance(
        _normalizePose(_customPoses.firstWhere((pose) => pose.id == id)),
        _appearance,
      );
    }
    final visiblePose = _applyAppearance(
      _sessionDrafts[id] ?? storedPose,
      _appearance,
    );
    if (!mounted) return;
    setState(() {
      _selectedPoseId = id;
      _pose = visiblePose;
      _initialPose = storedPose;
      _zoom = 1;
      _undoStack.clear();
      _redoStack.clear();
    });
  }

  Future<void> _newPose() async {
    if (!await _confirmUnsavedChanges()) return;
    final name = await _askPoseName(title: 'New Pose');
    if (name == null || !mounted) return;
    final id = SpritePoseRules.createId(name, _poseIds);
    final neutral = (await _loadBuiltInPose(
      _neutralPoseId,
    )).withMetadata(id: id, name: name);
    if (!mounted) return;
    setState(() {
      _replaceCustom(neutral);
      _selectedPoseId = id;
      _pose = neutral;
      _initialPose = neutral;
      _zoom = 1;
      _undoStack.clear();
      _redoStack.clear();
    });
    _message('$name created from Idle.');
  }

  Future<void> _renamePose() async {
    if (_isBuiltIn) return;
    final name = await _askPoseName(
      title: 'Rename Pose',
      initialName: _pose!.displayName,
      excludeId: _selectedPoseId,
    );
    if (name == null || name == _pose!.displayName || !mounted) return;
    _rememberPose();
    final renamed = _pose!.withMetadata(name: name);
    setState(() {
      _pose = renamed;
      _replaceCustom(renamed);
    });
  }

  Future<void> _duplicatePose() async {
    if (!await _confirmUnsavedChanges()) return;
    final name = await _askPoseName(
      title: 'Duplicate Pose',
      initialName: '${_pose!.displayName} Copy',
    );
    if (name == null || !mounted) return;
    final id = SpritePoseRules.createId(name, _poseIds);
    final copy = _normalizePose(_pose!).withMetadata(id: id, name: name);
    setState(() {
      _replaceCustom(copy);
      _selectedPoseId = id;
      _pose = copy;
      _initialPose = copy;
      _zoom = 1;
      _undoStack.clear();
      _redoStack.clear();
    });
    _message('$name created.');
  }

  Future<void> _deletePose() async {
    if (_isBuiltIn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete custom pose?'),
        content: Text(
          '${_pose!.displayName} will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmDeletePoseButton'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deletedId = _selectedPoseId;
    final deletedName = _pose!.displayName;
    if (_projectPoseIds.contains(deletedId)) {
      try {
        final response = await http.delete(
          Uri.parse('$_adminUrl/poses/$deletedId'),
        );
        if (response.statusCode != 200) throw Exception('Delete failed');
      } catch (_) {
        if (mounted) {
          _message('Local admin is offline, so the project pose was kept.');
        }
        return;
      }
    }
    if (_persistedCustomIds.contains(deletedId)) {
      await _poseRepository.delete(deletedId);
    }
    _sessionDrafts.remove(deletedId);
    _persistedCustomIds.remove(deletedId);
    _projectPoseIds.remove(deletedId);
    _customPoses.removeWhere((pose) => pose.id == deletedId);
    final neutral = await _loadBuiltInPose(_neutralPoseId);
    if (!mounted) return;
    setState(() {
      _selectedPoseId = _neutralPoseId;
      _pose = neutral;
      _initialPose = neutral;
      _undoStack.clear();
      _redoStack.clear();
    });
    _message('$deletedName deleted.');
  }

  void _reset() {
    if (_pose!.toPrettyJson() == _initialPose!.toPrettyJson()) return;
    _rememberPose();
    setState(() {
      _pose = _initialPose;
      _captureHairFits(_initialPose!);
    });
  }

  void _save() {
    final saved = _normalizePose(_pose!);
    setState(() {
      _sessionDrafts[_selectedPoseId] = saved;
      _pose = saved;
      _initialPose = saved;
    });
    _persistAppearance();
    _message('Pose saved for this session.');
  }

  void _loadSaved() {
    final saved = _sessionDrafts[_selectedPoseId];
    if (saved == null || _pose!.toPrettyJson() == saved.toPrettyJson()) return;
    _rememberPose();
    setState(() {
      _pose = _normalizePose(saved);
      _captureHairFits(_pose!);
    });
    _message('Saved pose loaded.');
  }

  Future<void> _savePose() async {
    if (_isBuiltIn) return;
    final saved = _normalizePose(_pose!);
    try {
      await _poseRepository.save(saved);
      await _appearanceRepository.save(_appearance);
      if (!mounted) return;
      setState(() {
        _pose = saved;
        _initialPose = saved;
        _replaceCustom(saved);
        _persistedCustomIds.add(saved.id);
      });
      _message('${saved.displayName} saved on this device.');
    } catch (_) {
      if (mounted) _message('The custom pose could not be saved.');
    }
  }

  void _rememberPose() {
    final current = _pose!;
    if (_undoStack.isNotEmpty &&
        _undoStack.last.toPrettyJson() == current.toPrettyJson()) {
      return;
    }
    _undoStack.add(current);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final current = _pose!;
    setState(() {
      _redoStack.add(current);
      _pose = _undoStack.removeLast();
      _captureHairFits(_pose!);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final current = _pose!;
    setState(() {
      _undoStack.add(current);
      _pose = _redoStack.removeLast();
      _captureHairFits(_pose!);
    });
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _pose!.toPrettyJson()));
    if (mounted) _message('Pose JSON copied.');
  }

  Future<void> _saveAsDefault() async {
    setState(() => _savingDefault = true);
    try {
      final normalizedPose = _normalizePose(_pose!);
      final selected = _rig!.partsById[_selectedPartId!]!;
      await _postProjectAppearance();

      if (_isHairSlot(selected.id)) {
        if (!mounted) return;
        setState(() {
          _pose = normalizedPose;
          _initialPose = normalizedPose;
        });
        _message(
          '${SpriteAppearanceCatalog.actor(_appearance.actorId).label} '
          '${selected.label.toLowerCase()} fit is now shared by every pose.',
        );
        return;
      }

      if (_isBuiltIn && !_usesInjectedSource && !selected.hasBone) {
        final attachment = normalizedPose.transformFor(selected.id);
        final updatedDefaults = <String, SpriteRigPose>{};
        for (final entry in _builtInPoses.entries) {
          final base = entry.key == _selectedPoseId
              ? normalizedPose
              : await SpriteRigPose.load(entry.value);
          var updated = base.update(selected.id, attachment);
          final selectedAsset = normalizedPose.partAssets[selected.id];
          if (selectedAsset != null) {
            updated = updated.withPartAsset(selected.id, selectedAsset);
          }
          updated = _normalizePose(updated);
          await _postProjectDefault(updated);
          updatedDefaults[entry.key] = updated;
        }
        if (!mounted) return;
        setState(() {
          _savedDefaults.addAll(updatedDefaults);
          _pose = updatedDefaults[_selectedPoseId];
          _initialPose = _pose;
        });
        _message(
          '${selected.label} is now the default attachment for every '
          'built-in pose.',
        );
        return;
      }

      await _postProjectDefault(normalizedPose);
      if (!mounted) return;
      setState(() {
        _pose = normalizedPose;
        _savedDefaults[_selectedPoseId] = normalizedPose;
        _initialPose = normalizedPose;
        if (!_isBuiltIn) {
          _replaceCustom(normalizedPose);
          _projectPoseIds.add(normalizedPose.id);
        }
      });
      _message('${normalizedPose.displayName} is now a project default pose.');
    } catch (_) {
      if (mounted) {
        _message('Local admin is offline. Start run_storytale.ps1 first.');
      }
    } finally {
      if (mounted) setState(() => _savingDefault = false);
    }
  }

  Future<void> _postProjectAppearance() async {
    final response = await http.post(
      Uri.parse('$_adminUrl/appearance'),
      headers: const {'Content-Type': 'application/json'},
      body: _appearance.toJsonString(),
    );
    if (response.statusCode != 200) throw Exception('Save failed');
    await _appearanceRepository.save(_appearance);
  }

  Future<void> _postProjectDefault(SpriteRigPose pose) async {
    final response = await http.post(
      Uri.parse('$_adminUrl/poses/${pose.id}'),
      headers: {'Content-Type': 'application/json'},
      body: pose.toPrettyJson(),
    );
    if (response.statusCode != 200) throw Exception('Save failed');
  }

  SpriteRigPose _normalizePose(SpriteRigPose pose) {
    final normalized = SpriteLayerPolicy.normalize(pose);
    final catalog = _faceCatalog;
    return catalog == null
        ? normalized
        : normalized.withFaceExpression(
            catalog.resolveId(normalized.faceExpressionId),
          );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _isHairSlot(String partId) {
    return partId == 'front_hair' || partId == 'back_hair';
  }

  void _captureHairFit(String partId, SpritePartTransform transform) {
    if (!_isHairSlot(partId)) return;
    _appearance = _appearance.withHairFitForPart(
      partId,
      SpriteHairFit(
        offsetX: transform.offsetX,
        offsetY: transform.offsetY,
        scale: transform.scale,
      ),
    );
  }

  void _captureHairFits(SpriteRigPose pose) {
    for (final partId in const ['front_hair', 'back_hair']) {
      if (_rig?.partsById.containsKey(partId) != true) continue;
      _captureHairFit(partId, pose.transformFor(partId));
    }
  }
}

enum _UnsavedPoseAction { save, discard, cancel }

class _SkinColorField extends StatelessWidget {
  const _SkinColorField({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    return AspectRatio(
      aspectRatio: 1.8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void select(Offset position) {
            final saturation = (position.dx / constraints.maxWidth).clamp(
              0.0,
              1.0,
            );
            final value =
                1 - (position.dy / constraints.maxHeight).clamp(0.0, 1.0);
            onChanged(
              HSVColor.fromAHSV(1, hsv.hue, saturation, value).toColor(),
            );
          }

          return GestureDetector(
            key: const Key('skinToneColorField'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => select(details.localPosition),
            onPanUpdate: (details) => select(details.localPosition),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.transparent],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(
                      (hsv.saturation * 2) - 1,
                      ((1 - hsv.value) * 2) - 1,
                    ),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
