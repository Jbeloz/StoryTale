import 'package:flutter/widgets.dart';

import '../../../shared/models/storytale_models.dart';

/// One laid-out page of a chapter: either a run of text or a single
/// illustration.
class ChapterPage {
  const ChapterPage.text(this.text) : image = null;
  const ChapterPage.illustration(ChapterImageData this.image) : text = '';

  final String text;
  final ChapterImageData? image;

  bool get isImage => image != null;
}

/// One item of chapter content in reading order.
class ChapterItem {
  const ChapterItem.text(String this.text) : image = null;
  const ChapterItem.illustration(ChapterImageData this.image) : text = null;

  final String? text;
  final ChapterImageData? image;
}

/// Splits a chapter into fixed pages that fit a given viewport.
///
/// Chapters here reach tens of thousands of characters, so this packs whole
/// paragraphs — the source blocks the importer already produced — instead of
/// re-measuring the entire remaining chapter for every page. A paragraph is
/// only split when it alone is taller than a page.
///
/// Pagination never loses or duplicates text: concatenating the text of every
/// page reproduces the chapter exactly.
class ChapterPaginator {
  const ChapterPaginator();

  /// Paragraphs are rejoined with this, matching how the importer builds
  /// `originalText`.
  static const paragraphSeparator = '\n\n';

  /// Builds the reading-order items for a chapter.
  ///
  /// [ChapterImageData.afterBlockIndex] is how many text blocks precede an
  /// illustration, which is the same ordering the scrolling reader uses.
  static List<ChapterItem> itemsFor(
    ChapterData chapter, {
    bool includeImages = true,
    String? overrideText,
  }) {
    if (overrideText != null || chapter.sourceBlocks.isEmpty) {
      final text = overrideText ?? chapter.originalText;
      return [if (text.trim().isNotEmpty) ChapterItem.text(text)];
    }

    final items = <ChapterItem>[];
    for (var index = 0; index <= chapter.sourceBlocks.length; index++) {
      if (includeImages) {
        for (final image in chapter.images) {
          if (image.afterBlockIndex != index) continue;
          items.add(ChapterItem.illustration(image));
        }
      }
      if (index < chapter.sourceBlocks.length) {
        items.add(ChapterItem.text(chapter.sourceBlocks[index].text));
      }
    }
    return items;
  }

  List<ChapterPage> paginate({
    required List<ChapterItem> items,
    required Size pageSize,
    required TextStyle style,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final width = pageSize.width;
    final height = pageSize.height;
    if (width <= 0 || height <= 0) return const [];

    final pages = <ChapterPage>[];
    final current = <String>[];

    void flush() {
      if (current.isEmpty) return;
      pages.add(ChapterPage.text(current.join(paragraphSeparator)));
      current.clear();
    }

    double heightOf(String text) =>
        _measure(text, width: width, style: style, direction: textDirection);

    for (final item in items) {
      final image = item.image;
      if (image != null) {
        // An illustration owns its page, so it is always fully visible.
        flush();
        pages.add(ChapterPage.illustration(image));
        continue;
      }

      var remaining = item.text ?? '';
      if (remaining.isEmpty) continue;

      while (remaining.isNotEmpty) {
        final candidate = [...current, remaining].join(paragraphSeparator);
        if (heightOf(candidate) <= height) {
          current.add(remaining);
          break;
        }

        // The paragraph does not fit beside what is already on this page.
        if (current.isNotEmpty) {
          flush();
          continue;
        }

        // It does not fit on a page of its own either, so split it.
        final breakAt = _breakPoint(
          remaining,
          width: width,
          height: height,
          style: style,
          direction: textDirection,
        );
        pages.add(
          ChapterPage.text(remaining.substring(0, breakAt).trimRight()),
        );
        remaining = remaining.substring(breakAt).trimLeft();
      }
    }

    flush();
    return pages;
  }

  double _measure(
    String text, {
    required double width,
    required TextStyle style,
    required TextDirection direction,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
    )..layout(maxWidth: width);
    final result = painter.height;
    painter.dispose();
    return result;
  }

  /// The character index where [text] stops fitting a page.
  ///
  /// Always returns at least one character so an impossibly small viewport
  /// cannot loop forever.
  int _breakPoint(
    String text, {
    required double width,
    required double height,
    required TextStyle style,
    required TextDirection direction,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
    )..layout(maxWidth: width);

    final position = painter.getPositionForOffset(Offset(0, height));
    painter.dispose();

    var index = position.offset.clamp(1, text.length);
    if (index >= text.length) return text.length;

    // Step back to a word boundary so no word is cut in half.
    final wordStart = text.lastIndexOf(RegExp(r'\s'), index);
    if (wordStart > 0) index = wordStart;
    return index.clamp(1, text.length);
  }
}
