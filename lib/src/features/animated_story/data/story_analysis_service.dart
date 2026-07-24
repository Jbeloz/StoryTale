import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/models/storytale_models.dart';
import 'story_analysis_contract.dart';

abstract interface class StoryAnalysisProvider {
  bool get isConfigured;

  Future<ChapterStoryData> analyze({
    required ChapterData chapter,
    required StoryAnalysisCatalog catalog,
  });
}

class GeminiStoryAnalysisProvider implements StoryAnalysisProvider {
  GeminiStoryAnalysisProvider({
    http.Client? client,
    String? endpoint,
    String? token,
  }) : _client = client ?? http.Client(),
       endpoint = (endpoint ?? _endpoint).replaceFirst(RegExp(r'/$'), ''),
       token = token ?? _token;

  static const _endpoint = String.fromEnvironment(
    'CLOUDFLARE_IMAGE_URL',
    defaultValue: 'https://storytale-image-worker.jbalejoshift0928.workers.dev',
  );
  static const _token = String.fromEnvironment('CLOUDFLARE_IMAGE_TOKEN');

  final http.Client _client;
  final String endpoint;
  final String token;

  @override
  bool get isConfigured => token.trim().isNotEmpty;

  @override
  Future<ChapterStoryData> analyze({
    required ChapterData chapter,
    required StoryAnalysisCatalog catalog,
  }) async {
    if (!isConfigured) {
      throw const StoryAnalysisException(
        'Add CLOUDFLARE_IMAGE_TOKEN to .env, then rebuild the app.',
      );
    }
    final blocks = StoryAnalysisContract.blocksFor(chapter);
    final response = await _client.post(
      Uri.parse('$endpoint/analyze'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'schemaVersion': 1,
        'chapter': {
          'id': chapter.id,
          'title': chapter.title,
          'blocks': [
            for (final block in blocks) {'id': block.id, 'text': block.text},
          ],
        },
        'catalog': catalog.toJson(),
      }),
    );
    if (response.statusCode != 200) {
      throw StoryAnalysisException(_errorMessage(response));
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map) {
        throw const FormatException('Expected a JSON object.');
      }
      final story = ChapterStoryData.fromJson(Map<String, dynamic>.from(body));
      StoryAnalysisContract.validate(
        story: story,
        chapter: chapter,
        catalog: catalog,
      );
      return story;
    } on StoryAnalysisException {
      rethrow;
    } catch (_) {
      throw const StoryAnalysisException(
        'Gemini returned an invalid chapter plan.',
      );
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {
      // The Worker may return a non-JSON platform error.
    }
    return 'Story analysis failed (HTTP ${response.statusCode}).';
  }
}
