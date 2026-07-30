import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/story_human_repository.dart';

class StoryGeneratedHumanView extends StatelessWidget {
  const StoryGeneratedHumanView({
    required this.parts,
    required this.poseId,
    super.key,
  });

  final Map<String, Uint8List> parts;
  final String poseId;

  @override
  Widget build(BuildContext context) {
    final metadata = StoryHumanRigMetadata.standard();
    return SizedBox.square(
      dimension: 1000,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final partId in metadata.layerOrder)
            if (parts[partId] case final bytes?)
              _part(
                partId,
                bytes,
                metadata.pivotByPart[partId] ?? const [0.5, 0.5],
              ),
        ],
      ),
    );
  }

  Widget _part(String partId, Uint8List bytes, List<double> pivot) {
    final transform = _pose(poseId)[partId] ?? const _PartTransform();
    return Transform.translate(
      offset: Offset(transform.x, transform.y),
      child: Transform.rotate(
        angle: transform.degrees * math.pi / 180,
        alignment: Alignment(pivot[0] * 2 - 1, pivot[1] * 2 - 1),
        child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
      ),
    );
  }

  Map<String, _PartTransform> _pose(String id) {
    return switch (id) {
      'talking' => const {
        'right_upper_arm': _PartTransform(degrees: -30),
        'right_lower_arm': _PartTransform(degrees: -18, x: -8, y: -10),
        'left_upper_arm': _PartTransform(degrees: 8),
      },
      'pointing' => const {
        'right_upper_arm': _PartTransform(degrees: -65, x: -18, y: -10),
        'right_lower_arm': _PartTransform(degrees: -65, x: -35, y: -20),
        'left_upper_arm': _PartTransform(degrees: 10),
      },
      'walking' => const {
        'left_upper_arm': _PartTransform(degrees: -18),
        'left_lower_arm': _PartTransform(degrees: -12),
        'right_upper_arm': _PartTransform(degrees: 18),
        'right_lower_arm': _PartTransform(degrees: 12),
        'left_upper_leg': _PartTransform(degrees: 12),
        'left_lower_leg': _PartTransform(degrees: 8, x: 6),
        'right_upper_leg': _PartTransform(degrees: -12),
        'right_lower_leg': _PartTransform(degrees: -8, x: -6),
      },
      _ => const {},
    };
  }
}

class _PartTransform {
  const _PartTransform({this.degrees = 0, this.x = 0, this.y = 0});

  final double degrees;
  final double x;
  final double y;
}
