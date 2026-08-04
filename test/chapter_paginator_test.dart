import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/reader/data/chapter_paginator.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  // TextPainter needs the binding before it can measure.
  TestWidgetsFlutterBinding.ensureInitialized();

  const paginator = ChapterPaginator();
  const style = TextStyle(fontSize: 16, height: 1.5);
  const pageSize = Size(360, 480);

  ChapterData chapterOf({
    required int paragraphs,
    int words = 40,
    List<ChapterImageData> images = const [],
  }) {
    final blocks = List.generate(paragraphs, (index) {
      final text = List.generate(
        words,
        (word) => 'word${index}x$word',
      ).join(' ');
      return ChapterTextBlock(id: 'c-block-$index', text: text);
    });
    return ChapterData(
      id: 'c',
      title: 'Chapter',
      originalText: blocks.map((block) => block.text).join('\n\n'),
      sourceBlocks: blocks,
      images: images,
    );
  }

  ChapterImageData imageAt(int index, {String id = 'c-image-0001'}) =>
      ChapterImageData(
        id: id,
        afterBlockIndex: index,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

  /// Words only, so paragraph joining and trimming do not confuse the
  /// comparison. Nothing may be lost or repeated.
  List<String> wordsOf(String text) =>
      text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

  List<ChapterPage> paginate(ChapterData chapter, {Size size = pageSize}) =>
      paginator.paginate(
        items: ChapterPaginator.itemsFor(chapter),
        pageSize: size,
        style: style,
      );

  test('a long chapter becomes several pages', () {
    final pages = paginate(chapterOf(paragraphs: 40));
    expect(pages.length, greaterThan(1));
  });

  test('a short chapter is one page', () {
    final pages = paginate(chapterOf(paragraphs: 1, words: 5));
    expect(pages, hasLength(1));
    expect(pages.single.isImage, isFalse);
  });

  test('pagination loses and duplicates nothing', () {
    final chapter = chapterOf(paragraphs: 40);
    final pages = paginate(chapter);

    final paginated = pages
        .where((page) => !page.isImage)
        .expand((page) => wordsOf(page.text))
        .toList();
    expect(paginated, equals(wordsOf(chapter.originalText)));
  });

  test('every page fits inside the page height', () {
    final pages = paginate(chapterOf(paragraphs: 40));
    for (final page in pages) {
      if (page.isImage) continue;
      final painter = TextPainter(
        text: TextSpan(text: page.text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: pageSize.width);
      expect(
        painter.height,
        lessThanOrEqualTo(pageSize.height + 0.5),
        reason: 'a page overflowed its viewport',
      );
      painter.dispose();
    }
  });

  test('an illustration gets a page of its own, in place', () {
    final chapter = chapterOf(paragraphs: 3, words: 5, images: [imageAt(1)]);
    final pages = paginate(chapter);

    final imageIndex = pages.indexWhere((page) => page.isImage);
    expect(imageIndex, isNot(-1));
    expect(pages[imageIndex].text, isEmpty);
    expect(pages[imageIndex].image!.id, 'c-image-0001');
    // The first paragraph comes before it, the rest after.
    expect(pages[imageIndex - 1].text, contains('word0x0'));
    expect(pages[imageIndex + 1].text, contains('word1x0'));
  });

  test('several illustrations each get their own page', () {
    final chapter = chapterOf(
      paragraphs: 2,
      words: 5,
      images: [
        imageAt(0, id: 'c-image-0001'),
        imageAt(0, id: 'c-image-0002'),
      ],
    );
    final pages = paginate(chapter);
    expect(pages.where((page) => page.isImage), hasLength(2));
  });

  test('a paragraph taller than a page splits at a word boundary', () {
    final chapter = chapterOf(paragraphs: 1, words: 400);
    final pages = paginate(chapter);
    expect(pages.length, greaterThan(1));

    // No word may be cut in half.
    expect(
      pages.expand((page) => wordsOf(page.text)),
      equals(wordsOf(chapter.originalText)),
    );
  });

  test('a tiny viewport still terminates', () {
    final pages = paginate(
      chapterOf(paragraphs: 2, words: 20),
      size: const Size(40, 24),
    );
    expect(pages, isNotEmpty);
    expect(pages.length, lessThan(500));
  });

  test('an empty chapter produces no pages', () {
    final chapter = ChapterData(id: 'c', title: 'Empty', originalText: '');
    expect(paginate(chapter), isEmpty);
  });

  test('a zero-sized viewport produces no pages', () {
    expect(paginate(chapterOf(paragraphs: 2), size: Size.zero), isEmpty);
  });

  test('translated text paginates without illustrations', () {
    final chapter = chapterOf(paragraphs: 3, words: 20, images: [imageAt(1)]);
    final items = ChapterPaginator.itemsFor(
      chapter,
      includeImages: false,
      overrideText: 'Isinalin na teksto. ' * 50,
    );
    final pages = paginator.paginate(
      items: items,
      pageSize: pageSize,
      style: style,
    );
    expect(pages, isNotEmpty);
    expect(pages.every((page) => !page.isImage), isTrue);
  });

  test('a chapter without source blocks falls back to its text', () {
    final chapter = ChapterData(
      id: 'c',
      title: 'Demo',
      originalText: 'One paragraph only.',
    );
    final pages = paginate(chapter);
    expect(pages, hasLength(1));
    expect(pages.single.text, 'One paragraph only.');
  });
}
