import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/models/storytale_models.dart';
import 'story_analysis_contract.dart';
import 'story_bible_models.dart';

abstract interface class StoryEntityProvider {
  bool get isConfigured;

  Future<List<StoryEntityData>> extract({
    required BookData book,
    required ChapterData chapter,
    required BookStoryBibleData bible,
  });
}

class GeminiStoryEntityProvider implements StoryEntityProvider {
  GeminiStoryEntityProvider({
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
  Future<List<StoryEntityData>> extract({
    required BookData book,
    required ChapterData chapter,
    required BookStoryBibleData bible,
  }) async {
    if (!isConfigured) {
      throw const StoryAnalysisException(
        'Add CLOUDFLARE_IMAGE_TOKEN to .env, then rebuild the app.',
      );
    }
    final blocks = StoryAnalysisContract.blocksFor(chapter);
    final response = await _client.post(
      Uri.parse('$endpoint/entities'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'schemaVersion': 1,
        'book': {'id': book.id, 'title': book.title},
        'chapter': {
          'id': chapter.id,
          'title': chapter.title,
          'blocks': [
            for (final block in blocks) {'id': block.id, 'text': block.text},
          ],
        },
        'storyBible': {
          'entities': [
            for (final entity in bible.entities)
              {
                'entityId': entity.entityId,
                'kind': entity.kind.name,
                'canonicalName': entity.canonicalName,
                'aliases': entity.aliases,
                'approved': entity.approved,
                'lockedAppearance': entity.lockedAppearance,
              },
          ],
        },
      }),
    );
    if (response.statusCode != 200) {
      throw StoryAnalysisException(_errorMessage(response));
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map || body['entities'] is! List) {
        throw const FormatException('Expected an entity list.');
      }
      final entities = (body['entities'] as List<dynamic>)
          .map(
            (value) => StoryEntityData.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false);
      StoryEntityContract.validate(entities: entities, chapter: chapter);
      return entities
          .map(StoryEntityPolicy.applyAutomaticApproval)
          .toList(growable: false);
    } on StoryAnalysisException {
      rethrow;
    } catch (_) {
      throw const StoryAnalysisException(
        'Gemini returned invalid story entities.',
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
    return 'Entity extraction failed (HTTP ${response.statusCode}).';
  }
}

class StoryEntityContract {
  const StoryEntityContract._();

  static void validate({
    required List<StoryEntityData> entities,
    required ChapterData chapter,
  }) {
    if (entities.length > 40) {
      throw const StoryAnalysisException('Gemini returned too many entities.');
    }
    final blockIds = StoryAnalysisContract.blocksFor(
      chapter,
    ).map((block) => block.id).toSet();
    final entityIds = <String>{};
    for (final entity in entities) {
      if (entity.entityId.trim().isEmpty ||
          entity.canonicalName.trim().isEmpty ||
          entity.firstSeenChapterId != chapter.id ||
          !entityIds.add(entity.entityId) ||
          entity.approved ||
          entity.lockedAppearance ||
          entity.assetIds.isNotEmpty ||
          entity.confidence < 0 ||
          entity.confidence > 1 ||
          entity.sourceBlockIds.isEmpty ||
          entity.sourceBlockIds.any((id) => !blockIds.contains(id))) {
        throw const StoryAnalysisException(
          'Gemini returned unsafe story entities.',
        );
      }
    }
  }
}
