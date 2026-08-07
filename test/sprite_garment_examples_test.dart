import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/chroma_key.dart';
import 'package:storytale/src/features/animated_story/data/sprite_garment_separator.dart';

/// Guards the owner-drawn example garments and the keying that produced them.
///
/// The assertion worth having here is **zero green pixels**. StoryTale's
/// original chroma key is edge-seeded, so green sealed inside artwork survives
/// it: measured on these very sheets, the torso alone carried 697 such pixels
/// in its collar opening, which would have rendered as a bright green patch on
/// the character. Nothing about the piece looks wrong until it is on the rig.
void main() {
  const pieceDirectory =
      'assets/images/characters/garment_fixtures/v5/pieces';

  late Map<String, dynamic> manifest;
  late Map<String, dynamic> pieces;

  setUpAll(() {
    manifest =
        jsonDecode(File('$pieceDirectory/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    pieces = manifest['pieces'] as Map<String, dynamic>;
  });

  test('every rig part that wears clothing has a piece on disk', () {
    expect(pieces.keys.toSet(), {
      'torso',
      'upper_arm_right',
      'upper_arm_left',
      'lower_arm_right',
      'lower_arm_left',
      'upper_leg_right',
      'upper_leg_left',
      'lower_leg_right',
      'lower_leg_left',
    });
    for (final partId in pieces.keys) {
      expect(
        File('$pieceDirectory/$partId.png').existsSync(),
        isTrue,
        reason: '$partId.png is registered but missing',
      );
    }
  });

  test('no piece carries a single green pixel', () {
    for (final partId in pieces.keys) {
      final decoded = image.decodeImage(
        File('$pieceDirectory/$partId.png').readAsBytesSync(),
      );
      expect(decoded, isNotNull, reason: '$partId.png does not decode');

      var green = 0;
      var visible = 0;
      for (var y = 0; y < decoded!.height; y++) {
        for (var x = 0; x < decoded.width; x++) {
          final pixel = decoded.getPixel(x, y);
          if (image.getAlpha(pixel) == 0) continue;
          visible++;
          if (ChromaKey.isGreen(pixel)) green++;
        }
      }

      expect(
        green,
        0,
        reason: '$partId would render a green patch on the character',
      );
      expect(visible, greaterThan(0), reason: '$partId is empty');
    }
  });

  test('every piece is drawn at rig scale, within a few pixels', () {
    for (final entry in pieces.entries) {
      final piece = entry.value as Map<String, dynamic>;
      expect(
        piece['sizeDifference'] as int,
        lessThanOrEqualTo(40),
        reason:
            '${entry.key} no longer matches its rig part; a re-cut that '
            'silently changes scale must fail here',
      );
      expect(piece['greenPixelsRemaining'], 0);
    }
  });

  group('the keying that made them', () {
    test('clears green sealed inside the artwork, which the old key could not', () {
      // A ring with a green hole in the middle: exactly the torso collar.
      final sheet = image.Image(60, 60)..channels = image.Channels.rgba;
      image.fill(sheet, image.getColor(0, 255, 0, 255));
      for (var y = 10; y < 50; y++) {
        for (var x = 10; x < 50; x++) {
          sheet.setPixel(x, y, image.getColor(40, 40, 50, 255));
        }
      }
      for (var y = 22; y < 38; y++) {
        for (var x = 22; x < 38; x++) {
          sheet.setPixel(x, y, image.getColor(0, 255, 0, 255));
        }
      }

      final pieces = const SpriteGarmentSeparator()
          .separate(Uint8List.fromList(image.encodePng(sheet)));

      expect(pieces, hasLength(1));
      final cut = image.decodeImage(pieces.single.bytes)!;

      // The hole is transparent...
      expect(image.getAlpha(cut.getPixel(20, 20)), 0);
      // ...and the garment around it is intact.
      expect(image.getAlpha(cut.getPixel(2, 2)), greaterThan(0));

      // Prove the old behaviour would have failed this: an edge-seeded fill
      // cannot reach a sealed hole.
      final edgeOnly = image.Image.from(sheet)..channels = image.Channels.rgba;
      ChromaKey.removeConnectedToEdges(edgeOnly);
      expect(
        image.getAlpha(edgeOnly.getPixel(30, 30)),
        255,
        reason: 'the edge-seeded key leaves the sealed hole green, which is '
            'the defect this piece pipeline exists to avoid',
      );
    });
  });
}
