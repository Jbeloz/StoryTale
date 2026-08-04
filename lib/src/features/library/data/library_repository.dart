import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/storytale_models.dart';

/// Progress, bookmarks, and cached translation for one chapter.
class ChapterReadingState {
  const ChapterReadingState({
    this.progress = 0,
    this.bookmarked = false,
    this.translatedText,
  });

  final double progress;
  final bool bookmarked;
  final String? translatedText;

  factory ChapterReadingState.fromJson(Map<String, dynamic> json) =>
      ChapterReadingState(
        progress: json['progress'] is num
            ? (json['progress'] as num).toDouble().clamp(0, 1)
            : 0,
        bookmarked: json['bookmarked'] == true,
        translatedText: json['translatedText'] is String
            ? json['translatedText'] as String
            : null,
      );

  Map<String, dynamic> toJson() => {
    'progress': progress,
    'bookmarked': bookmarked,
    if (translatedText != null) 'translatedText': translatedText,
  };
}

/// Everything that changes while reading. Kept apart from the imported book
/// records so frequent progress writes never rewrite whole chapter texts.
class LibraryReadingState {
  const LibraryReadingState({
    this.chapters = const {},
    this.bookProgress = const {},
    this.lastOpenedAt = const {},
    this.currentBookId,
    this.currentChapterId,
    this.readerSettings,
  });

  final Map<String, ChapterReadingState> chapters;
  final Map<String, double> bookProgress;
  final Map<String, DateTime> lastOpenedAt;
  final String? currentBookId;
  final String? currentChapterId;
  final ReaderSettingsData? readerSettings;

  static const empty = LibraryReadingState();

  factory LibraryReadingState.fromJson(Map<String, dynamic> json) {
    final chapters = <String, ChapterReadingState>{};
    final rawChapters = json['chapters'];
    if (rawChapters is Map) {
      for (final entry in rawChapters.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        chapters[entry.key as String] = ChapterReadingState.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    final bookProgress = <String, double>{};
    final rawProgress = json['bookProgress'];
    if (rawProgress is Map) {
      for (final entry in rawProgress.entries) {
        if (entry.key is! String || entry.value is! num) continue;
        bookProgress[entry.key as String] = (entry.value as num)
            .toDouble()
            .clamp(0, 1);
      }
    }

    final lastOpenedAt = <String, DateTime>{};
    final rawOpened = json['lastOpenedAt'];
    if (rawOpened is Map) {
      for (final entry in rawOpened.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final parsed = DateTime.tryParse(entry.value as String);
        if (parsed != null) lastOpenedAt[entry.key as String] = parsed;
      }
    }

    return LibraryReadingState(
      chapters: chapters,
      bookProgress: bookProgress,
      lastOpenedAt: lastOpenedAt,
      currentBookId: json['currentBookId'] is String
          ? json['currentBookId'] as String
          : null,
      currentChapterId: json['currentChapterId'] is String
          ? json['currentChapterId'] as String
          : null,
      readerSettings: json['readerSettings'] is Map
          ? ReaderSettingsData.fromJson(
              Map<String, dynamic>.from(json['readerSettings'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapters': chapters.map((key, value) => MapEntry(key, value.toJson())),
    'bookProgress': bookProgress,
    'lastOpenedAt': lastOpenedAt.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
    if (currentBookId != null) 'currentBookId': currentBookId,
    if (currentChapterId != null) 'currentChapterId': currentChapterId,
    if (readerSettings != null) 'readerSettings': readerSettings!.toJson(),
  };
}

/// Local store for the imported library.
///
/// This is the narrow Phase 8 slice that keeps imported books across restarts.
/// It deliberately stores parsed chapters rather than raw EPUB bytes: the web
/// preview keeps these values in browser local storage, which is only a few
/// megabytes and cannot hold whole EPUB files.
///
/// Reads never throw. Writes never throw either; a full store is reported
/// through [LibraryWriteResult] so the session can keep working.
class LibraryRepository {
  static const importedBooksKey = 'storytale.library.v1.imported_books';
  static const readingStateKey = 'storytale.library.v1.reading_state';

  Future<List<BookData>> loadImportedBooks() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(importedBooksKey);
    if (source == null) return const [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      final books = <BookData>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final book = BookData.fromJson(Map<String, dynamic>.from(entry));
        // A book with no ID or no chapters cannot be opened, so skip it
        // instead of showing a broken library row.
        if (book.id.isEmpty || book.chapters.isEmpty) continue;
        books.add(book);
      }
      return books;
    } catch (_) {
      return const [];
    }
  }

  Future<LibraryWriteResult> saveImportedBooks(List<BookData> books) {
    return _write(
      importedBooksKey,
      jsonEncode(books.map((book) => book.toJson()).toList(growable: false)),
    );
  }

  Future<LibraryReadingState> loadReadingState() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(readingStateKey);
    if (source == null) return LibraryReadingState.empty;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return LibraryReadingState.empty;
      return LibraryReadingState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return LibraryReadingState.empty;
    }
  }

  Future<LibraryWriteResult> saveReadingState(LibraryReadingState state) {
    return _write(readingStateKey, jsonEncode(state.toJson()));
  }

  Future<LibraryWriteResult> _write(String key, String value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(key, value);
      return saved
          ? LibraryWriteResult.saved
          : LibraryWriteResult.storageUnavailable;
    } catch (error) {
      // Browser local storage is small and can reject a large library. The
      // in-memory session must survive that, so report instead of throwing.
      debugPrint('StoryTale could not save $key: $error');
      return LibraryWriteResult.storageUnavailable;
    }
  }
}

enum LibraryWriteResult { saved, storageUnavailable }
