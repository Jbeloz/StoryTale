import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html;

import '../../../shared/models/storytale_models.dart';

class EpubImportException implements Exception {
  const EpubImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EpubImportService {
  const EpubImportService();

  Future<BookData> parse(Uint8List bytes, {required String fileName}) async {
    if (!fileName.toLowerCase().endsWith('.epub')) {
      throw const EpubImportException('Please choose an .epub file.');
    }
    if (bytes.isEmpty || bytes.length > 100 * 1024 * 1024) {
      throw const EpubImportException(
        'The EPUB is empty or larger than 100 MB.',
      );
    }

    try {
      final epub = await EpubReader.readBook(bytes);
      final metadata = epub.Schema?.Package?.Metadata;
      final id = 'book-${DateTime.now().microsecondsSinceEpoch}';
      final chapters = _chapters(epub.Chapters ?? const [], id);
      if (chapters.isEmpty) {
        throw const EpubImportException(
          'No readable story chapters were found in this EPUB.',
        );
      }

      final languageCode = metadata?.Languages?.firstOrNull ?? 'en';
      final description = _plainText(metadata?.Description ?? '');
      final subjects = metadata?.Subjects ?? const <String>[];
      return BookData(
        id: id,
        title: _valueOr(epub.Title, _fileTitle(fileName)),
        author: _valueOr(epub.Author, 'Unknown author'),
        language: _languageName(languageCode),
        description: description.isEmpty
            ? 'Imported locally from $fileName.'
            : description,
        tags: ['Imported', ...subjects.take(4)],
        chapters: chapters,
        coverBytes: _coverBytes(epub),
        sourceFileName: fileName,
      );
    } on EpubImportException {
      rethrow;
    } catch (_) {
      throw const EpubImportException(
        'This EPUB could not be read. It may be invalid or protected.',
      );
    }
  }

  List<ChapterData> _chapters(List<EpubChapter> source, String bookId) {
    final flat = <EpubChapter>[];

    void addChapter(EpubChapter chapter) {
      if ((chapter.HtmlContent ?? '').trim().isNotEmpty) flat.add(chapter);
      for (final child in chapter.SubChapters ?? const <EpubChapter>[]) {
        addChapter(child);
      }
    }

    for (final chapter in source) {
      addChapter(chapter);
    }

    final result = <ChapterData>[];
    for (final chapter in flat) {
      final title = _valueOr(chapter.Title, 'Chapter ${result.length + 1}');
      final blocks = _textBlocks(chapter.HtmlContent ?? '');
      if (_isFrontOrBackMatter(title) || blocks.join(' ').length < 80) continue;

      final chapterId = '$bookId-chapter-${result.length + 1}';
      final sourceBlocks = List.generate(
        blocks.length,
        (index) => ChapterTextBlock(
          id: '$chapterId-block-${(index + 1).toString().padLeft(4, '0')}',
          text: blocks[index],
        ),
      );
      result.add(
        ChapterData(
          id: chapterId,
          title: title,
          type: _chapterType(title),
          originalText: blocks.join('\n\n'),
          sourceBlocks: sourceBlocks,
        ),
      );
    }
    return result;
  }

  List<String> _textBlocks(String source) {
    final fragment = html.parseFragment(source);
    for (final element in fragment.querySelectorAll('script, style, nav')) {
      element.remove();
    }

    final blocks = fragment
        .querySelectorAll('h1, h2, h3, h4, h5, h6, p, blockquote, li')
        .map((element) => _normalize(element.text))
        .where((text) => text.isNotEmpty)
        .toList();
    if (blocks.isEmpty) {
      final text = _normalize(fragment.text ?? '');
      return text.isEmpty ? const [] : [text];
    }

    final unique = <String>[];
    for (final block in blocks) {
      if (unique.isEmpty || unique.last != block) unique.add(block);
    }
    return unique;
  }

  Uint8List? _coverBytes(EpubBook epub) {
    final images =
        epub.Content?.Images ?? const <String, EpubByteContentFile>{};
    for (final entry in images.entries) {
      final name = '${entry.key} ${entry.value.FileName}'.toLowerCase();
      final content = entry.value.Content;
      if (name.contains('cover') && content != null && content.isNotEmpty) {
        return Uint8List.fromList(content);
      }
    }
    return null;
  }

  bool _isFrontOrBackMatter(String title) => RegExp(
    r'^(cover|color inserts?|title page|copyright|credits?|contents|table of contents|about the author|newsletter|acknowledg|dedication|front matter)',
    caseSensitive: false,
  ).hasMatch(title.trim());

  ChapterType _chapterType(String title) {
    final value = title.toLowerCase();
    if (value.startsWith('side story')) return ChapterType.sideStory;
    if (value.startsWith('extra')) return ChapterType.extra;
    if (value.startsWith('prologue')) return ChapterType.prologue;
    if (value.startsWith('epilogue')) return ChapterType.epilogue;
    if (value.startsWith('chapter')) return ChapterType.chapter;
    return ChapterType.other;
  }

  String _plainText(String source) =>
      _normalize(html.parseFragment(source).text ?? '');

  String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _valueOr(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _fileTitle(String fileName) => fileName
      .replaceFirst(RegExp(r'\.epub$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();

  String _languageName(String code) => switch (code.toLowerCase()) {
    'en' || 'eng' => 'English',
    'tl' || 'fil' => 'Filipino',
    _ => code.toUpperCase(),
  };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
