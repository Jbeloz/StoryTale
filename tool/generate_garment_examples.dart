import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/chroma_key.dart';
import 'package:storytale/src/features/animated_story/data/sprite_garment_separator.dart';

/// Cuts the owner-supplied clothing sheets into one wearable PNG per rig part.
///
/// Runs offline with `dart run tool/generate_garment_examples.dart`. It uses the
/// real [SpriteGarmentSeparator], so what is checked in is exactly what the app
/// would produce from the same sheet — a build tool that keyed pixels its own
/// way would be worse than useless.
///
/// Deterministic: running it twice must leave `git diff` empty.
const _root = 'assets/images/characters/garment_fixtures/v5';
const _sheetDirectory = '$_root/user_supplied_part_sheets_1k';
const _pieceDirectory = '$_root/pieces';
const _rigManifest = 'assets/images/characters/rigs/humanoid_v1/rig.json';

/// Which rig parts each sheet dresses, **as rows**.
///
/// Position and size answer different halves of the question, and using only
/// one gets it wrong. Size alone cross-matched the arms on the first run: a
/// white hand landed on `upper_arm_left` and a sleeve on `lower_arm_right` at a
/// size difference of 50, because a sleeve and a hand have similar bounding
/// boxes.
///
/// So the **row** decides upper against lower — the sheet is drawn with the
/// upper segments above the lower ones — and **size** decides right against
/// left within that row, where the difference is unambiguous.
const _sheets = <String, List<List<String>>>{
  'torso_clothing_1k.png': [
    ['torso'],
  ],
  'arms_clothing_1k.png': [
    ['upper_arm_right', 'upper_arm_left'],
    ['lower_arm_right', 'lower_arm_left'],
  ],
  'legs_clothing_1k.png': [
    ['upper_leg_right', 'upper_leg_left'],
    ['lower_leg_right', 'lower_leg_left'],
  ],
};

/// A match worse than this is refused rather than written.
///
/// The artwork is drawn at rig scale, so a correct match differs by a handful
/// of pixels. Anything large means the sheet changed shape and the mapping
/// needs a human, not a silent best guess.
const _maximumSizeDifference = 40;

void main() {
  final rig =
      jsonDecode(File(_rigManifest).readAsStringSync()) as Map<String, dynamic>;
  final partSizes = <String, ({int width, int height})>{
    for (final raw in rig['parts'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: (
        width: ((raw['size'] as Map<String, dynamic>)['width'] as num).round(),
        height: ((raw['size'] as Map<String, dynamic>)['height'] as num).round(),
      ),
  };

  Directory(_pieceDirectory).createSync(recursive: true);
  const separator = SpriteGarmentSeparator();
  final entries = <String, dynamic>{};

  for (final sheetEntry in _sheets.entries) {
    final sheetName = sheetEntry.key;
    final expected = sheetEntry.value;
    final bytes = File('$_sheetDirectory/$sheetName').readAsBytesSync();
    final pieces = separator.separate(bytes);
    final expectedCount = expected.fold<int>(0, (sum, row) => sum + row.length);

    if (pieces.length != expectedCount) {
      stderr.writeln(
        '$sheetName produced ${pieces.length} pieces but $expectedCount '
        'parts were expected. Refusing to guess.',
      );
      exitCode = 1;
      return;
    }

    // The separator returns pieces in reading order, so chunking by row size
    // splits them the way the sheet is drawn.
    final assignments = <({String partId, SpriteGarmentPiece piece, int cost})>[];
    var cursor = 0;
    for (final row in expected) {
      final rowPieces = pieces.sublist(cursor, cursor + row.length);
      cursor += row.length;

      // Exhaustive within the row: at most two candidates, so the optimal
      // pairing is cheap and exact. Greedy across the whole sheet is what got
      // the arms wrong.
      List<int>? bestOrder;
      var bestTotal = 1 << 30;
      for (final order in _permutations(List.generate(row.length, (i) => i))) {
        var total = 0;
        for (var i = 0; i < row.length; i++) {
          final size = partSizes[row[i]]!;
          total += (rowPieces[order[i]].width - size.width).abs() +
              (rowPieces[order[i]].height - size.height).abs();
        }
        if (total < bestTotal) {
          bestTotal = total;
          bestOrder = order;
        }
      }

      for (var i = 0; i < row.length; i++) {
        final piece = rowPieces[bestOrder![i]];
        final size = partSizes[row[i]]!;
        final cost = (piece.width - size.width).abs() +
            (piece.height - size.height).abs();
        if (cost > _maximumSizeDifference) {
          stderr.writeln(
            '${row[i]} would take a ${piece.width}x${piece.height} piece '
            'against a ${size.width}x${size.height} part (difference $cost). '
            'Refusing to write a mapping this poor.',
          );
          exitCode = 1;
          return;
        }
        assignments.add((partId: row[i], piece: piece, cost: cost));
      }
    }

    for (final assignment in assignments) {
      final piece = assignment.piece;
      File('$_pieceDirectory/${assignment.partId}.png')
          .writeAsBytesSync(piece.bytes);

      final size = partSizes[assignment.partId]!;
      entries[assignment.partId] = {
        'sourceSheet': sheetName,
        'sourceBounds': {
          'x': piece.left,
          'y': piece.top,
          'width': piece.width,
          'height': piece.height,
        },
        'rigPartSize': {'width': size.width, 'height': size.height},
        'sizeDifference': assignment.cost,
        'visiblePixels': piece.visiblePixels,
        'greenPixelsRemaining': _greenPixels(piece.bytes),
      };
      stdout.writeln(
        '${assignment.partId.padRight(16)} '
        '${piece.width}x${piece.height} vs rig ${size.width}x${size.height} '
        '(difference ${assignment.cost}) from $sheetName',
      );
    }
  }

  final manifest = <String, dynamic>{
    'version': 'garment-examples-1',
    'purpose':
        'Owner-drawn clothing, cut from the 1K part sheets by the real '
        'separator. Wearable examples, not provider output.',
    'generator': 'tool/generate_garment_examples.dart',
    'pieces': Map.fromEntries(
      entries.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  };
  File('$_pieceDirectory/manifest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  stdout.writeln('\nWrote ${entries.length} pieces to $_pieceDirectory');
}

/// Every ordering of [values]. Only ever called with one or two elements.
Iterable<List<int>> _permutations(List<int> values) sync* {
  if (values.length <= 1) {
    yield values;
    return;
  }
  for (var i = 0; i < values.length; i++) {
    final rest = [...values]..removeAt(i);
    for (final tail in _permutations(rest)) {
      yield [values[i], ...tail];
    }
  }
}

/// Zero on every piece, or the green collar is back.
///
/// Uses the shared predicate rather than a copy, so this cannot drift from what
/// the separator actually removes.
int _greenPixels(List<int> png) {
  final decoded = image.decodeImage(Uint8List.fromList(png));
  if (decoded == null) return -1;
  var count = 0;
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final pixel = decoded.getPixel(x, y);
      if (image.getAlpha(pixel) == 0) continue;
      if (ChromaKey.isGreen(pixel)) count++;
    }
  }
  return count;
}
