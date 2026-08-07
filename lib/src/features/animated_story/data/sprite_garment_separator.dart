import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'sprite_layer_processor.dart';

/// One piece found in a generated sheet, cropped to its own artwork.
class SpriteGarmentPiece {
  const SpriteGarmentPiece({
    required this.bytes,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.visiblePixels,
  });

  /// A transparent PNG containing only this piece.
  final Uint8List bytes;

  /// Where the piece sat in the source sheet. Kept so a caller can explain
  /// which piece it is by position — "top row, second from the left" — which is
  /// the only identity a separated blob has.
  final int left;
  final int top;
  final int width;
  final int height;
  final int visiblePixels;
}

/// Cuts a sheet of separate drawings into one image per drawing.
///
/// This is what lets StoryTale stop asking a provider to honour a pixel-exact
/// layout. V4 spent eight paid sheets discovering that a provider will not keep
/// twelve cells in place; the separator only needs the pieces to be *apart*,
/// which is a far easier thing to ask for and to check.
///
/// It also means a hair image that came back with the front and rear layers in
/// one picture can be split without a second request.
class SpriteGarmentSeparator {
  const SpriteGarmentSeparator({this.minimumVisiblePixels = 64});

  /// Components smaller than this are treated as speckle and dropped.
  ///
  /// Chroma-keyed edges and JPEG ringing leave stray specks that are otherwise
  /// indistinguishable from a very small garment. Raise it for noisy sources.
  final int minimumVisiblePixels;

  /// A pixel counts as artwork above this alpha.
  ///
  /// Not zero: the green removal leaves partly transparent pixels along every
  /// antialiased edge, and treating those as artwork joins pieces that only
  /// touch through a haze.
  static const _alphaThreshold = 24;

  /// Splits [source] into one PNG per separate drawing.
  ///
  /// Ordered the way the sheet reads: top row first, then left to right within
  /// each row, so a caller can map pieces to parts by position.
  ///
  /// Returns an empty list for a sheet with nothing on it rather than throwing;
  /// an empty result is a legitimate answer, and the caller can say so better
  /// than an exception can.
  List<SpriteGarmentPiece> separate(Uint8List source, {int? minimumPixels}) {
    final threshold = minimumPixels ?? minimumVisiblePixels;

    // Reuse the one chroma key this project already trusts. It is seeded from
    // the border, so green sealed inside a garment stays put instead of
    // punching a hole through it.
    final transparent = image.decodeImage(
      const SpriteLayerProcessor().removeGreenBackground(source),
    );
    if (transparent == null) {
      throw const FormatException('Invalid garment sheet.');
    }

    final width = transparent.width;
    final height = transparent.height;
    final visible = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (image.getAlpha(transparent.getPixel(x, y)) > _alphaThreshold) {
          visible[y * width + x] = 1;
        }
      }
    }

    final pieces = <SpriteGarmentPiece>[];
    final claimed = Uint8List(width * height);
    for (var startY = 0; startY < height; startY++) {
      for (var startX = 0; startX < width; startX++) {
        final startIndex = startY * width + startX;
        if (visible[startIndex] == 0 || claimed[startIndex] != 0) continue;

        final component = _floodFill(
          visible: visible,
          claimed: claimed,
          width: width,
          height: height,
          startIndex: startIndex,
        );
        if (component.pixels.length < threshold) continue;

        pieces.add(
          _crop(transparent, component, width),
        );
      }
    }

    _sortAsRead(pieces);
    return pieces;
  }

  /// Eight-connected, iterative.
  ///
  /// Eight rather than four because an antialiased diagonal edge is a staircase
  /// of pixels that only meet at their corners; four-connectivity would cut one
  /// garment into several. Iterative because a full-height piece would blow the
  /// stack in a recursive version.
  _Component _floodFill({
    required Uint8List visible,
    required Uint8List claimed,
    required int width,
    required int height,
    required int startIndex,
  }) {
    final pixels = <int>[startIndex];
    claimed[startIndex] = 1;
    var left = startIndex % width;
    var right = left;
    var top = startIndex ~/ width;
    var bottom = top;

    for (var cursor = 0; cursor < pixels.length; cursor++) {
      final index = pixels[cursor];
      final x = index % width;
      final y = index ~/ width;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;

      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final neighbour = ny * width + nx;
          if (visible[neighbour] == 0 || claimed[neighbour] != 0) continue;
          claimed[neighbour] = 1;
          pixels.add(neighbour);
        }
      }
    }

    return _Component(
      pixels: pixels,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  /// Copies only this component's pixels, so two pieces whose bounding boxes
  /// overlap do not bleed into each other's crop.
  SpriteGarmentPiece _crop(
    image.Image transparent,
    _Component component,
    int sourceWidth,
  ) {
    final width = component.right - component.left + 1;
    final height = component.bottom - component.top + 1;
    final cropped = image.Image(width, height)
      ..channels = image.Channels.rgba;
    image.fill(cropped, image.getColor(0, 0, 0, 0));

    for (final index in component.pixels) {
      final x = index % sourceWidth;
      final y = index ~/ sourceWidth;
      cropped.setPixel(
        x - component.left,
        y - component.top,
        transparent.getPixel(x, y),
      );
    }

    return SpriteGarmentPiece(
      bytes: Uint8List.fromList(image.encodePng(cropped)),
      left: component.left,
      top: component.top,
      width: width,
      height: height,
      visiblePixels: component.pixels.length,
    );
  }

  /// Rows top to bottom, then left to right inside each row.
  ///
  /// A row is a band of pieces that overlap vertically, rather than a fixed
  /// stripe: a provider asked for "two rows of four" will not align them
  /// perfectly, and a piece hanging slightly lower than its neighbours still
  /// belongs to their row.
  void _sortAsRead(List<SpriteGarmentPiece> pieces) {
    pieces.sort((a, b) => a.top.compareTo(b.top));

    final rows = <List<SpriteGarmentPiece>>[];
    var rowBottom = -1;
    for (final piece in pieces) {
      if (rows.isEmpty || piece.top > rowBottom) {
        rows.add([piece]);
        rowBottom = piece.top + piece.height - 1;
        continue;
      }
      rows.last.add(piece);
      final bottom = piece.top + piece.height - 1;
      if (bottom > rowBottom) rowBottom = bottom;
    }

    pieces
      ..clear()
      ..addAll([
        for (final row in rows) ...row..sort((a, b) => a.left.compareTo(b.left)),
      ]);
  }
}

class _Component {
  const _Component({
    required this.pixels,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final List<int> pixels;
  final int left;
  final int top;
  final int right;
  final int bottom;
}
