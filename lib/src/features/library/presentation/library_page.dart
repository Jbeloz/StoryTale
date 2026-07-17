import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../../shared/widgets/storytale_image_placeholder.dart';
import '../../animated_story/presentation/story_pages.dart';
import '../../narration/presentation/audio_pages.dart';
import '../../reader/presentation/reader_page.dart';
import 'add_book_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    if (controller.books.isEmpty) {
      return StoryTaleEmptyState(
        title: 'Your library is empty',
        message: 'Add an EPUB to begin reading with StoryTale.',
        actionLabel: 'Add EPUB',
        onAction: () => _openAddBook(context),
        icon: Icons.library_add_outlined,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StoryTaleImagePlaceholder(
          path: 'assets/images/ui/library_banner.png',
          label: 'Welcome to StoryTale',
          icon: Icons.auto_stories,
          height: 130,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openAddBook(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Add EPUB Book'),
        ),
        const SizedBox(height: 20),
        StoryTaleSectionHeader(
          title: 'My Books',
          actionLabel: 'See All',
          onAction: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const BookshelfPage())),
        ),
        ...controller.books
            .take(4)
            .map(
              (book) => BookCoverCard(
                book: book,
                onTap: () => _openDetails(context, book),
                onMenu: () => showBookOptionsSheet(context, book),
              ),
            ),
      ],
    );
  }

  void _openAddBook(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddBookPage()));
  }

  void _openDetails(BuildContext context, BookData book) {
    StoryTaleScope.of(context).openBook(book);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BookDetailsPage()));
  }
}

class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    if (book == null) {
      return StoryTaleInfoPage(
        title: 'Book Details',
        description: 'This book is no longer available in the local library.',
      );
    }

    return StoryTaleAppShell(
      title: book.title,
      actions: [
        IconButton(
          onPressed: () => showBookOptionsSheet(context, book),
          icon: const Icon(Icons.more_vert),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoryTaleImagePlaceholder(
                path: book.coverPath,
                bytes: book.coverBytes,
                label: '${book.title} cover placeholder',
                icon: Icons.menu_book,
                width: 120,
                height: 170,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(book.author),
                    const SizedBox(height: 12),
                    Text('${book.language} • ${book.chapters.length} chapters'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: book.progress),
                    Text('${(book.progress * 100).round()}% complete'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ReaderPage())),
            icon: const Icon(Icons.menu_book),
            label: const Text('Read Now'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChapterAudioPreparationPage(),
                    ),
                  ),
                  icon: const Icon(Icons.headphones),
                  label: const Text('Listen'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StoryPreparationPage(),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_motion),
                  label: const Text('Story Mode'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(book.description),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: book.tags.map((tag) => Chip(label: Text(tag))).toList(),
          ),
          const SizedBox(height: 20),
          Text('Chapters', style: Theme.of(context).textTheme.titleLarge),
          ...book.chapters.map(
            (chapter) => ChapterListTile(
              chapter: chapter,
              onTap: () {
                controller.openBook(book, chapter: chapter);
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ReaderPage()));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  String _sort = 'Recent';

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final books = [...controller.books];
    if (_sort == 'Title') {
      books.sort((a, b) => a.title.compareTo(b.title));
    } else {
      books.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    }

    return StoryTaleAppShell(
      title: 'My Bookshelf',
      actions: [
        PopupMenuButton<String>(
          initialValue: _sort,
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'Recent', child: Text('Sort by recent')),
            PopupMenuItem(value: 'Title', child: Text('Sort by title')),
          ],
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: books
            .map(
              (book) => BookCoverCard(
                book: book,
                onTap: () {
                  controller.openBook(book);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BookDetailsPage()),
                  );
                },
                onMenu: () => showBookOptionsSheet(context, book),
              ),
            )
            .toList(),
      ),
    );
  }
}

Future<void> showBookOptionsSheet(BuildContext context, BookData book) async {
  final controller = StoryTaleScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit metadata'),
            subtitle: const Text('Prototype placeholder'),
            onTap: () {
              Navigator.pop(sheetContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Metadata editing will use parsed EPUB data.'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Clear reading progress'),
            onTap: () {
              controller.clearReadingProgress(book);
              Navigator.pop(sheetContext);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Remove from library'),
            onTap: () {
              controller.removeBook(book);
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    ),
  );
}
