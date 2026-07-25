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
    'repository replaces the same location state and keeps approval',
    () async {
      final repository = StoryBackgroundRepository();
      final pending = _asset(approved: false);
      await repository.save(pending);
      await repository.save(pending.copyWith(approved: true));

      final assets = await repository.load('book-1');

      expect(assets, hasLength(1));
      expect(assets.single.approved, isTrue);
      expect(assets.single.bytes, orderedEquals(Uint8List.fromList([1, 2, 3])));
    },
  );
}

StoryBackgroundAssetData _asset({required bool approved}) {
  return StoryBackgroundAssetData(
    assetId: 'background.book_1.garden.night',
    bookId: 'book-1',
    locationId: 'garden',
    stateId: 'night',
    prompt: 'A moonlit garden.',
    imageBase64: base64Encode([1, 2, 3]),
    createdAt: '2026-07-25T00:00:00.000Z',
    approved: approved,
  );
}
