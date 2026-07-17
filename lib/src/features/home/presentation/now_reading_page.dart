import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../library/presentation/library_page.dart';
import '../../reader/presentation/reader_page.dart';

class NowReadingPage extends StatelessWidget {
  const NowReadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final current = controller.currentBook;
    if (current == null) {
      return StoryTaleEmptyState(
        title: 'Nothing open yet',
        message: 'Choose a book from your local library to start reading.',
        actionLabel: 'View Library',
        onAction: () {},
        icon: Icons.menu_book_outlined,
      );
    }

    final recent = [...controller.books]
      ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StoryTaleSectionHeader(title: 'Continue Reading'),
        BookCoverCard(
          book: current,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ReaderPage())),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ReaderPage())),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Continue Reading'),
        ),
        const SizedBox(height: 24),
        const StoryTaleSectionHeader(title: 'Recently Opened'),
        ...recent
            .take(3)
            .map(
              (book) => BookCoverCard(
                book: book,
                onTap: () {
                  controller.openBook(book);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BookDetailsPage()),
                  );
                },
              ),
            ),
        const SizedBox(height: 24),
        const StoryTaleSectionHeader(title: 'Suggested From Your Library'),
        ...controller.books
            .where((book) => book.id != current.id)
            .take(2)
            .map(
              (book) => ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(book.title),
                subtitle: Text(book.tags.join(' • ')),
                onTap: () {
                  controller.openBook(book);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BookDetailsPage()),
                  );
                },
              ),
            ),
      ],
    );
  }
}
