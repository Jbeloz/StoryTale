import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _canvasWidth = 1024;
const _canvasHeight = 1024;
const _outputRoot =
    'assets/images/characters/garment_fixtures/v5/legs_gacha_v4_shoe_fill';

const _pants = [104, 82, 190];
const _waistband = [64, 48, 128];
const _shoeBody = [35, 35, 60];
const _shoePanel = [78, 78, 112];
const _accent = [242, 226, 245];
const _sole = [205, 207, 224];

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
    'version': 'v5-legs-clothing-fixture-shoe-fill-4',
    'canvas': {
      'width': _canvasWidth,
      'height': _canvasHeight,
      'format': 'PNG',
      'background': '#00FF00',
    },
    'design': {
      'style': 'filled Gacha-style shoe with small flat details',
      'pantsColor': '#6852BE',
      'shoeBodyColor': '#23233C',
      'shoePanelColor': '#4E4E70',
      'accentColor': '#F2E2F5',
      'soleColor': '#CDCFE0',
      'shoeBodyDominates': true,
      'originalOutlinePreserved': true,
      'noGradients': true,
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
  stdout.writeln('Wrote ${sheetFile.path} and four filled-shoe overlays.');
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

      final color = _clothingColor(partId, x, t, source.width);
      final outputPixel = _isOriginalOutline(source, x, y)
          ? sourcePixel
          : image.getColor(color[0], color[1], color[2], alpha);
      overlay.setPixel(x, y, outputPixel);
    }
  }
  return overlay;
}

List<int> _clothingColor(String partId, int x, double t, int width) {
  if (!partId.startsWith('lower_leg_')) {
    return t <= 0.10 ? _waistband : _pants;
  }

  // The shoe occupies most of the lower-leg silhouette, not just a few lines.
  if (t < 0.40) return _pants;
  if (t >= 0.90) return _sole;
  if (t >= 0.78) return _shoePanel;

  // Small flat details remain inside the filled shoe body.
  if ((t - 0.53).abs() < 0.018 || (t - 0.63).abs() < 0.018) {
    return _accent;
  }
  if (t >= 0.46 && t < 0.56 && x > width * 0.40 && x < width * 0.60) {
    return _accent;
  }
  return _shoeBody;
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

const _readme = '''# V5 legs clothing fixture — filled-shoe Gacha-style v4

This revision responds to the shoe reference: the lower-leg clothing is a
mostly filled dark shoe body, with only small light strap/lace accents, a flat
toe panel, and a solid light sole. Purple leggings remain above it. The
original outer outline pixels are reapplied after painting, and every pixel is
clipped to the immutable `humanoid_v1` alpha mask.

Files:

- `legs_clothing_fixture_1k.png` — 1024x1024 green-screen review sheet.
- Four transparent per-leg overlays with native runtime dimensions.
- `manifest.json` — colors, source hashes, placements, and mask guarantees.

This is a local review fixture only. It is not a provider response and is not
registered in Flutter.
''';
