import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/library/data/epub_import_service.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  const fixturePath =
      'docs/ui-concepts/ui/Mushoku_Tensei_-_Volume_09_Seven_Seas_Kobo.epub';
  final fixture = File(fixturePath);

  test(
    'parses the local Volume 9 EPUB into readable story chapters',
    () async {
      final book = await const EpubImportService().parse(
        await fixture.readAsBytes(),
        fileName: fixture.uri.pathSegments.last,
      );

      expect(book.title, 'Mushoku Tensei: Jobless Reincarnation Vol. 9');
      expect(book.author, 'Rifujin na Magonote');
      expect(book.language, 'English');
      expect(book.chapters, hasLength(15));
      expect(
        book.chapters.where((item) => item.type == ChapterType.chapter),
        hasLength(11),
      );
      expect(
        book.chapters.where((item) => item.type == ChapterType.sideStory),
        hasLength(3),
      );
      expect(
        book.chapters.where((item) => item.type == ChapterType.extra),
        hasLength(1),
      );
      expect(book.coverBytes, isNotEmpty);
      expect(book.chapters.first.sourceBlocks.first.id, endsWith('block-0001'));

      // The source cover is 1.9 MB; it is shrunk once at import so it fits
      // local storage and still draws as a thumbnail.
      expect(book.coverBytes!.lengthInBytes, lessThan(400 * 1024));

      final images = book.chapters.expand((item) => item.images).toList();
      // Seven interior illustrations sit inside chapters the table of contents
      // lists. Image-only pages outside the contents are not chapters, so
      // their artwork is not reachable yet.
      // The volume ships 16 images. One is the cover, and the other 15 are
      // reachable even though the colour gallery and front matter are missing
      // from the table of contents.
      expect(images, hasLength(15));

      // Artwork from unlisted pages is handed to the chapter it precedes, so
      // the colour gallery opens the first chapter.
      final opening = book.chapters.first.images;
      expect(opening.length, greaterThan(1));
      expect(opening.first.afterBlockIndex, 0);

      // The cover is not repeated as a chapter illustration.
      final coverLength = book.coverBytes!.lengthInBytes;
      expect(
        images.where((item) => item.bytes!.lengthInBytes == coverLength),
        isEmpty,
      );
      for (final illustration in images) {
        expect(illustration.isStored, isTrue);
        // Every source illustration is around 1 MB before shrinking.
        expect(illustration.bytes!.lengthInBytes, lessThan(250 * 1024));
        expect(illustration.id, contains('-image-'));
      }

      // Every illustration ID is unique and ordered within its chapter.
      for (final chapter in book.chapters) {
        final ids = chapter.images.map((item) => item.id).toList();
        expect(ids.toSet(), hasLength(ids.length));
        expect(ids, equals([...ids]..sort()));
      }

      final withImages = book.chapters.where((item) => item.images.isNotEmpty);
      for (final chapter in withImages) {
        for (final illustration in chapter.images) {
          // An illustration is anchored between the surrounding paragraphs.
          expect(illustration.afterBlockIndex, greaterThanOrEqualTo(0));
          expect(
            illustration.afterBlockIndex,
            lessThanOrEqualTo(chapter.sourceBlocks.length),
          );
        }
        // Story Mode's source-block contract stays untouched by artwork.
        expect(
          chapter.sourceBlocks.map((block) => block.id).toSet(),
          hasLength(chapter.sourceBlocks.length),
        );
      }
    },
    skip: fixture.existsSync() ? false : 'Local EPUB fixture is not available.',
  );

  test('rejects non-EPUB input', () async {
    expect(
      () => const EpubImportService().parse(
        Uint8List.fromList([1, 2, 3]),
        fileName: 'book.pdf',
      ),
      throwsA(isA<EpubImportException>()),
    );
  });
}
