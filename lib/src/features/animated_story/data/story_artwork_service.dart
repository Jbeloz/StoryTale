import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;

import 'sprite_references.dart';
import 'sprite_layer_processor.dart';
import 'story_foreground_repository.dart';
import 'visual_novel_background_brief.dart';

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
  String get spriteProvider => 'Google Gemini';
  String get spriteModel => 'gemini-3.1-flash-image';

  Future<GeneratedBackgroundData> generateBackground(
    VisualNovelBackgroundBrief brief,
  ) async {
    final prompt = const VisualNovelBackgroundPromptBuilder().build(brief);
    final result = await _generate(kind: 'background', prompt: prompt);
    final decoded = image.decodeImage(result.bytes);
    if (decoded == null) {
      throw const ArtworkGenerationException(
        'Cloudflare returned a corrupt background image.',
      );
    }
    if (decoded.width != 1024 || decoded.height != 576) {
      throw ArtworkGenerationException(
        'The background was ${decoded.width}x${decoded.height}; '
        'StoryTale requires exactly 1024x576.',
      );
    }
    return GeneratedBackgroundData(
      bytes: result.bytes,
      mimeType: result.mimeType,
      width: decoded.width,
      height: decoded.height,
      prompt: prompt,
    );
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
    return (await _generate(
      kind: 'sprite',
      prompt: description,
      files: files,
    )).bytes;
  }

  Future<GeneratedForegroundData> generateForeground(
    StoryForegroundAssetData asset,
  ) async {
    final prompt = _foregroundPrompt(asset);
    final result = await _generate(
      kind: 'sprite',
      mode: 'foreground',
      prompt: prompt,
    );
    final bytes = const SpriteLayerProcessor().removeMagentaBackground(
      result.bytes,
    );
    final decoded = image.decodeImage(bytes);
    if (decoded == null) {
      throw const ArtworkGenerationException(
        'Gemini returned a corrupt foreground image.',
      );
    }
    return GeneratedForegroundData(
      bytes: bytes,
      mimeType: 'image/png',
      width: decoded.width,
      height: decoded.height,
      prompt: prompt,
    );
  }

  Future<_WorkerImage> _generate({
    required String kind,
    required String prompt,
    String? mode,
    List<http.MultipartFile> files = const [],
  }) async {
    if (!isConfigured) {
      throw const ArtworkGenerationException(
        'Add CLOUDFLARE_IMAGE_TOKEN to .env, then restart the app.',
      );
    }

    final uri = Uri.parse(
      '$endpoint/generate',
    ).replace(queryParameters: {'kind': kind, if (mode != null) 'mode': mode});
    final request = http.MultipartRequest('POST', uri)
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
    final mimeType =
        response.headers['content-type']?.split(';').first.trim() ??
        'application/octet-stream';
    if (!const {'image/png', 'image/jpeg', 'image/webp'}.contains(mimeType)) {
      throw ArtworkGenerationException(
        'The image service returned an unsupported file type: $mimeType.',
      );
    }
    return _WorkerImage(Uint8List.fromList(bytes), mimeType);
  }

  String _foregroundPrompt(StoryForegroundAssetData asset) {
    final variant = asset.variantId.replaceAll('_', ' ');
    final description = asset.description.trim().isEmpty
        ? asset.entityName
        : asset.description.trim();
    return 'Create ${asset.entityName}, a ${asset.entityKind.name}, as the '
        '$variant reusable StoryTale foreground variant. '
        'Identity and appearance: $description. '
        'Show exactly one complete subject, preserve the same identity for '
        'every later variant, and make the $variant state clearly readable.';
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

class GeneratedBackgroundData {
  const GeneratedBackgroundData({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.prompt,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final String prompt;
}

class GeneratedForegroundData {
  const GeneratedForegroundData({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.prompt,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final String prompt;
}

class _WorkerImage {
  const _WorkerImage(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

class ArtworkGenerationException implements Exception {
  const ArtworkGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
