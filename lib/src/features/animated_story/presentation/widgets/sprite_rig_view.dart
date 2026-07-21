import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/sprite_face_catalog.dart';
import '../../data/sprite_rig.dart';

typedef SpritePartTransformChanged =
    void Function(String partId, SpritePartTransform transform);

class SpriteRigView extends StatelessWidget {
  const SpriteRigView({
    required this.rig,
    required this.pose,
    this.faceCatalog,
    this.showAnchors = false,
    this.showHitboxes = false,
    this.showBones = false,
    this.boneMode = false,
    this.selectedPartId,
    this.onPartSelected,
    this.onBoneDragStarted,
    this.onPartTransformChanged,
    super.key,
  });

  final SpriteRigDefinition rig;
  final SpriteRigPose pose;
  final SpriteFaceCatalog? faceCatalog;
  final bool showAnchors;
  final bool showHitboxes;
  final bool showBones;
  final bool boneMode;
  final String? selectedPartId;
  final ValueChanged<String>? onPartSelected;
  final VoidCallback? onBoneDragStarted;
  final SpritePartTransformChanged? onPartTransformChanged;

  @override
  Widget build(BuildContext context) {
    final transforms = SpriteRigCalculator.calculate(rig, pose);
    final parts = [...rig.parts]..sort(_compareLayers);
    final bones = showBones || boneMode
        ? SpriteBoneCalculator.calculate(rig, pose)
        : const <SpriteBone>[];

    return SizedBox(
      width: rig.canvasSize.width,
      height: rig.canvasSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final part in parts)
            _visualPart(context, part, transforms[part.id]!),
          if (onPartSelected != null)
            Positioned.fill(
              child: _SpriteRigInteractionLayer(
                rig: rig,
                pose: pose,
                transforms: transforms,
                bones: bones,
                showBones: showBones,
                boneMode: boneMode,
                selectedPartId: selectedPartId,
                onPartSelected: onPartSelected!,
                onBoneDragStarted: onBoneDragStarted,
                onPartTransformChanged: onPartTransformChanged,
              ),
            ),
          if (showBones || boneMode)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BonePainter(
                    rig: rig,
                    pose: pose,
                    bones: bones,
                    selectedPartId: selectedPartId,
                    primary: Theme.of(context).colorScheme.primary,
                    muted: Theme.of(context).colorScheme.outline,
                    warning: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          if (showAnchors)
            for (final part in parts) _anchor(part, transforms[part.id]!.pivot),
        ],
      ),
    );
  }

  Widget _visualPart(
    BuildContext context,
    SpriteRigPart part,
    SpritePartWorldTransform transform,
  ) {
    final imagePivot = part.imagePivot;
    final alignment = Alignment(
      imagePivot.dx / part.size.width * 2 - 1,
      imagePivot.dy / part.size.height * 2 - 1,
    );

    return Positioned(
      left: transform.pivot.dx - imagePivot.dx,
      top: transform.pivot.dy - imagePivot.dy,
      width: part.size.width,
      height: part.size.height,
      child: Transform.rotate(
        angle: transform.rotation,
        alignment: alignment,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _partArtwork(context, part, selectedPartId == part.id),
                if (showHitboxes)
                  Opacity(
                    opacity: selectedPartId == part.id ? 0.34 : 0.18,
                    child: _image(
                      part,
                      color: selectedPartId == part.id
                          ? Theme.of(context).colorScheme.primary
                          : Colors.cyan,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _compareLayers(SpriteRigPart a, SpriteRigPart b) {
    final aLayer = SpriteLayerPolicy.effectiveLayer(a, pose.transformFor(a.id));
    final bLayer = SpriteLayerPolicy.effectiveLayer(b, pose.transformFor(b.id));
    final order = aLayer.compareTo(bLayer);
    return order != 0 ? order : a.z.compareTo(b.z);
  }

  Widget _partArtwork(BuildContext context, SpriteRigPart part, bool selected) {
    final catalog = faceCatalog;
    return Stack(
      fit: StackFit.expand,
      children: [
        _partImage(context, part, selected),
        if (catalog != null && part.id == catalog.headPartId)
          Image.asset(
            catalog.expressionFor(pose.faceExpressionId).asset,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
      ],
    );
  }

  Widget _partImage(BuildContext context, SpriteRigPart part, bool selected) {
    if (!selected) return _image(part);

    const distance = 5.0;
    const offsets = [
      Offset(-distance, 0),
      Offset(distance, 0),
      Offset(0, -distance),
      Offset(0, distance),
      Offset(-distance, -distance),
      Offset(distance, -distance),
      Offset(-distance, distance),
      Offset(distance, distance),
    ];
    final color = Theme.of(context).colorScheme.primary;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        for (final offset in offsets)
          Transform.translate(
            offset: offset,
            child: _image(part, color: color),
          ),
        _image(part),
      ],
    );
  }

  Widget _image(SpriteRigPart part, {Color? color}) {
    return Image.asset(
      part.asset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
    );
  }

  Widget _anchor(SpriteRigPart part, Offset pivot) {
    final selected = selectedPartId == part.id;
    final size = selected ? 18.0 : 12.0;
    return Positioned(
      left: pivot.dx - size / 2,
      top: pivot.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

class _SpriteRigInteractionLayer extends StatefulWidget {
  const _SpriteRigInteractionLayer({
    required this.rig,
    required this.pose,
    required this.transforms,
    required this.bones,
    required this.showBones,
    required this.boneMode,
    required this.selectedPartId,
    required this.onPartSelected,
    this.onBoneDragStarted,
    this.onPartTransformChanged,
  });

  final SpriteRigDefinition rig;
  final SpriteRigPose pose;
  final Map<String, SpritePartWorldTransform> transforms;
  final List<SpriteBone> bones;
  final bool showBones;
  final bool boneMode;
  final String? selectedPartId;
  final ValueChanged<String> onPartSelected;
  final VoidCallback? onBoneDragStarted;
  final SpritePartTransformChanged? onPartTransformChanged;

  @override
  State<_SpriteRigInteractionLayer> createState() =>
      _SpriteRigInteractionLayerState();
}

class _SpriteRigInteractionLayerState
    extends State<_SpriteRigInteractionLayer> {
  Future<Map<String, _AlphaMask>>? _masks;
  _BoneDrag? _boneDrag;
  bool _boneHistoryStarted = false;

  @override
  void didUpdateWidget(covariant _SpriteRigInteractionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rig.id != widget.rig.id) _masks = null;
  }

  Future<Map<String, _AlphaMask>> _loadMasks() async {
    final entries = await Future.wait(
      widget.rig.parts.map(
        (part) async => MapEntry(part.id, await _AlphaMask.load(part.asset)),
      ),
    );
    return Map.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sprite body-part selector',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerEnd,
        onPointerCancel: _pointerEnd,
      ),
    );
  }

  void _pointerDown(PointerDownEvent event) {
    if (widget.showBones || widget.boneMode) {
      final bone = _hitBone(event.localPosition);
      if (bone != null) {
        widget.onPartSelected(bone.partId);
        if (widget.boneMode && widget.onPartTransformChanged != null) {
          _boneHistoryStarted = false;
          _boneDrag = _BoneDrag(
            pointer: event.pointer,
            bone: bone,
            initialPointer: event.localPosition,
            initialTransform: widget.pose.transformFor(bone.partId),
          );
        }
        return;
      }
    }
    _handlePointer(event.localPosition);
  }

  void _pointerMove(PointerMoveEvent event) {
    final drag = _boneDrag;
    if (drag == null || drag.pointer != event.pointer) return;
    if (!_boneHistoryStarted) {
      widget.onBoneDragStarted?.call();
      _boneHistoryStarted = true;
    }

    final part = widget.rig.partsById[drag.bone.partId]!;
    late final SpritePartTransform transform;
    if (drag.bone.isRoot) {
      final delta = event.localPosition - drag.initialPointer;
      transform = drag.initialTransform.copyWith(
        offsetX: (drag.initialTransform.offsetX + delta.dx).clamp(-80, 80),
        offsetY: (drag.initialTransform.offsetY + delta.dy).clamp(-80, 80),
      );
    } else {
      transform = drag.initialTransform.copyWith(
        rotation: SpriteBoneCalculator.rotationFromDrag(
          initialRotation: drag.initialTransform.rotation,
          pivot: drag.bone.start,
          initialPointer: drag.initialPointer,
          pointer: event.localPosition,
          range: part.rotationRange,
        ),
      );
    }
    widget.onPartTransformChanged!(part.id, transform);
  }

  void _pointerEnd(PointerEvent event) {
    if (_boneDrag?.pointer != event.pointer) return;
    _boneDrag = null;
    _boneHistoryStarted = false;
  }

  SpriteBone? _hitBone(Offset point) {
    SpriteBone? closest;
    var closestDistance = double.infinity;
    for (final bone in widget.bones) {
      final distance = (point - bone.end).distance;
      if (distance < closestDistance) {
        closest = bone;
        closestDistance = distance;
      }
    }
    if (closestDistance <= 34) return closest;

    closest = null;
    closestDistance = double.infinity;
    for (final bone in widget.bones.where((bone) => !bone.isRoot)) {
      final distance = _distanceToSegment(point, bone.start, bone.end);
      if (distance < closestDistance) {
        closest = bone;
        closestDistance = distance;
      }
    }
    return closestDistance <= 18 ? closest : null;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    if (segment.distanceSquared == 0) return (point - start).distance;
    final fromStart = point - start;
    final progress =
        ((fromStart.dx * segment.dx + fromStart.dy * segment.dy) /
                segment.distanceSquared)
            .clamp(0.0, 1.0);
    return (point - (start + segment * progress)).distance;
  }

  Future<void> _handlePointer(Offset point) async {
    final masks = await (_masks ??= _loadMasks());
    if (mounted) _select(point, masks);
  }

  void _select(Offset point, Map<String, _AlphaMask> masks) {
    final parts = [...widget.rig.parts]..sort(_compareHitPriority);
    for (final tolerance in const [0.0, 8.0]) {
      for (final part in parts.reversed) {
        final local = _toPartSpace(point, part, widget.transforms[part.id]!);
        final hit = tolerance == 0
            ? masks[part.id]!.isVisible(local, part.size)
            : masks[part.id]!.isVisibleNear(local, part.size, tolerance);
        if (hit) {
          widget.onPartSelected(part.id);
          return;
        }
      }
    }
  }

  Offset _toPartSpace(
    Offset point,
    SpriteRigPart part,
    SpritePartWorldTransform transform,
  ) {
    final delta = point - transform.pivot;
    final cosine = math.cos(-transform.rotation);
    final sine = math.sin(-transform.rotation);
    return part.imagePivot +
        Offset(
          delta.dx * cosine - delta.dy * sine,
          delta.dx * sine + delta.dy * cosine,
        );
  }

  int _compareHitPriority(SpriteRigPart a, SpriteRigPart b) {
    if (a.id == 'torso') return b.id == 'torso' ? 0 : -1;
    if (b.id == 'torso') return 1;
    final aLayer = SpriteLayerPolicy.effectiveLayer(
      a,
      widget.pose.transformFor(a.id),
    );
    final bLayer = SpriteLayerPolicy.effectiveLayer(
      b,
      widget.pose.transformFor(b.id),
    );
    return aLayer.compareTo(bLayer);
  }
}

class _BoneDrag {
  const _BoneDrag({
    required this.pointer,
    required this.bone,
    required this.initialPointer,
    required this.initialTransform,
  });

  final int pointer;
  final SpriteBone bone;
  final Offset initialPointer;
  final SpritePartTransform initialTransform;
}

class _BonePainter extends CustomPainter {
  const _BonePainter({
    required this.rig,
    required this.pose,
    required this.bones,
    required this.selectedPartId,
    required this.primary,
    required this.muted,
    required this.warning,
  });

  final SpriteRigDefinition rig;
  final SpriteRigPose pose;
  final List<SpriteBone> bones;
  final String? selectedPartId;
  final Color primary;
  final Color muted;
  final Color warning;

  @override
  void paint(Canvas canvas, Size size) {
    for (final bone in bones) {
      final selected = bone.partId == selectedPartId;
      final part = rig.partsById[bone.partId]!;
      final range = part.rotationRange;
      final rotation = pose.transformFor(part.id).rotation;
      final atLimit =
          range != null &&
          ((rotation - range.min).abs() < 0.5 ||
              (rotation - range.max).abs() < 0.5);
      final color = atLimit && selected
          ? warning
          : selected
          ? primary
          : muted.withAlpha(190);
      final line = Paint()
        ..color = color
        ..strokeWidth = selected ? 8 : 5
        ..strokeCap = StrokeCap.round;

      if (!bone.isRoot) canvas.drawLine(bone.start, bone.end, line);
      _joint(canvas, bone.start, color, selected ? 14 : 10);
      _joint(canvas, bone.end, color, selected ? 22 : 16);
      if (bone.isRoot) {
        canvas.drawLine(
          bone.end - const Offset(22, 0),
          bone.end + const Offset(22, 0),
          line,
        );
        canvas.drawLine(
          bone.end - const Offset(0, 22),
          bone.end + const Offset(0, 22),
          line,
        );
      }
    }
  }

  void _joint(Canvas canvas, Offset center, Color color, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius - 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BonePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.selectedPartId != selectedPartId ||
        oldDelegate.bones != bones ||
        oldDelegate.primary != primary ||
        oldDelegate.muted != muted ||
        oldDelegate.warning != warning;
  }
}

class _AlphaMask {
  const _AlphaMask(this.width, this.height, this.rgba);

  static final _cache = <String, Future<_AlphaMask>>{};

  final int width;
  final int height;
  final Uint8List rgba;

  static Future<_AlphaMask> load(String asset) {
    return _cache.putIfAbsent(asset, () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) throw StateError('Could not read $asset pixels.');
      final mask = _AlphaMask(
        image.width,
        image.height,
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      image.dispose();
      codec.dispose();
      return mask;
    });
  }

  bool isVisible(Offset position, Size size) {
    final x = (position.dx / size.width * width).floor();
    final y = (position.dy / size.height * height).floor();
    if (x < 0 || x >= width || y < 0 || y >= height) return false;
    return rgba[(y * width + x) * 4 + 3] > 16;
  }

  bool isVisibleNear(Offset position, Size size, double tolerance) {
    if (position.dx < -tolerance ||
        position.dy < -tolerance ||
        position.dx > size.width + tolerance ||
        position.dy > size.height + tolerance) {
      return false;
    }
    final centerX = (position.dx / size.width * width).round();
    final centerY = (position.dy / size.height * height).round();
    final radiusX = math.max(1, (tolerance / size.width * width).ceil());
    final radiusY = math.max(1, (tolerance / size.height * height).ceil());
    for (var y = centerY - radiusY; y <= centerY + radiusY; y++) {
      if (y < 0 || y >= height) continue;
      for (var x = centerX - radiusX; x <= centerX + radiusX; x++) {
        if (x < 0 || x >= width) continue;
        if (rgba[(y * width + x) * 4 + 3] > 16) return true;
      }
    }
    return false;
  }
}
