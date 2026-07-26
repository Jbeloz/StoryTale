import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/features/animated_story/data/story_background_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('background asset ID is stable for one location state', () {
    expect(
      StoryBackgroundAssetData.stableId(
        bookId: 'The Little Prince',
        locationId: 'Prince Home',
        stateId: 'Moonlit Night',
      ),
      'background.the_little_prince.prince_home.moonlit_night',
    );
  });

  test(
    'candidate replacement keeps the approved background until accepted',
    () async {
      final repository = StoryBackgroundRepository();
      final approved = _asset(approved: true);
      final candidate = _asset(
        approved: false,
        assetId: 'background.book_1.garden.night.candidate.1',
      );
      await repository.save(approved);
      await repository.saveCandidate(candidate);

      var assets = await repository.load('book-1');
      expect(assets, hasLength(2));
      expect(assets.where((asset) => asset.approved), hasLength(1));

      await repository.rejectCandidate(candidate);
      assets = await repository.load('book-1');
      expect(assets, hasLength(1));
      expect(assets.single.approved, isTrue);
      expect(assets.single.bytes, orderedEquals(Uint8List.fromList([1, 2, 3])));
    },
  );

  test('approving a candidate promotes it to the stable asset ID', () async {
    final repository = StoryBackgroundRepository();
    final candidate = _asset(
      approved: false,
      assetId: 'background.book_1.garden.night.candidate.2',
    );

    await repository.saveCandidate(candidate);
    final assets = await repository.approveCandidate(candidate);

    expect(assets, hasLength(1));
    expect(assets.single.approved, isTrue);
    expect(assets.single.assetId, 'background.book_1.garden.night');
  });

  test('legacy assets without dimensions are not treated as landscape', () {
    final legacy = StoryBackgroundAssetData.fromJson({
      'assetId': 'legacy',
      'bookId': 'book-1',
      'locationId': 'garden',
      'stateId': 'night',
      'imageBase64': base64Encode([1, 2, 3]),
      'approved': true,
    });

    expect(legacy.isVisualNovelSize, isFalse);
  });
}

StoryBackgroundAssetData _asset({
  required bool approved,
  String assetId = 'background.book_1.garden.night',
}) {
  return StoryBackgroundAssetData(
    assetId: assetId,
    bookId: 'book-1',
    locationId: 'garden',
    stateId: 'night',
    prompt: 'A moonlit garden.',
    imageBase64: base64Encode([1, 2, 3]),
    createdAt: '2026-07-25T00:00:00.000Z',
    approved: approved,
  );
}
