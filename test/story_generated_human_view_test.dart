import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/sprite_layer_processor.dart';
import 'package:storytale/src/features/animated_story/presentation/widgets/story_generated_human_view.dart';

void main() {
  testWidgets('renders every generated rig layer for a supported pose', (
    tester,
  ) async {
    final source = image.Image(4, 4)
      ..setPixelRgba(2, 2, 40, 50, 60, 255);
    final bytes = Uint8List.fromList(image.encodePng(source));

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StoryGeneratedHumanView(
            poseId: 'talking',
            parts: {
              for (final partId in SpriteLayerProcessor.rigPartIds)
                partId: bytes,
            },
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNWidgets(10));
  });
}
