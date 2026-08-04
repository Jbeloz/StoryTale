import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../../../shared/models/storytale_models.dart';
import 'reader_image_codec.dart';

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
      final chapters = _chapters(epub, id);
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

  List<ChapterData> _chapters(EpubBook epub, String bookId) {
    final flat = <EpubChapter>[];

    void addChapter(EpubChapter chapter) {
      if ((chapter.HtmlContent ?? '').trim().isNotEmpty) flat.add(chapter);
      for (final child in chapter.SubChapters ?? const <EpubChapter>[]) {
        addChapter(child);
      }
    }

    for (final chapter in epub.Chapters ?? const <EpubChapter>[]) {
      addChapter(chapter);
    }

    final imageIndex = _imageIndex(epub);
    final shrunk = <String, Uint8List?>{};

    final result = <ChapterData>[];
    for (final chapter in flat) {
      final title = _valueOr(chapter.Title, 'Chapter ${result.length + 1}');
      if (_isFrontOrBackMatter(title)) continue;

      final content = _sectionContent(chapter.HtmlContent ?? '');
      // A short section is normally front or back matter, but an illustration
      // page such as a colour gallery carries almost no text and must be kept.
      if (content.blocks.join(' ').length < 80 && content.images.isEmpty) {
        continue;
      }

      final chapterId = '$bookId-chapter-${result.length + 1}';
      final sourceBlocks = List.generate(
        content.blocks.length,
        (index) => ChapterTextBlock(
          id: '$chapterId-block-${(index + 1).toString().padLeft(4, '0')}',
          text: content.blocks[index],
        ),
      );

      final images = <ChapterImageData>[];
      for (final reference in content.images) {
        final key = _basename(reference.href);
        final source = imageIndex[key];
        if (source == null) continue;
        final bytes = shrunk.putIfAbsent(
          key,
          () => const ReaderImageCodec().shrinkIllustration(source.Content),
        );
        if (bytes == null || bytes.isEmpty) continue;
        images.add(
          ChapterImageData(
            id:
                '$chapterId-image-'
                '${(images.length + 1).toString().padLeft(4, '0')}',
            afterBlockIndex: reference.afterBlockIndex,
            bytes: bytes,
            alt: reference.alt,
          ),
        );
      }

      result.add(
        ChapterData(
          id: chapterId,
          title: title,
          type: _chapterType(title),
          originalText: content.blocks.join('\n\n'),
          sourceBlocks: sourceBlocks,
          images: images,
        ),
      );
    }
    return result;
  }

  /// Reads one section in document order so illustrations keep their place
  /// between the surrounding paragraphs.
  _SectionContent _sectionContent(String source) {
    final fragment = html.parseFragment(source);
    for (final element in fragment.querySelectorAll('script, style, nav')) {
      element.remove();
    }

    final blocks = <String>[];
    final images = <_ImageReference>[];
    for (final element in fragment.querySelectorAll(
      'h1, h2, h3, h4, h5, h6, p, blockquote, li, img, image',
    )) {
      final name = element.localName?.toLowerCase();
      if (name == 'img' || name == 'image') {
        final href = _imageHref(element);
        if (href.isEmpty) continue;
        images.add(
          _ImageReference(
            href: href,
            afterBlockIndex: blocks.length,
            alt: _normalize(element.attributes['alt'] ?? ''),
          ),
        );
        continue;
      }
      final text = _normalize(element.text);
      // Skip empties and the repeated text of a nested element.
      if (text.isEmpty || (blocks.isNotEmpty && blocks.last == text)) continue;
      blocks.add(text);
    }

    if (blocks.isEmpty && images.isEmpty) {
      final text = _normalize(fragment.text ?? '');
      return _SectionContent(text.isEmpty ? const [] : [text], const []);
    }
    return _SectionContent(blocks, images);
  }

  String _imageHref(dom.Element element) {
    for (final name in const ['src', 'xlink:href', 'href']) {
      final value = element.attributes[name];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// EPUB chapters reference images with relative paths such as
  /// `../Images/Foo.jpg`, so they are matched on file name alone.
  Map<String, EpubByteContentFile> _imageIndex(EpubBook epub) {
    final result = <String, EpubByteContentFile>{};
    final images =
        epub.Content?.Images ?? const <String, EpubByteContentFile>{};
    for (final entry in images.entries) {
      result.putIfAbsent(_basename(entry.key), () => entry.value);
      final fileName = entry.value.FileName;
      if (fileName != null && fileName.isNotEmpty) {
        result.putIfAbsent(_basename(fileName), () => entry.value);
      }
    }
    return result;
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    final name = index == -1 ? normalized : normalized.substring(index + 1);
    try {
      return Uri.decodeComponent(name).toLowerCase();
    } catch (_) {
      return name.toLowerCase();
    }
  }

  Uint8List? _coverBytes(EpubBook epub) {
    final images =
        epub.Content?.Images ?? const <String, EpubByteContentFile>{};
    for (final entry in images.entries) {
      final name = '${entry.key} ${entry.value.FileName}'.toLowerCase();
      final content = entry.value.Content;
      if (name.contains('cover') && content != null && content.isNotEmpty) {
        // EPUB covers are print resolution; the reader only ever draws a
        // thumbnail, and the full size does not fit local storage.
        return const ReaderImageCodec().shrinkCover(content);
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

class _SectionContent {
  const _SectionContent(this.blocks, this.images);

  final List<String> blocks;
  final List<_ImageReference> images;
}

class _ImageReference {
  const _ImageReference({
    required this.href,
    required this.afterBlockIndex,
    required this.alt,
  });

  final String href;
  final int afterBlockIndex;
  final String alt;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
