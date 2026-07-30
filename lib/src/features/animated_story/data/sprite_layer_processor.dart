import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as image;

import 'sprite_rig.dart';

class SpriteLayers {
  const SpriteLayers({
    required this.source,
    required this.head,
    required this.body,
    required this.rejoined,
  });

  final Uint8List source;
  final Uint8List head;
  final Uint8List body;
  final Uint8List rejoined;
}

class SpriteRigLayers {
  const SpriteRigLayers({
    required this.source,
    required this.parts,
    required this.rejoined,
    required this.width,
    required this.height,
    required this.partFrames,
    required this.validation,
  });

  final Uint8List source;
  final Map<String, Uint8List> parts;
  final Uint8List rejoined;
  final int width;
  final int height;
  final Map<String, SpriteRigPartFrame> partFrames;
  final SpriteRigValidation validation;

  SpriteRigDefinition toRigDefinition({
    required String rigId,
    required Map<String, String> partAssetIds,
  }) {
    return SpriteRigDefinition(
      id: rigId,
      canvasSize: Size(width.toDouble(), height.toDouble()),
      parts: [
        for (final id in SpriteLayerProcessor.rigPartIds)
          partFrames[id]!.toRigPart(partAssetIds[id] ?? '$rigId.$id'),
      ],
    );
  }
}

class SpriteRigPartFrame {
  const SpriteRigPartFrame({
    required this.id,
    required this.label,
    required this.parentId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pivotX,
    required this.pivotY,
    required this.z,
    required this.rotationMin,
    required this.rotationMax,
  });

  final String id;
  final String label;
  final String? parentId;
  final int x;
  final int y;
  final int width;
  final int height;
  final double pivotX;
  final double pivotY;
  final int z;
  final double rotationMin;
  final double rotationMax;

  int get right => x + width;
  int get bottom => y + height;

  bool contains(int px, int py) =>
      px >= x && px < right && py >= y && py < bottom;

  SpriteRigPartFrame withBounds({
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    return SpriteRigPartFrame(
      id: id,
      label: label,
      parentId: parentId,
      x: x,
      y: y,
      width: width,
      height: height,
      pivotX: pivotX,
      pivotY: pivotY,
      z: z,
      rotationMin: rotationMin,
      rotationMax: rotationMax,
    );
  }

  SpriteRigPart toRigPart(String assetId) {
    return SpriteRigPart(
      id: id,
      label: label,
      asset: assetId,
      parentId: parentId,
      position: Offset(x.toDouble(), y.toDouble()),
      pivot: Offset(pivotX, pivotY),
      size: Size(width.toDouble(), height.toDouble()),
      z: z,
      rotationRange: SpriteRotationRange(min: rotationMin, max: rotationMax),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (parentId != null) 'parent': parentId,
    'position': {'x': x, 'y': y},
    'pivot': {'x': pivotX, 'y': pivotY},
    'size': {'width': width, 'height': height},
    'rotationRange': {'min': rotationMin, 'max': rotationMax},
    'z': z,
  };

  factory SpriteRigPartFrame.fromJson(Map<String, dynamic> json) {
    final position = Map<String, dynamic>.from(
      json['position'] as Map? ?? const {},
    );
    final pivot = Map<String, dynamic>.from(json['pivot'] as Map? ?? const {});
    final size = Map<String, dynamic>.from(json['size'] as Map? ?? const {});
    final rotationRange = Map<String, dynamic>.from(
      json['rotationRange'] as Map? ?? const {},
    );
    return SpriteRigPartFrame(
      id: json['id'] as String,
      label: json['label'] as String? ?? json['id'] as String,
      parentId: json['parent'] as String?,
      x: (position['x'] as num?)?.round() ?? 0,
      y: (position['y'] as num?)?.round() ?? 0,
      width: (size['width'] as num?)?.round() ?? 1,
      height: (size['height'] as num?)?.round() ?? 1,
      pivotX: (pivot['x'] as num?)?.toDouble() ?? 0,
      pivotY: (pivot['y'] as num?)?.toDouble() ?? 0,
      z: (json['z'] as num?)?.toInt() ?? 0,
      rotationMin: (rotationRange['min'] as num?)?.toDouble() ?? -180,
      rotationMax: (rotationRange['max'] as num?)?.toDouble() ?? 180,
    );
  }
}

class SpriteRigValidation {
  const SpriteRigValidation({
    required this.errors,
    required this.visiblePixelsByPart,
    required this.neutralReassemblyMatches,
  });

  final List<String> errors;
  final Map<String, int> visiblePixelsByPart;
  final bool neutralReassemblyMatches;

  bool get isValid => errors.isEmpty && neutralReassemblyMatches;

  String? get errorMessage => errors.isEmpty ? null : errors.join(' ');
}

class SpriteLayerProcessor {
  const SpriteLayerProcessor();

  static const canonicalCanvasWidth = 1103;
  static const canonicalCanvasHeight = 1172;

  static const rigPartIds = [
    'head',
    'torso',
    'upper_arm_left',
    'lower_arm_left',
    'upper_arm_right',
    'lower_arm_right',
    'upper_leg_left',
    'lower_leg_left',
    'upper_leg_right',
    'lower_leg_right',
  ];

  static const legacyPartIdAliases = {
    'left_upper_arm': 'upper_arm_left',
    'left_lower_arm': 'lower_arm_left',
    'right_upper_arm': 'upper_arm_right',
    'right_lower_arm': 'lower_arm_right',
    'left_upper_leg': 'upper_leg_left',
    'left_lower_leg': 'lower_leg_left',
    'right_upper_leg': 'upper_leg_right',
    'right_lower_leg': 'lower_leg_right',
  };

  static String canonicalPartId(String id) => legacyPartIdAliases[id] ?? id;

  static const canonicalPartFrames = <String, SpriteRigPartFrame>{
    'head': SpriteRigPartFrame(
      id: 'head',
      label: 'Head',
      parentId: 'torso',
      x: 373,
      y: 182,
      width: 357,
      height: 367,
      pivotX: 552.88,
      pivotY: 544.54,
      z: 40,
      rotationMin: -45,
      rotationMax: 45,
    ),
    'torso': SpriteRigPartFrame(
      id: 'torso',
      label: 'Torso',
      parentId: null,
      x: 474,
      y: 541,
      width: 165,
      height: 234,
      pivotX: 558.45,
      pivotY: 756.28,
      z: 20,
      rotationMin: -30,
      rotationMax: 30,
    ),
    'upper_arm_left': SpriteRigPartFrame(
      id: 'upper_arm_left',
      label: 'Left upper arm',
      parentId: 'torso',
      x: 570,
      y: 554,
      width: 78,
      height: 128,
      pivotX: 589.09,
      pivotY: 578.78,
      z: 11,
      rotationMin: -150,
      rotationMax: 150,
    ),
    'lower_arm_left': SpriteRigPartFrame(
      id: 'lower_arm_left',
      label: 'Left lower arm',
      parentId: 'upper_arm_left',
      x: 596,
      y: 644,
      width: 86,
      height: 129,
      pivotX: 619.6,
      pivotY: 662.56,
      z: 9,
      rotationMin: -150,
      rotationMax: 150,
    ),
    'upper_arm_right': SpriteRigPartFrame(
      id: 'upper_arm_right',
      label: 'Right upper arm',
      parentId: 'torso',
      x: 454,
      y: 560,
      width: 67,
      height: 118,
      pivotX: 497,
      pivotY: 588.29,
      z: 32,
      rotationMin: -150,
      rotationMax: 150,
    ),
    'lower_arm_right': SpriteRigPartFrame(
      id: 'lower_arm_right',
      label: 'Right lower arm',
      parentId: 'upper_arm_right',
      x: 419,
      y: 634,
      width: 77,
      height: 145,
      pivotX: 473.71,
      pivotY: 659,
      z: 30,
      rotationMin: -150,
      rotationMax: 150,
    ),
    'upper_leg_left': SpriteRigPartFrame(
      id: 'upper_leg_left',
      label: 'Left upper leg',
      parentId: 'torso',
      x: 557,
      y: 753,
      width: 85,
      height: 141,
      pivotX: 603.29,
      pivotY: 760,
      z: 6,
      rotationMin: -90,
      rotationMax: 90,
    ),
    'lower_leg_left': SpriteRigPartFrame(
      id: 'lower_leg_left',
      label: 'Left lower leg',
      parentId: 'upper_leg_left',
      x: 560,
      y: 857,
      width: 88,
      height: 140,
      pivotX: 599.29,
      pivotY: 873,
      z: 5,
      rotationMin: -120,
      rotationMax: 120,
    ),
    'upper_leg_right': SpriteRigPartFrame(
      id: 'upper_leg_right',
      label: 'Right upper leg',
      parentId: 'torso',
      x: 469,
      y: 740,
      width: 94,
      height: 150,
      pivotX: 513.6,
      pivotY: 752.56,
      z: 8,
      rotationMin: -90,
      rotationMax: 90,
    ),
    'lower_leg_right': SpriteRigPartFrame(
      id: 'lower_leg_right',
      label: 'Right lower leg',
      parentId: 'upper_leg_right',
      x: 465,
      y: 848,
      width: 84,
      height: 156,
      pivotX: 509,
      pivotY: 862.71,
      z: 7,
      rotationMin: -120,
      rotationMax: 120,
    ),
  };

  SpriteLayers process(Uint8List source, {double splitRatio = 0.46}) {
    final transparent = _decodeTransparent(source);

    final splitY = (transparent.height * splitRatio)
        .round()
        .clamp(1, transparent.height - 1)
        .toInt();
    final head = image.Image.from(transparent);
    final body = image.Image.from(transparent);

    for (var y = 0; y < transparent.height; y++) {
      for (var x = 0; x < transparent.width; x++) {
        if (y >= splitY) head.setPixelRgba(x, y, 0, 0, 0, 0);
        if (y < splitY) body.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }

    final rejoined = image.Image(transparent.width, transparent.height);
    for (var y = 0; y < transparent.height; y++) {
      for (var x = 0; x < transparent.width; x++) {
        final headPixel = head.getPixel(x, y);
        rejoined.setPixel(
          x,
          y,
          image.getAlpha(headPixel) > 0 ? headPixel : body.getPixel(x, y),
        );
      }
    }

    return SpriteLayers(
      source: source,
      head: Uint8List.fromList(image.encodePng(head)),
      body: Uint8List.fromList(image.encodePng(body)),
      rejoined: Uint8List.fromList(image.encodePng(rejoined)),
    );
  }

  /// Separates the locked front-facing master into one head and nine body
  /// layers using the same canonical geometry as `humanoid_v1/rig.json`.
  /// Every visible source pixel belongs to exactly one layer, so the neutral
  /// rejoin remains visually identical to the cleaned, canonical-sized master.
  SpriteRigLayers processRig(Uint8List source) {
    final decoded = _decodeTransparent(source);
    final transparent =
        decoded.width == canonicalCanvasWidth &&
            decoded.height == canonicalCanvasHeight
        ? decoded
        : image.copyResize(
            decoded,
            width: canonicalCanvasWidth,
            height: canonicalCanvasHeight,
            interpolation: image.Interpolation.linear,
          );
    final fullCanvasLayers = {
      for (final id in rigPartIds)
        id: image.Image(transparent.width, transparent.height),
    };
    final bounds = {for (final id in rigPartIds) id: _PixelBounds()};

    for (var y = 0; y < transparent.height; y++) {
      for (var x = 0; x < transparent.width; x++) {
        final pixel = transparent.getPixel(x, y);
        if (image.getAlpha(pixel) == 0) continue;
        final id = _rigPartFor(x, y);
        fullCanvasLayers[id]!.setPixel(x, y, pixel);
        bounds[id]!.include(x, y);
      }
    }

    final croppedLayers = <String, Uint8List>{};
    final frames = <String, SpriteRigPartFrame>{};
    final rejoined = image.Image(transparent.width, transparent.height);
    for (final id in rigPartIds) {
      final template = canonicalPartFrames[id]!;
      final partBounds = bounds[id]!;
      final frame = partBounds.isEmpty
          ? template.withBounds(
              x: template.x,
              y: template.y,
              width: 1,
              height: 1,
            )
          : template.withBounds(
              x: partBounds.left,
              y: partBounds.top,
              width: partBounds.width,
              height: partBounds.height,
            );
      final cropped = image.copyCrop(
        fullCanvasLayers[id]!,
        frame.x,
        frame.y,
        frame.width,
        frame.height,
      );
      frames[id] = frame;
      croppedLayers[id] = Uint8List.fromList(image.encodePng(cropped));
      image.drawImage(rejoined, cropped, dstX: frame.x, dstY: frame.y);
    }

    final sourceBytes = Uint8List.fromList(image.encodePng(transparent));
    final rejoinedBytes = Uint8List.fromList(image.encodePng(rejoined));
    final validation = validateRigPackage(
      source: sourceBytes,
      rejoined: rejoinedBytes,
      parts: croppedLayers,
      partFrames: frames,
      width: transparent.width,
      height: transparent.height,
    );
    return SpriteRigLayers(
      source: sourceBytes,
      parts: Map.unmodifiable(croppedLayers),
      rejoined: rejoinedBytes,
      width: transparent.width,
      height: transparent.height,
      partFrames: Map.unmodifiable(frames),
      validation: validation,
    );
  }

  SpriteRigValidation validateRigPackage({
    required Uint8List source,
    required Uint8List rejoined,
    required Map<String, Uint8List> parts,
    required Map<String, SpriteRigPartFrame> partFrames,
    required int width,
    required int height,
  }) {
    final errors = <String>[];
    final visiblePixels = <String, int>{};
    final sourceImage = image.decodeImage(source);
    final rejoinedImage = image.decodeImage(rejoined);

    if (width != canonicalCanvasWidth || height != canonicalCanvasHeight) {
      errors.add(
        'The character canvas must be '
        '${canonicalCanvasWidth}x$canonicalCanvasHeight.',
      );
    }
    if (sourceImage == null ||
        sourceImage.width != width ||
        sourceImage.height != height) {
      errors.add('The character master is missing or has the wrong size.');
    }
    if (rejoinedImage == null ||
        rejoinedImage.width != width ||
        rejoinedImage.height != height) {
      errors.add('The neutral reassembly is missing or has the wrong size.');
    }

    final composed = image.Image(width, height);
    for (final id in rigPartIds) {
      final bytes = parts[id];
      final frame = partFrames[id];
      if (bytes == null || frame == null) {
        errors.add('The $id layer is missing.');
        visiblePixels[id] = 0;
        continue;
      }
      if (frame.x < 0 ||
          frame.y < 0 ||
          frame.width < 1 ||
          frame.height < 1 ||
          frame.right > width ||
          frame.bottom > height) {
        errors.add('The $id layer has invalid rig bounds.');
        visiblePixels[id] = 0;
        continue;
      }
      final decoded = image.decodeImage(bytes);
      if (decoded == null ||
          decoded.width != frame.width ||
          decoded.height != frame.height) {
        errors.add('The $id layer is invalid or has the wrong crop size.');
        visiblePixels[id] = 0;
        continue;
      }
      final count = _visiblePixelCount(decoded);
      visiblePixels[id] = count;
      if (count == 0) {
        errors.add('The $id layer is empty.');
      }
      image.drawImage(composed, decoded, dstX: frame.x, dstY: frame.y);
    }

    final composedBytes = Uint8List.fromList(image.encodePng(composed));
    final reassemblyMatches =
        sourceImage != null &&
        rejoinedImage != null &&
        visuallyMatches(source, rejoined) &&
        visuallyMatches(rejoined, composedBytes);
    if (!reassemblyMatches) {
      errors.add('The neutral rig does not reassemble to the locked master.');
    }

    return SpriteRigValidation(
      errors: List.unmodifiable(errors),
      visiblePixelsByPart: Map.unmodifiable(visiblePixels),
      neutralReassemblyMatches: reassemblyMatches,
    );
  }

  static Map<String, SpriteRigPose> canonicalPosesFor(String rigId) {
    SpriteRigPose pose(
      String id,
      String name,
      String faceExpressionId,
      Map<String, SpritePartTransform> parts,
    ) {
      return SpriteRigPose(
        id: id,
        name: name,
        rigId: rigId,
        faceExpressionId: faceExpressionId,
        parts: Map.unmodifiable(parts),
      );
    }

    return Map.unmodifiable({
      'neutral': pose('neutral', 'Idle', 'neutral', const {
        'head': SpritePartTransform(
          offsetX: 0.39667807334714666,
          offsetY: 16.26444666838843,
        ),
      }),
      'talking': pose('talking', 'Talking', 'talking', const {
        'upper_arm_right': SpritePartTransform(rotation: 34),
        'lower_arm_right': SpritePartTransform(rotation: -92),
        'upper_arm_left': SpritePartTransform(rotation: -33.50250191848281),
        'lower_arm_left': SpritePartTransform(rotation: -7.0050735471667736),
        'head': SpritePartTransform(offsetY: 16),
      }),
      'pointing': pose('pointing', 'Pointing', 'neutral', const {
        'upper_arm_left': SpritePartTransform(rotation: -70),
        'lower_arm_left': SpritePartTransform(rotation: 9.32227773114667),
        'head': SpritePartTransform(offsetY: 16),
      }),
      'walking': pose('walking', 'Walking', 'neutral', const {
        'upper_arm_right': SpritePartTransform(rotation: 14.08265673424583),
        'lower_arm_right': SpritePartTransform(rotation: -8),
        'upper_arm_left': SpritePartTransform(rotation: -16.066127808626064),
        'lower_arm_left': SpritePartTransform(rotation: 5.355335582386374),
        'upper_leg_right': SpritePartTransform(rotation: -30.347143756456617),
        'lower_leg_right': SpritePartTransform(rotation: 15.66940938145666),
        'upper_leg_left': SpritePartTransform(rotation: 20.42972785382247),
        'lower_leg_left': SpritePartTransform(rotation: 28),
        'head': SpritePartTransform(offsetY: 15.735529119318187),
      }),
    });
  }

  bool visuallyMatches(Uint8List first, Uint8List second) {
    final left = image.decodeImage(first);
    final right = image.decodeImage(second);
    if (left == null ||
        right == null ||
        left.width != right.width ||
        left.height != right.height) {
      return false;
    }
    for (var y = 0; y < left.height; y++) {
      for (var x = 0; x < left.width; x++) {
        if (left.getPixel(x, y) != right.getPixel(x, y)) return false;
      }
    }
    return true;
  }

  Uint8List removeGreenBackground(Uint8List source, {int? width, int? height}) {
    var transparent = _decodeTransparent(source);
    if (width != null || height != null) {
      if (width == null || height == null) {
        throw const FormatException(
          'Width and height must be provided together.',
        );
      }
      transparent = image.copyResize(
        transparent,
        width: width,
        height: height,
        interpolation: image.Interpolation.linear,
      );
    }
    return Uint8List.fromList(image.encodePng(transparent));
  }

  Uint8List removeMagentaBackground(Uint8List source) {
    final decoded = image.decodeImage(source);
    if (decoded == null) throw const FormatException('Invalid sprite image.');
    final transparent = image.Image.from(decoded)
      ..channels = image.Channels.rgba;
    for (var y = 0; y < transparent.height; y++) {
      for (var x = 0; x < transparent.width; x++) {
        final pixel = transparent.getPixel(x, y);
        final red = image.getRed(pixel);
        final green = image.getGreen(pixel);
        final blue = image.getBlue(pixel);
        if (red > 80 && blue > 80 && red > green + 25 && blue > green + 25) {
          transparent.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    return Uint8List.fromList(image.encodePng(transparent));
  }

  Uint8List composeLayers(Uint8List base, Uint8List overlay) {
    final baseImage = _decodeTransparent(base);
    final overlayImage = _decodeTransparent(overlay);
    if (baseImage.width != overlayImage.width ||
        baseImage.height != overlayImage.height) {
      throw const FormatException(
        'Sprite layers must use the same canvas size.',
      );
    }

    image.drawImage(baseImage, overlayImage);
    return Uint8List.fromList(image.encodePng(baseImage));
  }

  image.Image _decodeTransparent(Uint8List source) {
    final decoded = image.decodeImage(source);
    if (decoded == null) throw const FormatException('Invalid sprite image.');

    final transparent = image.Image.from(decoded)
      ..channels = image.Channels.rgba;
    _removeGreenBackground(transparent);
    return transparent;
  }

  void _removeGreenBackground(image.Image sprite) {
    final queue = <int>[];
    final visited = Uint8List(sprite.width * sprite.height);

    void add(int x, int y) {
      if (x < 0 || y < 0 || x >= sprite.width || y >= sprite.height) return;
      final index = y * sprite.width + x;
      if (visited[index] != 0) return;
      visited[index] = 1;
      final pixel = sprite.getPixel(x, y);
      final red = image.getRed(pixel);
      final green = image.getGreen(pixel);
      final blue = image.getBlue(pixel);
      if (green > 20 && green > red + 5 && green > blue + 5) {
        queue.add(index);
      }
    }

    for (var x = 0; x < sprite.width; x++) {
      add(x, 0);
      add(x, sprite.height - 1);
    }
    for (var y = 0; y < sprite.height; y++) {
      add(0, y);
      add(sprite.width - 1, y);
    }
    for (var cursor = 0; cursor < queue.length; cursor++) {
      final index = queue[cursor];
      final x = index % sprite.width;
      final y = index ~/ sprite.width;
      sprite.setPixelRgba(x, y, 0, 0, 0, 0);
      add(x - 1, y);
      add(x + 1, y);
      add(x, y - 1);
      add(x, y + 1);
    }
  }

  int _visiblePixelCount(image.Image source) {
    var count = 0;
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (image.getAlpha(source.getPixel(x, y)) > 0) count++;
      }
    }
    return count;
  }

  String _rigPartFor(int x, int y) {
    String? selectedId;
    var selectedScore = double.infinity;
    for (final id in rigPartIds) {
      final frame = canonicalPartFrames[id]!;
      final centerX = frame.x + frame.width / 2;
      final centerY = frame.y + frame.height / 2;
      final dx = (x - centerX) / frame.width;
      final dy = (y - centerY) / frame.height;
      var score = dx * dx + dy * dy;
      if (frame.contains(x, y)) score *= 0.18;
      if (score < selectedScore) {
        selectedId = id;
        selectedScore = score;
      }
    }
    return selectedId!;
  }
}

class _PixelBounds {
  var left = 1 << 30;
  var top = 1 << 30;
  var right = -1;
  var bottom = -1;

  bool get isEmpty => right < left || bottom < top;
  int get width => right - left + 1;
  int get height => bottom - top + 1;

  void include(int x, int y) {
    if (x < left) left = x;
    if (y < top) top = y;
    if (x > right) right = x;
    if (y > bottom) bottom = y;
  }
}
