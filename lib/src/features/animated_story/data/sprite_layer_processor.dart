import 'dart:typed_data';

import 'package:image/image.dart' as image;

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
  });

  final Uint8List source;
  final Map<String, Uint8List> parts;
  final Uint8List rejoined;
  final int width;
  final int height;
}

class SpriteLayerProcessor {
  const SpriteLayerProcessor();

  static const rigPartIds = [
    'head',
    'torso',
    'left_upper_arm',
    'left_lower_arm',
    'right_upper_arm',
    'right_lower_arm',
    'left_upper_leg',
    'left_lower_leg',
    'right_upper_leg',
    'right_lower_leg',
  ];

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
  /// layers. Every source pixel belongs to exactly one layer, so the neutral
  /// rejoin remains visually identical to the cleaned master.
  SpriteRigLayers processRig(Uint8List source) {
    final transparent = _decodeTransparent(source);
    final layers = {
      for (final id in rigPartIds)
        id: image.Image(transparent.width, transparent.height),
    };

    for (var y = 0; y < transparent.height; y++) {
      for (var x = 0; x < transparent.width; x++) {
        final id = _rigPartFor(x / transparent.width, y / transparent.height);
        layers[id]!.setPixel(x, y, transparent.getPixel(x, y));
      }
    }

    final rejoined = image.Image(transparent.width, transparent.height);
    for (final id in rigPartIds) {
      image.drawImage(rejoined, layers[id]!);
    }
    return SpriteRigLayers(
      source: Uint8List.fromList(image.encodePng(transparent)),
      parts: {
        for (final entry in layers.entries)
          entry.key: Uint8List.fromList(image.encodePng(entry.value)),
      },
      rejoined: Uint8List.fromList(image.encodePng(rejoined)),
      width: transparent.width,
      height: transparent.height,
    );
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

  String _rigPartFor(double x, double y) {
    if (y < 0.46) return 'head';
    if (y < 0.69) {
      if (x < 0.27) return 'left_upper_arm';
      if (x >= 0.73) return 'right_upper_arm';
      return 'torso';
    }
    if (x < 0.27) return 'left_lower_arm';
    if (x >= 0.73) return 'right_lower_arm';
    if (y < 0.83) {
      return x < 0.5 ? 'left_upper_leg' : 'right_upper_leg';
    }
    return x < 0.5 ? 'left_lower_leg' : 'right_lower_leg';
  }
}
