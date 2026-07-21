import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'sprite_references.dart';

class StoryArtworkService {
  StoryArtworkService({
    http.Client? client,
    AssetBundle? bundle,
    String? endpoint,
    String? token,
  }) : _client = client ?? http.Client(),
       _bundle = bundle ?? rootBundle,
       endpoint = endpoint ?? _endpoint,
       token = token ?? _token;

  static const _endpoint = String.fromEnvironment(
    'CLOUDFLARE_IMAGE_URL',
    defaultValue: 'https://storytale-image-worker.jbalejoshift0928.workers.dev',
  );
  static const _token = String.fromEnvironment('CLOUDFLARE_IMAGE_TOKEN');

  final http.Client _client;
  final AssetBundle _bundle;
  final String endpoint;
  final String token;

  bool get isConfigured => token.trim().isNotEmpty;

  Future<Uint8List> generateBackground(String sceneDetails) {
    final description = sceneDetails.trim().isEmpty
        ? 'a quiet storybook forest clearing at sunrise'
        : sceneDetails.trim();
    final prompt =
        'Create one polished 2D storybook background showing '
        '$description. Use a wide stage-like composition with clear foreground '
        'space for character sprites. No people, characters, text, speech '
        'bubbles, UI, border, or watermark.';
    return _generate(kind: 'background', prompt: prompt);
  }

  Future<Uint8List> generateSpriteMaster(String characterDetails) async {
    final description = characterDetails.trim().isEmpty
        ? 'a kind young storybook traveler in simple blue clothing'
        : characterDetails.trim();
    final files = <http.MultipartFile>[];
    for (var index = 0; index < spriteReferencePaths.length; index++) {
      final path = spriteReferencePaths[index];
      final data = await _bundle.load(path);
      files.add(
        http.MultipartFile.fromBytes(
          'input_image_$index',
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          filename: path.split('/').last,
        ),
      );
    }
    return _generate(kind: 'sprite', prompt: description, files: files);
  }

  Future<Uint8List> _generate({
    required String kind,
    required String prompt,
    List<http.MultipartFile> files = const [],
  }) async {
    if (!isConfigured) {
      throw const ArtworkGenerationException(
        'Add CLOUDFLARE_IMAGE_TOKEN to .env, then restart the app.',
      );
    }

    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$endpoint/generate?kind=$kind'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['prompt'] = prompt
          ..files.addAll(files);

    final response = await _client.send(request);
    final bytes = await response.stream.toBytes();
    if (response.statusCode != 200) {
      throw ArtworkGenerationException(
        _errorMessage(bytes, response.statusCode),
      );
    }
    return Uint8List.fromList(bytes);
  }

  String _errorMessage(List<int> bytes, int statusCode) {
    try {
      final body = jsonDecode(utf8.decode(bytes));
      if (body is Map && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {
      // The Worker may return a non-JSON platform error.
    }
    return 'Story artwork generation failed (HTTP $statusCode).';
  }
}

class ArtworkGenerationException implements Exception {
  const ArtworkGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
