import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

class SpriteRigDefinition {
  SpriteRigDefinition({
    required this.id,
    required this.canvasSize,
    required this.parts,
  }) : partsById = {for (final part in parts) part.id: part};

  final String id;
  final Size canvasSize;
  final List<SpriteRigPart> parts;
  final Map<String, SpriteRigPart> partsById;

  static Future<SpriteRigDefinition> load(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
    return SpriteRigDefinition.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  factory SpriteRigDefinition.fromJson(Map<String, dynamic> json) {
    return SpriteRigDefinition(
      id: json['id'] as String,
      canvasSize: _size(json['canvas'] as Map<String, dynamic>),
      parts: (json['parts'] as List<dynamic>)
          .map((item) => SpriteRigPart.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SpriteRigPart {
  const SpriteRigPart({
    required this.id,
    required this.label,
    required this.asset,
    required this.parentId,
    required this.position,
    required this.pivot,
    required this.size,
    required this.z,
    this.hasBone = true,
    this.rotationRange,
  });

  final String id;
  final String label;
  final String asset;
  final String? parentId;
  final Offset position;
  final Offset pivot;
  final Size size;
  final int z;
  final bool hasBone;
  final SpriteRotationRange? rotationRange;

  Offset get imagePivot => pivot - position;

  factory SpriteRigPart.fromJson(Map<String, dynamic> json) {
    return SpriteRigPart(
      id: json['id'] as String,
      label: json['label'] as String,
      asset: json['asset'] as String,
      parentId: json['parent'] as String?,
      position: _offset(json['position'] as Map<String, dynamic>),
      pivot: _offset(json['pivot'] as Map<String, dynamic>),
      size: _size(json['size'] as Map<String, dynamic>),
      z: (json['z'] as num).toInt(),
      hasBone: json['bone'] as bool? ?? true,
      rotationRange: json['rotationRange'] == null
          ? null
          : SpriteRotationRange.fromJson(
              json['rotationRange'] as Map<String, dynamic>,
            ),
    );
  }

  double clampRotation(double value) => rotationRange?.clamp(value) ?? value;
}

class SpriteRotationRange {
  const SpriteRotationRange({required this.min, required this.max});

  final double min;
  final double max;

  factory SpriteRotationRange.fromJson(Map<String, dynamic> json) {
    return SpriteRotationRange(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  double clamp(double value) => value.clamp(min, max).toDouble();
}

class SpriteRigPose {
  const SpriteRigPose({
    required this.id,
    this.name = '',
    this.rigId = 'humanoid_v1',
    this.faceExpressionId = 'neutral',
    this.faceProfileId,
    this.faceSetId,
    this.layerPolicyVersion = 1,
    this.parts = const {},
  });

  final String id;
  final String name;
  final String rigId;
  final String faceExpressionId;
  final String? faceProfileId;
  final String? faceSetId;
  final int layerPolicyVersion;
  final Map<String, SpritePartTransform> parts;

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    return id
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static Future<SpriteRigPose> load(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
    return SpriteRigPose.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  factory SpriteRigPose.fromJson(Map<String, dynamic> json) {
    final values = json['parts'] as Map<String, dynamic>? ?? const {};
    return SpriteRigPose(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      rigId: json['rigId'] as String? ?? 'humanoid_v1',
      faceExpressionId: json['faceExpressionId'] as String? ?? 'neutral',
      faceProfileId: json['faceProfileId'] as String?,
      faceSetId: json['faceSetId'] as String?,
      layerPolicyVersion: (json['layerPolicyVersion'] as num?)?.toInt() ?? 1,
      parts: values.map(
        (id, value) => MapEntry(
          id,
          SpritePartTransform.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  SpritePartTransform transformFor(String partId) {
    return parts[partId] ?? const SpritePartTransform();
  }

  SpriteRigPose update(String partId, SpritePartTransform transform) {
    return SpriteRigPose(
      id: id,
      name: name,
      rigId: rigId,
      faceExpressionId: faceExpressionId,
      faceProfileId: faceProfileId,
      faceSetId: faceSetId,
      layerPolicyVersion: layerPolicyVersion,
      parts: {...parts, partId: transform},
    );
  }

  SpriteRigPose withFaceExpression(String expressionId) {
    return SpriteRigPose(
      id: id,
      name: name,
      rigId: rigId,
      faceExpressionId: expressionId,
      faceProfileId: faceProfileId,
      faceSetId: faceSetId,
      layerPolicyVersion: layerPolicyVersion,
      parts: parts,
    );
  }

  SpriteRigPose withFaceSelection(String profileId, String setId) {
    return SpriteRigPose(
      id: id,
      name: name,
      rigId: rigId,
      faceExpressionId: faceExpressionId,
      faceProfileId: profileId,
      faceSetId: setId,
      layerPolicyVersion: layerPolicyVersion,
      parts: parts,
    );
  }

  SpriteRigPose withMetadata({String? id, String? name}) {
    return SpriteRigPose(
      id: id ?? this.id,
      name: name ?? this.name,
      rigId: rigId,
      faceExpressionId: faceExpressionId,
      faceProfileId: faceProfileId,
      faceSetId: faceSetId,
      layerPolicyVersion: layerPolicyVersion,
      parts: parts,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': displayName,
    'rigId': rigId,
    'faceExpressionId': faceExpressionId,
    if (faceProfileId != null) 'faceProfileId': faceProfileId,
    if (faceSetId != null) 'faceSetId': faceSetId,
    'layerPolicyVersion': layerPolicyVersion,
    'parts': parts.map((id, transform) => MapEntry(id, transform.toJson())),
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class SpritePartTransform {
  const SpritePartTransform({
    this.rotation = 0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
    this.layer,
  });

  final double rotation;
  final double offsetX;
  final double offsetY;
  final double scale;
  final int? layer;

  factory SpritePartTransform.fromJson(Map<String, dynamic> json) {
    return SpritePartTransform(
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      offsetX: (json['x'] as num?)?.toDouble() ?? 0,
      offsetY: (json['y'] as num?)?.toDouble() ?? 0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      layer: (json['layer'] as num?)?.toInt(),
    );
  }

  SpritePartTransform copyWith({
    double? rotation,
    double? offsetX,
    double? offsetY,
    double? scale,
    int? layer,
  }) {
    return SpritePartTransform(
      rotation: rotation ?? this.rotation,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      layer: layer ?? this.layer,
    );
  }

  Map<String, dynamic> toJson() => {
    'rotation': rotation,
    'x': offsetX,
    'y': offsetY,
    if (scale != 1) 'scale': scale,
    if (layer != null) 'layer': layer,
  };

  SpritePartTransform withoutLayer() {
    return SpritePartTransform(
      rotation: rotation,
      offsetX: offsetX,
      offsetY: offsetY,
      scale: scale,
    );
  }
}

class SpriteLayerPolicy {
  const SpriteLayerPolicy._();

  static const lockedBodyParts = {
    'lower_leg_left',
    'upper_leg_left',
    'lower_leg_right',
    'upper_leg_right',
    'lower_arm_left',
    'upper_arm_left',
    'torso',
    'lower_arm_right',
    'upper_arm_right',
    'head',
  };

  static bool isLocked(String partId) => lockedBodyParts.contains(partId);

  static int effectiveLayer(SpriteRigPart part, SpritePartTransform transform) {
    return isLocked(part.id) ? part.z : transform.layer ?? part.z;
  }

  static SpriteRigPose normalize(SpriteRigPose pose) {
    return SpriteRigPose(
      id: pose.id,
      name: pose.name,
      rigId: pose.rigId,
      faceExpressionId: pose.faceExpressionId,
      faceProfileId: pose.faceProfileId,
      faceSetId: pose.faceSetId,
      layerPolicyVersion: pose.layerPolicyVersion,
      parts: pose.parts.map(
        (id, transform) =>
            MapEntry(id, isLocked(id) ? transform.withoutLayer() : transform),
      ),
    );
  }
}

class SpritePartWorldTransform {
  const SpritePartWorldTransform({required this.pivot, required this.rotation});

  final Offset pivot;
  final double rotation;
}

class SpriteRigCalculator {
  const SpriteRigCalculator._();

  static Map<String, SpritePartWorldTransform> calculate(
    SpriteRigDefinition rig,
    SpriteRigPose pose,
  ) {
    final result = <String, SpritePartWorldTransform>{};

    SpritePartWorldTransform resolve(SpriteRigPart part) {
      final cached = result[part.id];
      if (cached != null) return cached;

      final transform = pose.transformFor(part.id);
      final localRotation = transform.rotation * math.pi / 180;
      final parentId = part.parentId;
      late final SpritePartWorldTransform world;

      if (parentId == null) {
        world = SpritePartWorldTransform(
          pivot: part.pivot + Offset(transform.offsetX, transform.offsetY),
          rotation: localRotation,
        );
      } else {
        final parent = rig.partsById[parentId];
        if (parent == null) {
          throw FormatException('Missing parent $parentId for ${part.id}.');
        }
        final parentWorld = resolve(parent);
        final restOffset =
            part.pivot -
            parent.pivot +
            Offset(transform.offsetX, transform.offsetY);
        world = SpritePartWorldTransform(
          pivot: parentWorld.pivot + rotate(restOffset, parentWorld.rotation),
          rotation: parentWorld.rotation + localRotation,
        );
      }

      result[part.id] = world;
      return world;
    }

    for (final part in rig.parts) {
      resolve(part);
    }
    return result;
  }

  static Offset rotate(Offset value, double radians) {
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    return Offset(
      value.dx * cosine - value.dy * sine,
      value.dx * sine + value.dy * cosine,
    );
  }
}

class SpriteBone {
  const SpriteBone({
    required this.partId,
    required this.start,
    required this.end,
    required this.isRoot,
  });

  final String partId;
  final Offset start;
  final Offset end;
  final bool isRoot;
}

class SpriteBoneCalculator {
  const SpriteBoneCalculator._();

  static List<SpriteBone> calculate(
    SpriteRigDefinition rig,
    SpriteRigPose pose,
  ) {
    final transforms = SpriteRigCalculator.calculate(rig, pose);
    final firstChild = <String, SpriteRigPart>{};
    for (final part in rig.parts.where((part) => part.hasBone)) {
      final parentId = part.parentId;
      if (parentId != null && rig.partsById[parentId]?.hasBone == true) {
        firstChild.putIfAbsent(parentId, () => part);
      }
    }

    return [
      for (final part in rig.parts.where((part) => part.hasBone))
        _boneFor(part, firstChild[part.id], transforms),
    ];
  }

  static SpriteBone _boneFor(
    SpriteRigPart part,
    SpriteRigPart? child,
    Map<String, SpritePartWorldTransform> transforms,
  ) {
    final world = transforms[part.id]!;
    if (part.parentId == null) {
      return SpriteBone(
        partId: part.id,
        start: world.pivot,
        end: world.pivot,
        isRoot: true,
      );
    }

    final end = child == null
        ? world.pivot +
              SpriteRigCalculator.rotate(_terminalOffset(part), world.rotation)
        : transforms[child.id]!.pivot;
    return SpriteBone(
      partId: part.id,
      start: world.pivot,
      end: end,
      isRoot: false,
    );
  }

  static Offset _terminalOffset(SpriteRigPart part) {
    final pivot = part.imagePivot;
    final candidates = [
      Offset(part.size.width / 2, 0),
      Offset(part.size.width / 2, part.size.height),
      Offset(0, part.size.height / 2),
      Offset(part.size.width, part.size.height / 2),
    ];
    return candidates
        .map((point) => point - pivot)
        .reduce(
          (best, value) =>
              value.distanceSquared > best.distanceSquared ? value : best,
        );
  }

  static double rotationFromDrag({
    required double initialRotation,
    required Offset pivot,
    required Offset initialPointer,
    required Offset pointer,
    SpriteRotationRange? range,
  }) {
    final start = initialPointer - pivot;
    final current = pointer - pivot;
    if (start.distanceSquared < 1 || current.distanceSquared < 1) {
      return initialRotation;
    }

    var delta =
        math.atan2(current.dy, current.dx) - math.atan2(start.dy, start.dx);
    while (delta > math.pi) {
      delta -= math.pi * 2;
    }
    while (delta < -math.pi) {
      delta += math.pi * 2;
    }
    final rotation = initialRotation + delta * 180 / math.pi;
    return range?.clamp(rotation) ?? rotation;
  }
}

Offset _offset(Map<String, dynamic> json) {
  return Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
}

Size _size(Map<String, dynamic> json) {
  return Size(
    (json['width'] as num).toDouble(),
    (json['height'] as num).toDouble(),
  );
}
