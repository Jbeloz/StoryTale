import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/sprite_garment_separator.dart';

/// Guards the piece finder that lets StoryTale stop demanding a pixel-exact
/// layout from a provider.
///
/// V4 spent eight paid sheets proving a provider will not keep twelve cells in
/// place. The separator only needs the drawings to be apart, so these tests are
/// about "did it find the right number of pieces, in the right order, without
/// counting speckle" rather than about coordinates.
void main() {
  const separator = SpriteGarmentSeparator();

  test('splits two separate drawings into two cropped pieces', () {
    final sheet = _greenSheet(200, 120);
    _paintBlock(sheet, left: 10, top: 20, width: 40, height: 60);
    _paintBlock(sheet, left: 120, top: 20, width: 30, height: 50);

    final pieces = separator.separate(_png(sheet));

    expect(pieces, hasLength(2));
    expect(pieces[0].width, 40);
    expect(pieces[0].height, 60);
    expect(pieces[0].left, 10);
    expect(pieces[1].width, 30);
    expect(pieces[1].height, 50);
    expect(pieces[1].left, 120);
  });

  test('reads two rows of four the way the sheet is drawn', () {
    final sheet = _greenSheet(440, 260);
    // Deliberately ragged: the provider will not align a row perfectly, and a
    // piece hanging lower than its neighbours still belongs to their row.
    const topOffsets = [10, 22, 14, 18];
    const bottomOffsets = [150, 142, 158, 146];
    for (var column = 0; column < 4; column++) {
      _paintBlock(
        sheet,
        left: 20 + column * 100,
        top: topOffsets[column],
        width: 50,
        height: 70,
      );
      _paintBlock(
        sheet,
        left: 20 + column * 100,
        top: bottomOffsets[column],
        width: 50,
        height: 70,
      );
    }

    final pieces = separator.separate(_png(sheet));

    expect(pieces, hasLength(8));
    // Top row first, left to right, then the bottom row the same way.
    for (var index = 0; index < 4; index++) {
      expect(pieces[index].left, 20 + index * 100, reason: 'top row $index');
      expect(pieces[index].top, lessThan(100), reason: 'top row $index');
      expect(pieces[index + 4].left, 20 + index * 100, reason: 'row 2 $index');
      expect(pieces[index + 4].top, greaterThan(100), reason: 'row 2 $index');
    }
  });

  test('drops speckle below the threshold but keeps the garment', () {
    final sheet = _greenSheet(200, 120);
    _paintBlock(sheet, left: 20, top: 20, width: 40, height: 60);
    // Scattered marks of 4 and 9 pixels, the kind a chroma key leaves behind.
    _paintBlock(sheet, left: 150, top: 15, width: 2, height: 2);
    _paintBlock(sheet, left: 160, top: 80, width: 3, height: 3);

    final pieces = separator.separate(_png(sheet));

    expect(pieces, hasLength(1));
    expect(pieces.single.width, 40);
  });

  test('the threshold is what drops them, not luck', () {
    final sheet = _greenSheet(200, 120);
    _paintBlock(sheet, left: 20, top: 20, width: 40, height: 60);
    _paintBlock(sheet, left: 150, top: 15, width: 3, height: 3);

    // Lower the bar under the speckle and it comes back, which proves the
    // default is doing the work rather than the speckle being invisible.
    final permissive = separator.separate(_png(sheet), minimumPixels: 4);

    expect(permissive, hasLength(2));
    expect(permissive.map((piece) => piece.visiblePixels), contains(9));
  });

  test('an empty sheet yields nothing instead of throwing', () {
    expect(separator.separate(_png(_greenSheet(80, 80))), isEmpty);
  });

  test('an already transparent sheet needs no green at all', () {
    // The case a provider with real alpha produces, which is what
    // ProviderCapabilities.supportsTransparentOutput exists to describe.
    final sheet = image.Image(200, 120)..channels = image.Channels.rgba;
    image.fill(sheet, image.getColor(0, 0, 0, 0));
    _paintBlock(sheet, left: 30, top: 10, width: 40, height: 40);
    _paintBlock(sheet, left: 120, top: 10, width: 40, height: 40);

    final pieces = separator.separate(_png(sheet));

    expect(pieces, hasLength(2));
    expect(pieces.first.width, 40);
  });

  test('a detached strand is its own piece, because connectedness is the rule', () {
    // Measured on the real eighth V4 sheet: the separator found 18 pieces in a
    // twelve-cell sheet, and two of the extras were the hair's ahoge strands
    // floating clear of the main mass. That is the separator working correctly
    // — it groups by connectedness, not by what a person would call one
    // drawing. The prompt has to ask for connected shapes; the separator
    // cannot infer intent, and quietly merging nearby blobs would just as
    // easily glue two garments together.
    final sheet = _greenSheet(200, 200);
    _paintBlock(sheet, left: 40, top: 60, width: 60, height: 100);
    _paintBlock(sheet, left: 66, top: 20, width: 8, height: 20);

    final pieces = separator.separate(_png(sheet), minimumPixels: 64);

    expect(pieces, hasLength(2));
    expect(pieces.first.height, 20, reason: 'the strand sorts above the body');
  });

  test('pieces whose bounding boxes overlap do not bleed into each other', () {
    // An L shape and a block tucked into its corner: the L's bounding box
    // contains part of the block, so a naive rectangle crop would copy it in.
    final sheet = _greenSheet(200, 200);
    _paintBlock(sheet, left: 20, top: 20, width: 20, height: 120);
    _paintBlock(sheet, left: 20, top: 120, width: 120, height: 20);
    _paintBlock(sheet, left: 90, top: 40, width: 40, height: 40);

    final pieces = separator.separate(_png(sheet));

    expect(pieces, hasLength(2));
    final lShape = pieces.firstWhere((piece) => piece.width > 100);
    final decoded = image.decodeImage(lShape.bytes)!;
    // Inside the L's bounding box, where the separate block sits, but not part
    // of the L itself.
    expect(
      image.getAlpha(decoded.getPixel(90 - 20, 40 - 20)),
      0,
      reason: 'the neighbouring block must not appear in this crop',
    );
  });
}

image.Image _greenSheet(int width, int height) {
  final sheet = image.Image(width, height)..channels = image.Channels.rgba;
  image.fill(sheet, image.getColor(0, 255, 0, 255));
  return sheet;
}

void _paintBlock(
  image.Image sheet, {
  required int left,
  required int top,
  required int width,
  required int height,
}) {
  for (var y = top; y < top + height; y++) {
    for (var x = left; x < left + width; x++) {
      sheet.setPixel(x, y, image.getColor(58, 92, 168, 255));
    }
  }
}

Uint8List _png(image.Image sheet) =>
    Uint8List.fromList(image.encodePng(sheet));
