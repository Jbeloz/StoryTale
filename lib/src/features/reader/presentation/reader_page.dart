import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.chrome_reader_mode_outlined,
      title: 'Reader & Translation',
      description:
          'Read one EPUB chapter at a time and request an English-to-Filipino translation when needed.',
      plannedFeatures: [
        'Dynamic chapter text from the uploaded EPUB',
        'DeepL English-to-Filipino word or chapter translation',
        'Adjustable text, bookmarks, and saved progress',
        'Text-to-speech with highlighted spoken text',
      ],
    );
  }
}
