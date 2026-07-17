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
