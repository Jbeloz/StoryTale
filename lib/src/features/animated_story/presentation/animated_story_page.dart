import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class AnimatedStoryPage extends StatelessWidget {
  const AnimatedStoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.movie_filter_outlined,
      title: 'Animated Story Mode',
      description:
          'Each EPUB chapter can have its own dynamic scene package and ending moral.',
      plannedFeatures: [
        'Character sprites and chapter backgrounds',
        'Narrator and character text-to-speech voices',
        'Subtitles, simple movement, music, and sound effects',
        'A short moral shown at the end of every chapter',
      ],
    );
  }
}
