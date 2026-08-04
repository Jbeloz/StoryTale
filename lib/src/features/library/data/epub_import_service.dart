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
      final imageIndex = _imageIndex(epub);
      final coverKey = _coverKey(imageIndex);
      final chapters = _chapters(epub, id, imageIndex, coverKey);
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
        coverBytes: coverKey == null
            ? null
            // EPUB covers are print resolution; the reader only ever draws a
            // thumbnail, and the full size does not fit local storage.
            : const ReaderImageCodec().shrinkCover(
                imageIndex[coverKey]?.Content,
              ),
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

  List<ChapterData> _chapters(
    EpubBook epub,
    String bookId,
    Map<String, EpubByteContentFile> imageIndex,
    String? coverKey,
  ) {
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

    final shrunk = <String, Uint8List?>{};
    final result = <ChapterData>[];
    // The page each kept chapter came from, so spine pages that no chapter
    // owns can be matched against it below.
    final chapterFiles = <String>[];

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
        final artwork = _artwork(reference, imageIndex, shrunk, coverKey);
        if (artwork == null) continue;
        images.add(
          ChapterImageData(
            id: '$chapterId-image-0000',
            afterBlockIndex: reference.afterBlockIndex,
            bytes: artwork.bytes,
            alt: artwork.alt,
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
      chapterFiles.add(_basename(chapter.ContentFileName ?? ''));
    }

    _attachUnlistedArtwork(
      epub,
      result,
      chapterFiles,
      imageIndex,
      shrunk,
      coverKey,
    );
    _numberImages(result);
    return result;
  }

  /// Recovers artwork from pages the table of contents does not list.
  ///
  /// Chapters come from the EPUB navigation, but colour galleries and other
  /// illustration pages are usually missing from it, so their artwork would be
  /// lost. Walking the spine — the real page order — those images are handed to
  /// the chapter that follows them, which is where a reader meets them anyway.
  /// Chapter identity, IDs, and source blocks are untouched.
  void _attachUnlistedArtwork(
    EpubBook epub,
    List<ChapterData> chapters,
    List<String> chapterFiles,
    Map<String, EpubByteContentFile> imageIndex,
    Map<String, Uint8List?> shrunk,
    String? coverKey,
  ) {
    if (chapters.isEmpty) return;
    final htmlIndex = _htmlIndex(epub);
    final owned = chapterFiles.where((file) => file.isNotEmpty).toSet();
    final pending = <_Artwork>[];

    void flushInto(ChapterData chapter, int afterBlockIndex, bool atTop) {
      if (pending.isEmpty) return;
      final recovered = pending
          .map(
            (artwork) => ChapterImageData(
              id: '${chapter.id}-image-0000',
              afterBlockIndex: afterBlockIndex,
              bytes: artwork.bytes,
              alt: artwork.alt,
            ),
          )
          .toList(growable: false);
      chapter.images.insertAll(atTop ? 0 : chapter.images.length, recovered);
      pending.clear();
    }

    for (final file in _spineFiles(epub)) {
      final ownerIndex = chapterFiles.indexOf(file);
      if (ownerIndex != -1) {
        // The gallery belongs above the text of the chapter it precedes.
        flushInto(chapters[ownerIndex], 0, true);
        continue;
      }
      if (owned.contains(file)) continue;

      final source = htmlIndex[file];
      if (source == null || source.trim().isEmpty) continue;
      for (final reference in _sectionContent(source).images) {
        final artwork = _artwork(reference, imageIndex, shrunk, coverKey);
        if (artwork != null) pending.add(artwork);
      }
    }

    // Artwork after the last listed chapter still belongs to the book.
    final last = chapters.last;
    flushInto(last, last.sourceBlocks.length, false);
  }

  _Artwork? _artwork(
    _ImageReference reference,
    Map<String, EpubByteContentFile> imageIndex,
    Map<String, Uint8List?> shrunk,
    String? coverKey,
  ) {
    final key = _basename(reference.href);
    // The cover already has its own slot; it is not a chapter illustration.
    if (key == coverKey) return null;
    final source = imageIndex[key];
    if (source == null) return null;
    final bytes = shrunk.putIfAbsent(
      key,
      () => const ReaderImageCodec().shrinkIllustration(source.Content),
    );
    if (bytes == null || bytes.isEmpty) return null;
    return _Artwork(bytes: bytes, alt: reference.alt);
  }

  /// Gives every illustration a stable, ordered ID once its chapter is final.
  void _numberImages(List<ChapterData> chapters) {
    for (final chapter in chapters) {
      final ordered = [...chapter.images]
        ..sort((a, b) => a.afterBlockIndex.compareTo(b.afterBlockIndex));
      chapter.images
        ..clear()
        ..addAll(
          ordered.indexed.map(
            (entry) => ChapterImageData(
              id:
                  '${chapter.id}-image-'
                  '${(entry.$1 + 1).toString().padLeft(4, '0')}',
              afterBlockIndex: entry.$2.afterBlockIndex,
              bytes: entry.$2.bytes,
              alt: entry.$2.alt,
            ),
          ),
        );
    }
  }

  /// The book's real page order, which includes pages the contents omit.
  List<String> _spineFiles(EpubBook epub) {
    final package = epub.Schema?.Package;
    final hrefById = <String, String>{};
    for (final item in package?.Manifest?.Items ?? const []) {
      final id = item.Id;
      final href = item.Href;
      if (id != null && href != null && href.isNotEmpty) hrefById[id] = href;
    }

    final files = <String>[];
    for (final reference in package?.Spine?.Items ?? const []) {
      final href = hrefById[reference.IdRef ?? ''];
      if (href == null || href.isEmpty) continue;
      files.add(_basename(href));
    }
    return files;
  }

  Map<String, String> _htmlIndex(EpubBook epub) {
    final result = <String, String>{};
    final files = epub.Content?.Html ?? const <String, EpubTextContentFile>{};
    for (final entry in files.entries) {
      final content = entry.value.Content;
      if (content == null || content.isEmpty) continue;
      result.putIfAbsent(_basename(entry.key), () => content);
      final fileName = entry.value.FileName;
      if (fileName != null && fileName.isNotEmpty) {
        result.putIfAbsent(_basename(fileName), () => content);
      }
    }
    return result;
  }

  String? _coverKey(Map<String, EpubByteContentFile> imageIndex) {
    for (final entry in imageIndex.entries) {
      final content = entry.value.Content;
      if (entry.key.contains('cover') &&
          content != null &&
          content.isNotEmpty) {
        return entry.key;
      }
    }
    return null;
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

/// One resolved and shrunk illustration, before it is placed in a chapter.
class _Artwork {
  const _Artwork({required this.bytes, required this.alt});

  final Uint8List bytes;
  final String alt;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
