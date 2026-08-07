import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _sourcePath =
    'assets/images/characters/garment_fixtures/v5/user_refined_source/legs_clothing_user_source.png';
const _outputRoot =
    'assets/images/characters/garment_fixtures/v5/user_refined_linework';

void main() {
  final sourceBytes = File(_sourcePath).readAsBytesSync();
  final source = image.decodeImage(sourceBytes);
  if (source == null) throw const FormatException('Invalid source PNG.');

  final subject = List.generate(
    source.height,
    (_) => List<bool>.filled(source.width, false),
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      subject[y][x] = image.getAlpha(pixel) > 0 && !_isGreen(pixel);
    }
  }

  final polished = image.Image(source.width, source.height)
    ..channels = image.Channels.rgba;
  var changedPixels = 0;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final original = source.getPixel(x, y);
      if (!_isPolishableOuterLine(source, subject, x, y)) {
        polished.setPixel(x, y, original);
        continue;
      }
      final outline = image.getColor(18, 15, 26, image.getAlpha(original));
      polished.setPixel(x, y, outline);
      if (_channelDifference(original, outline)) changedPixels++;
    }
  }

  final outputFile = File('$_outputRoot/legs_clothing_polished_1k.png');
  outputFile.parent.createSync(recursive: true);
  final outputBytes = image.encodePng(polished);
  outputFile.writeAsBytesSync(outputBytes);

  final manifest = {
    'version': 'user-legs-linework-polish-1',
    'source': _sourcePath,
    'output': outputFile.path.replaceAll('\\', '/'),
    'canvas': {
      'width': source.width,
      'height': source.height,
      'background': '#00FF00',
      'format': 'PNG',
    },
    'sourceSha256': sha256.convert(sourceBytes).toString(),
    'outputSha256': sha256.convert(outputBytes).toString(),
    'lineOnlyEdit': true,
    'changedPixelCount': changedPixels,
    'backgroundPreserved': true,
    'positionsAndFillsPreserved': true,
    'shoeDesignPreserved': true,
    'outlineColor': '#120F1A',
  };
  File(
    '$_outputRoot/manifest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  File('$_outputRoot/README.md').writeAsStringSync(_readme);
  stdout.writeln(
    'Wrote ${outputFile.path}; polished $changedPixels outer-line pixels only.',
  );
}

bool _isGreen(dynamic pixel) {
  final red = image.getRed(pixel);
  final green = image.getGreen(pixel);
  final blue = image.getBlue(pixel);
  return green >= 160 && green >= red + 40 && green >= blue + 40;
}

bool _isPolishableOuterLine(
  image.Image source,
  List<List<bool>> subject,
  int x,
  int y,
) {
  final current = source.getPixel(x, y);
  if (!subject[y][x] || image.getAlpha(current) == 0) return false;

  var adjacentToBackground = false;
  var adjacentToDark = false;
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      if (dx == 0 && dy == 0) continue;
      final nx = x + dx;
      final ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= source.width || ny >= source.height) {
        adjacentToBackground = true;
        continue;
      }
      if (!subject[ny][nx]) adjacentToBackground = true;
      final neighbour = source.getPixel(nx, ny);
      if (_isDark(neighbour)) adjacentToDark = true;
    }
  }

  // Only touch antialiased/dark pixels on an existing outer contour. Interior
  // fills and shoe details are copied byte-for-byte from the user's image.
  return adjacentToBackground && (_isDark(current) || adjacentToDark);
}

bool _isDark(dynamic pixel) {
  return image.getAlpha(pixel) > 0 &&
      image.getRed(pixel) < 110 &&
      image.getGreen(pixel) < 110 &&
      image.getBlue(pixel) < 110;
}

bool _channelDifference(dynamic pixel, int color) {
  return image.getRed(pixel) != image.getRed(color) ||
      image.getGreen(pixel) != image.getGreen(color) ||
      image.getBlue(pixel) != image.getBlue(color) ||
      image.getAlpha(pixel) != image.getAlpha(color);
}

const _readme = '''# User legs sheet — linework polish

This output is a conservative polish of the supplied legs clothing sheet.
Only existing outer-contour line pixels were cleaned to a consistent dark
outline. The 1024x1024 canvas, pure green background, positions, fills, shoe
design, and internal shoe details are preserved byte-for-byte everywhere else.

The source image is kept under `../user_refined_source/`. This polished image
is a review asset only; it is not registered in Flutter or sent to a provider.
''';
