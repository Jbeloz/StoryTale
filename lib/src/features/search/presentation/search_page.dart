import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../library/presentation/library_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final results = controller.books.where(_matches).toList();

    return StoryTaleAppShell(
      title: 'Search',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Title, author, tag, or chapter',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_query.isEmpty) ...[
            const StoryTaleSectionHeader(title: 'Recent Searches'),
            ...controller.recentSearches.map(
              (term) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(term),
                onTap: () {
                  _search.text = term;
                  setState(() => _query = term);
                },
              ),
            ),
            const StoryTaleSectionHeader(title: 'Local Categories'),
            Wrap(
              spacing: 8,
              children: ['Fantasy', 'Classic', 'Adventure', 'Children']
                  .map(
                    (tag) => ActionChip(
                      label: Text(tag),
                      onPressed: () {
                        _search.text = tag;
                        setState(() => _query = tag);
                      },
                    ),
                  )
                  .toList(),
            ),
          ] else if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 64),
                  SizedBox(height: 12),
                  Text('No local books matched your search.'),
                ],
              ),
            )
          else ...[
            StoryTaleSectionHeader(title: '${results.length} result(s)'),
            ...results.map(
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
          ],
        ],
      ),
    );
  }

  bool _matches(BookData book) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    return book.title.toLowerCase().contains(needle) ||
        book.author.toLowerCase().contains(needle) ||
        book.tags.any((tag) => tag.toLowerCase().contains(needle)) ||
        book.chapters.any(
          (chapter) => chapter.title.toLowerCase().contains(needle),
        );
  }
}
