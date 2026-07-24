import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'story_bible_models.dart';

class StoryBibleRepository {
  static const _keyPrefix = 'storytale.story_bible.v1.';

  Future<BookStoryBibleData> load(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString('$_keyPrefix$bookId');
    if (source == null) return BookStoryBibleData.empty(bookId);
    try {
      final bible = BookStoryBibleData.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
      return bible.bookId == bookId ? bible : BookStoryBibleData.empty(bookId);
    } catch (_) {
      return BookStoryBibleData.empty(bookId);
    }
  }

  Future<void> save(BookStoryBibleData bible) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix${bible.bookId}',
      jsonEncode(bible.toJson()),
    );
  }
}
