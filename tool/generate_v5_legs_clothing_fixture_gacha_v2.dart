import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _canvasWidth = 1024;
const _canvasHeight = 1024;
const _outputRoot =
    'assets/images/characters/garment_fixtures/v5/legs_gacha_v2';
const _pantsColor = [104, 82, 190];
const _shoeColor = [228, 112, 154];

const _sources = <String, String>{
  'upper_leg_left':
      'assets/images/characters/rigs/humanoid_v1/base/upper_leg_left.png',
  'lower_leg_left':
      'assets/images/characters/rigs/humanoid_v1/base/lower_leg_left.png',
  'upper_leg_right':
      'assets/images/characters/rigs/humanoid_v1/base/upper_leg_right.png',
  'lower_leg_right':
      'assets/images/characters/rigs/humanoid_v1/base/lower_leg_right.png',
};

const _placements = <String, _Placement>{
  'upper_leg_left': _Placement(170, 160),
  'lower_leg_left': _Placement(170, 650),
  'upper_leg_right': _Placement(760, 160),
  'lower_leg_right': _Placement(760, 650),
};

void main() {
  final sheet = image.Image(_canvasWidth, _canvasHeight)
    ..channels = image.Channels.rgba;
  image.fill(sheet, image.getColor(0, 255, 0, 255));

  final manifest = <String, Object?>{
    'version': 'v5-legs-clothing-fixture-gacha-flat-2',
    'canvas': {
      'width': _canvasWidth,
      'height': _canvasHeight,
      'format': 'PNG',
      'background': '#00FF00',
    },
    'design': {
      'style': 'simple flat Gacha-style clothing',
      'pantsColor': '#6852BE',
      'shoeColor': '#E4709A',
      'noShadows': true,
      'noHighlights': true,
      'noOutlinesAdded': true,
      'clothingOnly': true,
      'shapeSource': 'immutable humanoid_v1 alpha mask',
      'outsideSourceMask': 'transparent',
      'providerRequest': false,
    },
    'parts': <String, Object?>{},
  };

  for (final entry in _sources.entries) {
    final sourceBytes = File(entry.value).readAsBytesSync();
    final source = image.decodeImage(sourceBytes);
    if (source == null) throw FormatException('Cannot decode ${entry.value}');

    final overlay = _makeOverlay(entry.key, source);
    _assertInsideSourceMask(source, overlay, entry.key);

    final output = File('$_outputRoot/${entry.key}_clothing.png');
    output.parent.createSync(recursive: true);
    final overlayBytes = image.encodePng(overlay);
    output.writeAsBytesSync(overlayBytes);

    final placement = _placements[entry.key]!;
    image.drawImage(sheet, overlay, dstX: placement.x, dstY: placement.y);
    (manifest['parts']! as Map<String, Object?>)[entry.key] = {
      'sourceAsset': entry.value,
      'sourceSha256': sha256.convert(sourceBytes).toString(),
      'overlayAsset': output.path.replaceAll('\\', '/'),
      'overlaySha256': sha256.convert(overlayBytes).toString(),
      'nativeSize': {'width': source.width, 'height': source.height},
      'reviewSheetPosition': {'x': placement.x, 'y': placement.y},
      'clippedToSourceMask': true,
      'nonTransparentOutsideSource': false,
    };
  }

  final sheetFile = File('$_outputRoot/legs_clothing_fixture_1k.png');
  sheetFile.writeAsBytesSync(image.encodePng(sheet));
  final sheetBytes = sheetFile.readAsBytesSync();
  manifest['reviewSheet'] = {
    'asset': sheetFile.path.replaceAll('\\', '/'),
    'sha256': sha256.convert(sheetBytes).toString(),
    'partsRemainSeparated': true,
  };
  File(
    '$_outputRoot/manifest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  File('$_outputRoot/README.md').writeAsStringSync(_readme);
  stdout.writeln('Wrote ${sheetFile.path} and four flat-color overlays.');
}

image.Image _makeOverlay(String partId, image.Image source) {
  final overlay = image.Image(source.width, source.height)
    ..channels = image.Channels.rgba;
  image.fill(overlay, image.getColor(0, 0, 0, 0));

  for (var y = 0; y < source.height; y++) {
    final t = y / (source.height - 1);
    final color = partId.startsWith('lower_leg_') && t >= 0.58
        ? _shoeColor
        : _pantsColor;
    for (var x = 0; x < source.width; x++) {
      final alpha = image.getAlpha(source.getPixel(x, y));
      if (alpha == 0) continue;
      overlay.setPixel(
        x,
        y,
        image.getColor(color[0], color[1], color[2], alpha),
      );
    }
  }
  return overlay;
}

void _assertInsideSourceMask(
  image.Image source,
  image.Image overlay,
  String partId,
) {
  if (source.width != overlay.width || source.height != overlay.height) {
    throw StateError('$partId overlay changed the source dimensions');
  }
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final sourceAlpha = image.getAlpha(source.getPixel(x, y));
      final overlayAlpha = image.getAlpha(overlay.getPixel(x, y));
      if (overlayAlpha > 0 && sourceAlpha == 0) {
        throw StateError(
          '$partId clothing escaped its source silhouette at $x,$y',
        );
      }
    }
  }
}

class _Placement {
  const _Placement(this.x, this.y);

  final int x;
  final int y;
}

const _readme = '''# V5 legs clothing fixture — flat Gacha-style v2

This is a second local review design. It uses exactly two flat colors: purple
leggings and pink shoes. There are no shadows, highlights, gradients, added
outlines, or details. Every nontransparent pixel is clipped to the matching
immutable `humanoid_v1` leg alpha mask, so the silhouette cannot change.

Files:

- `legs_clothing_fixture_1k.png` — 1024x1024 green-screen review sheet.
- Four transparent per-leg overlays with native runtime dimensions.
- `manifest.json` — source hashes, colors, placements, and mask guarantees.

This is a review fixture only. It is not a provider response and is not
registered in Flutter.
''';
