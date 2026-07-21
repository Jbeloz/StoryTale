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

class SpriteLayerProcessor {
  const SpriteLayerProcessor();

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
    for (var y = 0; y < sprite.height; y++) {
      for (var x = 0; x < sprite.width; x++) {
        final pixel = sprite.getPixel(x, y);
        final red = image.getRed(pixel);
        final green = image.getGreen(pixel);
        final blue = image.getBlue(pixel);
        if (green > 20 && green > red + 5 && green > blue + 5) {
          sprite.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
  }
}
