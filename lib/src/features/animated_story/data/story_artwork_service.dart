import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;

import 'character_sheet_contract.dart';
import 'character_sheet_generation.dart';
import 'sprite_references.dart';
import 'sprite_layer_processor.dart';
import 'story_foreground_repository.dart';
import 'visual_novel_background_brief.dart';

class StoryArtworkService {
  StoryArtworkService({
    http.Client? client,
    AssetBundle? bundle,
    CharacterSheetContractRepository? characterSheetContracts,
    String? endpoint,
    String? token,
  }) : _client = client ?? http.Client(),
       _bundle = bundle ?? rootBundle,
       _characterSheetContracts =
           characterSheetContracts ??
           CharacterSheetContractRepository(bundle: bundle ?? rootBundle),
       endpoint = endpoint ?? _endpoint,
       token = token ?? _token;

  static const _endpoint = String.fromEnvironment(
    'CLOUDFLARE_IMAGE_URL',
    defaultValue: 'https://storytale-image-worker.jbalejoshift0928.workers.dev',
  );
  static const _token = String.fromEnvironment('CLOUDFLARE_IMAGE_TOKEN');

  final http.Client _client;
  final AssetBundle _bundle;
  final CharacterSheetContractRepository _characterSheetContracts;
  final String endpoint;
  final String token;
  final Map<String, CharacterSheetGenerationResult> _characterSheetCache = {};
  Future<CharacterSheetGenerationResult>? _characterSheetInFlight;

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

  Future<CharacterSheetGenerationResult> generateCharacterSheet(
    CharacterSheetGenerationRequest request,
  ) async {
    final contract = await _characterSheetContracts.load();
    final fingerprint = request.fingerprint(contract);
    final cached = _characterSheetCache[fingerprint];
    if (cached != null) return cached;
    if (_characterSheetInFlight != null) {
      throw const ArtworkGenerationException(
        'Another character-sheet request is already active. Wait for it to '
        'finish before starting a paid request.',
      );
    }

    final generation = _generateCharacterSheet(
      request: request,
      contract: contract,
      fingerprint: fingerprint,
    );
    _characterSheetInFlight = generation;
    try {
      final result = await generation;
      _characterSheetCache[fingerprint] = result;
      return result;
    } finally {
      _characterSheetInFlight = null;
    }
  }

  Future<CharacterSheetGenerationResult> _generateCharacterSheet({
    required CharacterSheetGenerationRequest request,
    required CharacterSheetContract contract,
    required String fingerprint,
  }) async {
    final promptBytes = await _verifiedAssetBytes(
      contract.assets.promptContract,
      contract.assetSha256['promptContract']!,
    );
    final prompt = request.buildPrompt(utf8.decode(promptBytes), contract);
    // The guide must show the rear-hair silhouette this request is asking for.
    // V4 publishes one variant per length behind a single set of cells, masks,
    // and anchors, so only the first reference and its hash change.
    final guide = contract.selection.guideFor(request.backHairId);
    final references = <({String path, String sha256})>[
      guide,
      (
        path: contract.assets.assembledReference,
        sha256: contract.assetSha256['assembledReference']!,
      ),
      (
        path: contract.assets.allowedRegions,
        sha256: contract.assetSha256['allowedRegions']!,
      ),
      (
        path: contract.assets.protectedRegions,
        sha256: contract.assetSha256['protectedRegions']!,
      ),
      (
        path: contract.assets.seamAllowances,
        sha256: contract.assetSha256['seamAllowances']!,
      ),
    ];
    final files = <http.MultipartFile>[];
    for (var index = 0; index < references.length; index++) {
      final reference = references[index];
      final bytes = await _verifiedAssetBytes(
        reference.path,
        reference.sha256,
      );
      files.add(
        http.MultipartFile.fromBytes(
          'input_image_$index',
          bytes,
          filename: reference.path.split('/').last,
        ),
      );
    }

    final worker = await _generate(
      kind: 'sprite',
      mode: 'character-sheet',
      prompt: prompt,
      fields: {
        'contract_id': contract.contractId,
        'contract_version': '${contract.contractVersion}',
        // The hash of the variant actually being sent, not the canonical one,
        // so the Worker can verify the uploaded file against the declared hash.
        'guide_sha256': guide.sha256,
        'geometry_hash': contract.lockedRig.geometryHash,
        'request_fingerprint': fingerprint,
        'selected_back_hair': request.selectedBackHairRegion(contract),
      },
      files: files,
    );
    final decoded = image.decodeImage(worker.bytes);
    if (decoded == null) {
      throw const ArtworkGenerationException(
        'Gemini returned a corrupt character sheet.',
      );
    }
    if (worker.mimeType != 'image/png' ||
        decoded.width != contract.canvas.width ||
        decoded.height != contract.canvas.height) {
      throw ArtworkGenerationException(
        'Gemini returned ${decoded.width}x${decoded.height} '
        '${worker.mimeType}; StoryTale requires one '
        '${contract.canvas.width}x${contract.canvas.height} '
        '${contract.canvas.mimeType}.',
      );
    }
    if (worker.requestFingerprint != fingerprint) {
      throw const ArtworkGenerationException(
        'The Worker returned mismatched character-sheet request metadata.',
      );
    }
    return CharacterSheetGenerationResult(
      bytes: worker.bytes,
      mimeType: worker.mimeType,
      width: decoded.width,
      height: decoded.height,
      provider: worker.provider,
      model: worker.model,
      requestId: worker.requestId,
      requestFingerprint: fingerprint,
      contractId: contract.contractId,
      contractVersion: contract.contractVersion,
      prompt: prompt,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<Uint8List> _verifiedAssetBytes(
    String assetPath,
    String expectedSha256,
  ) async {
    final data = await _bundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (sha256.convert(bytes).toString() != expectedSha256) {
      throw ArtworkGenerationException(
        'Character-sheet contract asset drifted: $assetPath.',
      );
    }
    return bytes;
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
    Map<String, String> fields = const {},
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
      ..fields.addAll(fields)
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
    return _WorkerImage(
      bytes: Uint8List.fromList(bytes),
      mimeType: mimeType,
      provider: response.headers['x-image-provider'] ?? '',
      model: response.headers['x-image-model'] ?? '',
      requestId: response.headers['x-request-id'] ?? '',
      requestFingerprint: response.headers['x-request-fingerprint'],
    );
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
  const _WorkerImage({
    required this.bytes,
    required this.mimeType,
    required this.provider,
    required this.model,
    required this.requestId,
    this.requestFingerprint,
  });

  final Uint8List bytes;
  final String mimeType;
  final String provider;
  final String model;
  final String requestId;
  final String? requestFingerprint;
}

class ArtworkGenerationException implements Exception {
  const ArtworkGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
