import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../../shared/widgets/storytale_image_placeholder.dart';
import '../data/epub_import_service.dart';
import 'library_page.dart';

class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _parser = const EpubImportService();

  BookData? _book;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  Future<void> _selectEpub() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      withData: true,
    );
    if (result == null || !mounted) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'The selected EPUB could not be loaded.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _book = null;
    });
    try {
      final book = await _parser.parse(bytes, fileName: file.name);
      if (!mounted) return;
      setState(() {
        _book = book;
        _title.text = book.title;
        _author.text = book.author;
      });
    } on EpubImportException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    final book = _book;
    if (book == null) return;
    book
      ..title = _title.text.trim().isEmpty ? book.title : _title.text.trim()
      ..author = _author.text.trim().isEmpty
          ? 'Unknown author'
          : _author.text.trim();
    StoryTaleScope.of(context).addImportedBook(book);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BookDetailsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return StoryTaleAppShell(
      title: 'Add EPUB',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StoryTaleImagePlaceholder(
            path: book == null ? 'assets/images/ui/epub_upload.png' : null,
            bytes: book?.coverBytes,
            label: book == null
                ? 'EPUB upload illustration placeholder'
                : '${book.title} cover',
            icon: Icons.upload_file,
            height: 170,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : _selectEpub,
            icon: const Icon(Icons.folder_open),
            label: Text(book?.sourceFileName ?? 'Select EPUB File'),
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const Text('Reading EPUB metadata and chapters...'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (book != null) ...[
            const SizedBox(height: 12),
            Text('${book.chapters.length} readable chapters found'),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            enabled: book != null,
            decoration: const InputDecoration(labelText: 'Book title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _author,
            enabled: book != null,
            decoration: const InputDecoration(labelText: 'Author'),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Language'),
            child: Text(book?.language ?? 'Read from the EPUB'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: book == null || _loading ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Book'),
          ),
        ],
      ),
    );
  }
}
