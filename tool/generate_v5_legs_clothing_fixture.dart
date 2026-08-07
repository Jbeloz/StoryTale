import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _canvasWidth = 1024;
const _canvasHeight = 1024;
const _outputRoot = 'assets/images/characters/garment_fixtures/v5/legs';

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
  final canvas = image.Image(_canvasWidth, _canvasHeight)
    ..channels = image.Channels.rgba;
  image.fill(canvas, image.getColor(0, 255, 0, 255));

  final manifest = <String, Object?>{
    'version': 'v5-legs-clothing-fixture-1',
    'canvas': {
      'width': _canvasWidth,
      'height': _canvasHeight,
      'format': 'PNG',
      'background': '#00FF00',
      'purpose': 'local clothing-only shape review',
    },
    'design': {
      'name': 'navy leggings with brown shoes',
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

    final overlayPath = File('$_outputRoot/${entry.key}_clothing.png');
    overlayPath.parent.createSync(recursive: true);
    final overlayBytes = image.encodePng(overlay);
    overlayPath.writeAsBytesSync(overlayBytes);

    final placement = _placements[entry.key]!;
    image.drawImage(canvas, overlay, dstX: placement.x, dstY: placement.y);
    (manifest['parts']! as Map<String, Object?>)[entry.key] = {
      'sourceAsset': entry.value,
      'sourceSha256': sha256.convert(sourceBytes).toString(),
      'overlayAsset': overlayPath.path.replaceAll('\\', '/'),
      'overlaySha256': sha256.convert(overlayBytes).toString(),
      'nativeSize': {'width': source.width, 'height': source.height},
      'reviewSheetPosition': {'x': placement.x, 'y': placement.y},
      'clippedToSourceMask': true,
      'nonTransparentOutsideSource': false,
    };
    stdout.writeln(
      'Generated ${entry.key}: ${source.width}x${source.height} clothing overlay',
    );
  }

  final sheetPath = File('$_outputRoot/legs_clothing_fixture_1k.png');
  sheetPath.writeAsBytesSync(image.encodePng(canvas));
  final sheetBytes = sheetPath.readAsBytesSync();
  (manifest['reviewSheet'] = {
    'asset': sheetPath.path.replaceAll('\\', '/'),
    'sha256': sha256.convert(sheetBytes).toString(),
    'partsRemainSeparated': true,
  });
  File(
    '$_outputRoot/manifest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  File('$_outputRoot/README.md').writeAsStringSync(_readme);
  stdout.writeln('Wrote ${sheetPath.path} and four transparent overlays.');
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
      overlay.setPixel(
        x,
        y,
        image.getColor(color[0], color[1], color[2], alpha),
      );
    }
  }
  return overlay;
}

List<int> _clothingColor(String partId, int x, int y, double t, int width) {
  final isLower = partId.startsWith('lower_leg_');
  final isShoe = isLower && t >= 0.58;
  if (isShoe) {
    final isSole = t >= 0.84;
    if (isSole) return [224, 178, 102];
    final highlight = x < width * 0.34 && t < 0.78;
    return highlight ? [125, 82, 58] : [91, 58, 42];
  }

  final waistband = !isLower && t <= 0.12;
  if (waistband) return [20, 29, 74];

  final sideShade = x < width * 0.28
      ? 10
      : x > width * 0.74
      ? -6
      : 0;
  return [45 + sideShade, 62 + sideShade, 134 + sideShade];
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

const _readme = '''# V5 legs clothing fixture

This is a local, deterministic review fixture for the V5 legs group. It uses
the locked `humanoid_v1` leg alpha masks and paints a simple navy leggings /
brown shoes design **inside those masks only**. It is not a provider response,
does not replace any runtime body part, and costs no credits.

## Files

- `legs_clothing_fixture_1k.png` — 1024x1024 green-screen review sheet.
- `upper_leg_left_clothing.png` and `upper_leg_right_clothing.png` — pants overlays.
- `lower_leg_left_clothing.png` and `lower_leg_right_clothing.png` — pants plus shoes overlays.
- `manifest.json` — source hashes, native sizes, placements, and mask guarantees.

The transparent overlays are ready for the existing `SpriteGarmentLayer` shape,
but they are not registered in Flutter until the owner approves the design and
the offline V5-3 group path is complete.
''';
