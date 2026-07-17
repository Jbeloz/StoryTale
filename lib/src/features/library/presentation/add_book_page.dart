import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../../shared/widgets/storytale_image_placeholder.dart';
import 'library_page.dart';

class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  bool _selected = false;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoryTaleAppShell(
      title: 'Add EPUB',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StoryTaleImagePlaceholder(
            path: 'assets/images/ui/epub_upload.png',
            label: 'EPUB upload illustration placeholder',
            icon: Icons.upload_file,
            height: 150,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _selected = true);
              _title.text = 'My Imported Story';
              _author.text = 'Local EPUB Author';
            },
            icon: const Icon(Icons.folder_open),
            label: Text(
              _selected ? 'prototype-story.epub selected' : 'Select EPUB File',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prototype note: the workflow is functional, but native file picking '
            'and EPUB parsing are the next service integrations.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Book title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _author,
            decoration: const InputDecoration(labelText: 'Author'),
          ),
          const SizedBox(height: 12),
          const DropdownMenu<String>(
            initialSelection: 'English',
            expandedInsets: EdgeInsets.zero,
            label: Text('Language'),
            dropdownMenuEntries: [
              DropdownMenuEntry(value: 'English', label: 'English'),
              DropdownMenuEntry(value: 'Filipino', label: 'Filipino'),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _selected
                ? () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ImportProgressPage(
                        title: _title.text,
                        author: _author.text,
                      ),
                    ),
                  )
                : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Book'),
          ),
        ],
      ),
    );
  }
}

class ImportProgressPage extends StatefulWidget {
  const ImportProgressPage({
    required this.title,
    required this.author,
    super.key,
  });

  final String title;
  final String author;

  @override
  State<ImportProgressPage> createState() => _ImportProgressPageState();
}

class _ImportProgressPageState extends State<ImportProgressPage> {
  double _progress = 0;
  BookData? _book;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _import());
  }

  Future<void> _import() async {
    for (final value in [0.2, 0.45, 0.7, 1.0]) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() => _progress = value);
    }
    final book = StoryTaleScope.of(
      context,
    ).addPrototypeBook(title: widget.title, author: widget.author);
    if (mounted) setState(() => _book = book);
  }

  @override
  Widget build(BuildContext context) {
    final done = _book != null;
    return StoryTaleAppShell(
      title: done ? 'Import Complete' : 'Importing EPUB',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              done ? Icons.check_circle_outline : Icons.auto_stories_outlined,
              size: 72,
            ),
            const SizedBox(height: 20),
            Text(
              done ? '${_book!.title} is ready.' : 'Reading EPUB metadata…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 24),
            if (done)
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const BookDetailsPage()),
                ),
                child: const Text('View Book'),
              ),
          ],
        ),
      ),
    );
  }
}
