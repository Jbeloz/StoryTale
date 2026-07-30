import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/sprite_layer_processor.dart';

void main() {
  test('removes green and rejoins matching head and body layers', () {
    final source = image.Image(4, 4);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(x, y, 0, 255, 0);
      }
    }
    source.setPixelRgba(1, 0, 40, 50, 60);
    source.setPixelRgba(1, 3, 70, 80, 90);

    final layers = const SpriteLayerProcessor().process(
      Uint8List.fromList(image.encodePng(source)),
      splitRatio: 0.5,
    );
    final head = image.decodePng(layers.head)!;
    final body = image.decodePng(layers.body)!;
    final rejoined = image.decodePng(layers.rejoined)!;

    expect(image.getAlpha(head.getPixel(1, 0)), 255);
    expect(image.getAlpha(head.getPixel(1, 3)), 0);
    expect(image.getAlpha(body.getPixel(1, 0)), 0);
    expect(image.getAlpha(body.getPixel(1, 3)), 255);
    expect(image.getAlpha(rejoined.getPixel(0, 0)), 0);
    expect(image.getRed(rejoined.getPixel(1, 0)), 40);
    expect(image.getRed(rejoined.getPixel(1, 3)), 70);
  });

  test('removes green and returns the requested canvas size', () {
    final source = image.Image(2, 2);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(x, y, 0, 255, 0);
      }
    }
    source.setPixelRgba(1, 1, 20, 30, 40);

    final result = const SpriteLayerProcessor().removeGreenBackground(
      Uint8List.fromList(image.encodePng(source)),
      width: 4,
      height: 6,
    );
    final decoded = image.decodePng(result)!;

    expect(decoded.width, 4);
    expect(decoded.height, 6);
    expect(image.getAlpha(decoded.getPixel(0, 0)), 0);
  });

  test('keeps enclosed green character details', () {
    final source = image.Image(5, 5);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(x, y, 0, 255, 0, 255);
      }
    }
    for (var y = 1; y < 4; y++) {
      for (var x = 1; x < 4; x++) {
        source.setPixelRgba(x, y, 80, 80, 80, 255);
      }
    }
    source.setPixelRgba(2, 2, 0, 120, 0, 255);

    final result = const SpriteLayerProcessor().removeGreenBackground(
      Uint8List.fromList(image.encodePng(source)),
    );
    final decoded = image.decodePng(result)!;

    expect(image.getAlpha(decoded.getPixel(0, 0)), 0);
    expect(image.getGreen(decoded.getPixel(2, 2)), 120);
    expect(image.getAlpha(decoded.getPixel(2, 2)), 255);
  });

  test('composes matching transparent sprite layers', () {
    final base = image.Image(2, 2);
    base.setPixelRgba(1, 1, 200, 100, 50, 255);
    final overlay = image.Image(2, 2);
    overlay.setPixelRgba(0, 0, 20, 30, 40, 255);

    final result = const SpriteLayerProcessor().composeLayers(
      Uint8List.fromList(image.encodePng(base)),
      Uint8List.fromList(image.encodePng(overlay)),
    );
    final decoded = image.decodePng(result)!;

    expect(image.getRed(decoded.getPixel(0, 0)), 20);
    expect(image.getRed(decoded.getPixel(1, 1)), 200);
  });

  test('builds ten canonical visible parts and a matching neutral rig', () {
    final source = image.Image(
      SpriteLayerProcessor.canonicalCanvasWidth,
      SpriteLayerProcessor.canonicalCanvasHeight,
    );
    for (final frame in SpriteLayerProcessor.canonicalPartFrames.values) {
      source.setPixelRgba(
        frame.x + frame.width ~/ 2,
        frame.y + frame.height ~/ 2,
        30,
        40,
        120,
        255,
      );
    }

    const processor = SpriteLayerProcessor();
    final rig = processor.processRig(
      Uint8List.fromList(image.encodePng(source)),
    );

    expect(rig.parts.keys, SpriteLayerProcessor.rigPartIds);
    expect(rig.parts, hasLength(10));
    expect(
      rig.validation.visiblePixelsByPart.values,
      everyElement(greaterThan(0)),
    );
    expect(rig.validation.isValid, isTrue);
    expect(processor.visuallyMatches(rig.source, rig.rejoined), isTrue);
    expect(
      rig
          .toRigDefinition(
            rigId: 'humanoid_v1',
            partAssetIds: {
              for (final id in SpriteLayerProcessor.rigPartIds)
                id: 'memory.$id',
            },
          )
          .partsById
          .keys,
      containsAll(SpriteLayerProcessor.rigPartIds),
    );
  });
}
