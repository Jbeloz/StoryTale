import 'dart:typed_data';

import 'package:image/image.dart' as image;

/// The one green test StoryTale uses, and the two ways of applying it.
///
/// Pure Dart on purpose: it depends only on `package:image`, so a `tool/` script
/// can run the same code the app runs. `sprite_layer_processor.dart` reaches
/// `dart:ui` through the rig, which is what stopped the separator being usable
/// offline.
///
/// One copy of the predicate, two callers. Duplicating it is how a sheet ends up
/// keyed one way in the app and another way in a build tool.
class ChromaKey {
  const ChromaKey._();

  /// Deliberately tolerant rather than an exact `#00FF00` match.
  ///
  /// Measured on the owner's three clothing sheets, 2026-08-07: only the legs
  /// sheet is exactly `#00FF00`. The torso averages `(11,249,5)` and the arms
  /// `(3,250,2)`, because the artwork went through lossy compression on its way
  /// here. An exact match would have failed on two sheets out of three.
  static bool isGreen(int pixel) {
    final red = image.getRed(pixel);
    final green = image.getGreen(pixel);
    final blue = image.getBlue(pixel);
    return green > 20 && green > red + 5 && green > blue + 5;
  }

  /// Clears green that is reachable from the border, leaving green sealed inside
  /// the artwork alone.
  ///
  /// This is what the whole-character master path wants: it treats an enclosed
  /// green area as something the artwork chose to contain.
  static void removeConnectedToEdges(image.Image sprite) {
    final queue = <int>[];
    final visited = Uint8List(sprite.width * sprite.height);

    void add(int x, int y) {
      if (x < 0 || y < 0 || x >= sprite.width || y >= sprite.height) return;
      final index = y * sprite.width + x;
      if (visited[index] != 0) return;
      visited[index] = 1;
      if (isGreen(sprite.getPixel(x, y))) queue.add(index);
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

  /// Clears **every** green pixel, wherever it is.
  ///
  /// For garments, green sealed inside the artwork is a hole, not paint: a
  /// collar opening, a shoe eyelet, the gap between two fingers. The clothing
  /// contract forbids green in a garment, so nothing legitimate is lost.
  ///
  /// Measured on the owner's sheets before this existed: the torso alone had
  /// **697** green pixels the edge-seeded fill could never reach, which would
  /// have rendered as a bright green collar patch on the character.
  static void removeEverywhere(image.Image sprite) {
    for (var y = 0; y < sprite.height; y++) {
      for (var x = 0; x < sprite.width; x++) {
        if (isGreen(sprite.getPixel(x, y))) {
          sprite.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
  }
}
