import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'character_design_brief.dart';
import 'character_sheet_contract.dart';

class CharacterSheetGenerationRequest {
  static const fidelityGateVersion = 1;

  const CharacterSheetGenerationRequest({
    required this.brief,
    required this.skinTone,
    required this.frontHairId,
    required this.backHairId,
    required this.outfitRequirements,
    this.ageAndRole = 'source-defined story character',
    this.approvedAccessories = const [],
  });

  final CharacterDesignBrief brief;
  final String skinTone;
  final String frontHairId;
  final String backHairId;
  final String outfitRequirements;
  final String ageAndRole;
  final List<String> approvedAccessories;

  String selectedBackHairRegion() {
    return switch (backHairId) {
      'short' => 'back_hair_short',
      'medium' => 'back_hair_medium',
      'long' => 'back_hair_long',
      'none' => 'none',
      _ => throw FormatException('Unsupported back-hair ID: $backHairId.'),
    };
  }

  String fingerprint(CharacterSheetContract contract) {
    final source = jsonEncode({
      'contractId': contract.contractId,
      'contractVersion': contract.contractVersion,
      'guideSha256': contract.assetSha256['guide'],
      'geometryHash': contract.lockedRig.geometryHash,
      'fidelityGateVersion': fidelityGateVersion,
      'bookId': brief.bookId,
      'characterId': brief.characterId,
      'canonicalName': brief.canonicalName,
      'actorProfileId': brief.actorProfileId,
      'sourceDescription': brief.sourceDescription,
      'skinTone': skinTone.toUpperCase(),
      'frontHairId': frontHairId,
      'backHairId': backHairId,
      'outfitRequirements': outfitRequirements,
      'ageAndRole': ageAndRole,
      'approvedAccessories': approvedAccessories,
    });
    return sha256.convert(utf8.encode(source)).toString();
  }

  String buildPrompt(String template) {
    final replacements = {
      '{{character_name}}': brief.canonicalName.trim(),
      '{{character_design_brief}}': brief.generationPrompt,
      '{{age_and_role}}': ageAndRole.trim(),
      '{{skin_tone}}': skinTone.toUpperCase(),
      '{{hair_requirements}}':
          'Front hair $frontHairId with $backHairId back hair. Preserve one '
          'identity, color, and line style.',
      '{{back_hair_short|back_hair_medium|back_hair_long|none}}':
          selectedBackHairRegion(),
      '{{outfit_requirements}}': outfitRequirements.trim(),
      '{{approved_accessories_or_none}}': approvedAccessories.isEmpty
          ? 'none'
          : approvedAccessories.join(', '),
    };
    var result = template;
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}

class CharacterSheetGenerationResult {
  const CharacterSheetGenerationResult({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.provider,
    required this.model,
    required this.requestId,
    required this.requestFingerprint,
    required this.contractId,
    required this.contractVersion,
    required this.prompt,
    required this.generatedAt,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final String provider;
  final String model;
  final String requestId;
  final String requestFingerprint;
  final String contractId;
  final int contractVersion;
  final String prompt;
  final String generatedAt;

  Map<String, dynamic> metadataJson() => {
    'mimeType': mimeType,
    'width': width,
    'height': height,
    'provider': provider,
    'model': model,
    'requestId': requestId,
    'requestFingerprint': requestFingerprint,
    'contractId': contractId,
    'contractVersion': contractVersion,
    'prompt': prompt,
    'generatedAt': generatedAt,
  };
}
