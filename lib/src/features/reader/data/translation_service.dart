import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/models/storytale_models.dart';

class TranslationException implements Exception {
  const TranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Translates chapter text through the local StoryTale admin server, which
/// holds the DeepL key and forwards the request.
///
/// The key deliberately never reaches this class. DeepL sends no CORS headers,
/// so a browser cannot call it directly, and a key shipped in the web bundle
/// would be readable by anyone. The proxy solves both.
class TranslationService {
  TranslationService({http.Client? client, String? endpoint})
    : _client = client ?? http.Client(),
      endpoint = (endpoint ?? _endpoint).replaceFirst(RegExp(r'/$'), '');

  static const _endpoint = String.fromEnvironment(
    'STORYTALE_TRANSLATE_URL',
    defaultValue: 'http://127.0.0.1:52828',
  );

  /// DeepL accepts up to 50 texts per request; the proxy enforces the same cap.
  static const batchSize = 50;

  /// DeepL's Tagalog target code. Filipino has no separate code.
  static const filipinoLangCode = 'TL';

  final http.Client _client;
  final String endpoint;

  /// Translates a chapter and returns the Filipino text.
  ///
  /// Source blocks are translated individually and rejoined with a blank line,
  /// which is how [ChapterData] rebuilds `originalText`, so paragraph structure
  /// survives the round trip.
  Future<String> translateChapter(
    ChapterData chapter, {
    String targetLang = filipinoLangCode,
  }) async {
    final paragraphs = _paragraphsOf(chapter);
    if (paragraphs.isEmpty) {
      throw const TranslationException(
        'This chapter has no text to translate.',
      );
    }

    final translated = <String>[];
    for (var start = 0; start < paragraphs.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, paragraphs.length);
      translated.addAll(
        await _translateBatch(paragraphs.sublist(start, end), targetLang),
      );
    }
    return translated.join('\n\n');
  }

  List<String> _paragraphsOf(ChapterData chapter) {
    final blocks = chapter.sourceBlocks
        .map((block) => block.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    if (blocks.isNotEmpty) return blocks;
    // Books imported before source blocks existed only carry originalText.
    return chapter.originalText
        .split(RegExp(r'\n{2,}'))
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> _translateBatch(
    List<String> texts,
    String targetLang,
  ) async {
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$endpoint/translate'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'texts': texts, 'targetLang': targetLang}),
      );
    } catch (_) {
      throw const TranslationException(
        'The translation service is not running. Start the app with '
        'tool/run_storytale.ps1 so the local DeepL proxy is available.',
      );
    }

    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) decoded = value;
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode != 200) {
      // Surface the real provider message rather than a generic failure.
      final detail = decoded?['error'];
      throw TranslationException(
        detail is String && detail.isNotEmpty
            ? detail
            : 'Translation failed with status ${response.statusCode}.',
      );
    }
    if (decoded == null) {
      throw const TranslationException(
        'The translation service sent an unreadable response.',
      );
    }

    final translations = (decoded['translations'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    if (translations.length != texts.length) {
      throw const TranslationException(
        'The translation service returned the wrong number of paragraphs.',
      );
    }
    return translations;
  }
}
