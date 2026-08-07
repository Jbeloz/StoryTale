import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _canvasWidth = 1024;
const _canvasHeight = 1024;
const _outputRoot =
    'assets/images/characters/garment_fixtures/v5/legs_gacha_v3_quality';

const _pants = [104, 82, 190];
const _waistband = [64, 48, 128];
const _shoe = [47, 43, 78];
const _strap = [246, 177, 207];
const _toePanel = [143, 116, 207];
const _sole = [232, 228, 242];

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
    'version': 'v5-legs-clothing-fixture-gacha-quality-3',
    'canvas': {
      'width': _canvasWidth,
      'height': _canvasHeight,
      'format': 'PNG',
      'background': '#00FF00',
    },
    'design': {
      'style': 'flat Gacha-style sneaker boots with preserved original outline',
      'pantsColor': '#6852BE',
      'shoeColor': '#2F2B4E',
      'strapColor': '#F6B1CF',
      'toePanelColor': '#8F74CF',
      'soleColor': '#E8E4F2',
      'noGradients': true,
      'originalOutlinePreserved': true,
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
      'originalOutlineReapplied': true,
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
  stdout.writeln('Wrote ${sheetFile.path} and four quality overlays.');
}

image.Image _makeOverlay(String partId, image.Image source) {
  final overlay = image.Image(source.width, source.height)
    ..channels = image.Channels.rgba;
  image.fill(overlay, image.getColor(0, 0, 0, 0));

  for (var y = 0; y < source.height; y++) {
    final t = y / (source.height - 1);
    for (var x = 0; x < source.width; x++) {
      final sourcePixel = source.getPixel(x, y);
      final alpha = image.getAlpha(sourcePixel);
      if (alpha == 0) continue;

      final color = _clothingColor(partId, x, y, t, source.width);
      final outputPixel = _isOriginalOutline(source, x, y)
          ? sourcePixel
          : image.getColor(color[0], color[1], color[2], alpha);
      overlay.setPixel(x, y, outputPixel);
    }
  }
  return overlay;
}

List<int> _clothingColor(String partId, int x, int y, double t, int width) {
  if (!partId.startsWith('lower_leg_')) {
    return t <= 0.10 ? _waistband : _pants;
  }

  if (t < 0.45) return _pants;
  if (t >= 0.90) return _sole;
  if (t >= 0.78) return _toePanel;
  if ((t - 0.56).abs() < 0.035 || (t - 0.66).abs() < 0.035) {
    return _strap;
  }
  if (t >= 0.48 && t < 0.58 && x > width * 0.40 && x < width * 0.60) {
    return _strap;
  }
  return _shoe;
}

bool _isOriginalOutline(image.Image source, int x, int y) {
  if (image.getAlpha(source.getPixel(x, y)) == 0) return false;
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      if (dx == 0 && dy == 0) continue;
      final nx = x + dx;
      final ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= source.width || ny >= source.height) {
        return true;
      }
      if (image.getAlpha(source.getPixel(nx, ny)) == 0) return true;
    }
  }
  return false;
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

const _readme = '''# V5 legs clothing fixture — quality Gacha-style v3

This revision keeps the flat Gacha-style purple leggings but gives the shoes a
clearer sneaker-boot design: dark shoe body, two pink straps, a purple toe
panel, and a light flat sole. The original `humanoid_v1` outer outline pixels
are reapplied after painting, so the original silhouette and linework stay
visible. There are no gradients or lighting effects.

Files:

- `legs_clothing_fixture_1k.png` — 1024x1024 green-screen review sheet.
- Four transparent per-leg overlays with native runtime dimensions.
- `manifest.json` — colors, source hashes, placements, and mask guarantees.

This is a local review fixture only. It is not a provider response and is not
registered in Flutter.
''';
