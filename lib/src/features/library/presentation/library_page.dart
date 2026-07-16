import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholder(
      icon: Icons.local_library_outlined,
      title: 'EPUB Library',
      description:
          'Upload your own EPUB books, organize them, and continue from your last chapter.',
      actionLabel: 'Upload EPUB',
      onAction: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EPUB upload is the next placeholder to build.'),
          ),
        );
      },
      plannedFeatures: const [
        'EPUB-only upload and validation',
        'Dynamic books, covers, chapters, and reading progress',
        'Search, favorites, and recently read books',
        'Local storage first - no Supabase',
      ],
    );
  }
}
