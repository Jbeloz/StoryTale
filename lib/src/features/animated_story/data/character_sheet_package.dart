import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'character_sheet_contract.dart';
import 'character_sheet_generation.dart';
import 'story_asset_binary_store.dart';

enum CharacterSheetPackageStatus { ready, needsAttention }

class CharacterSheetPoseProofMetadata {
  const CharacterSheetPoseProofMetadata({
    required this.poseId,
    required this.label,
    required this.assetId,
    required this.width,
    required this.height,
    required this.visiblePixelCount,
    required this.sha256,
    required this.valid,
  });

  final String poseId;
  final String label;
  final String assetId;
  final int width;
  final int height;
  final int visiblePixelCount;
  final String sha256;
  final bool valid;

  Map<String, dynamic> toJson() => {
    'poseId': poseId,
    'label': label,
    'assetId': assetId,
    'width': width,
    'height': height,
    'visiblePixelCount': visiblePixelCount,
    'sha256': sha256,
    'valid': valid,
  };
}

class CharacterSheetFaceProofMetadata {
  const CharacterSheetFaceProofMetadata({
    required this.expressionId,
    required this.label,
    required this.assetId,
    required this.width,
    required this.height,
    required this.visiblePixelCount,
    required this.sha256,
    required this.valid,
  });

  final String expressionId;
  final String label;
  final String assetId;
  final int width;
  final int height;
  final int visiblePixelCount;
  final String sha256;
  final bool valid;

  Map<String, dynamic> toJson() => {
    'expressionId': expressionId,
    'label': label,
    'assetId': assetId,
    'width': width,
    'height': height,
    'visiblePixelCount': visiblePixelCount,
    'sha256': sha256,
    'valid': valid,
  };
}

class CharacterSheetLayerMetadata {
  const CharacterSheetLayerMetadata({
    required this.regionId,
    required this.kind,
    required this.parentPart,
    required this.side,
    required this.width,
    required this.height,
    required this.anchorX,
    required this.anchorY,
    required this.layerOrder,
    required this.requirement,
    required this.assetId,
    required this.visiblePixelCount,
    required this.sha256,
    required this.empty,
  });

  final String regionId;
  final String kind;
  final String parentPart;
  final String side;
  final int width;
  final int height;
  final double anchorX;
  final double anchorY;
  final int layerOrder;
  final String requirement;
  final String assetId;
  final int visiblePixelCount;
  final String? sha256;
  final bool empty;

  Map<String, dynamic> toJson() => {
    'regionId': regionId,
    'kind': kind,
    'parentPart': parentPart,
    'side': side,
    'width': width,
    'height': height,
    'attachmentAnchor': {'x': anchorX, 'y': anchorY},
    'layerOrder': layerOrder,
    'requirement': requirement,
    'assetId': assetId,
    'visiblePixelCount': visiblePixelCount,
    'empty': empty,
    if (sha256 != null) 'sha256': sha256,
  };
}

class CharacterSheetPackageValidation {
  const CharacterSheetPackageValidation({
    required this.errors,
    required this.visiblePixelsByRegion,
    required this.rejectedPixelsByRegion,
    required this.greenPixelsRemovedByRegion,
    required this.canvasValid,
    required this.fingerprintValid,
    required this.geometryValid,
    required this.slotValid,
    required this.sideValid,
    required this.seamValid,
    required this.lockedAssetsValid,
    required this.identityValid,
    required this.faceProofValid,
    required this.poseProofValid,
    required this.proofsByFace,
    required this.proofsByPose,
  });

  final List<String> errors;
  final Map<String, int> visiblePixelsByRegion;
  final Map<String, int> rejectedPixelsByRegion;
  final Map<String, int> greenPixelsRemovedByRegion;
  final bool canvasValid;
  final bool fingerprintValid;
  final bool geometryValid;
  final bool slotValid;
  final bool sideValid;
  final bool seamValid;
  final bool lockedAssetsValid;
  final bool identityValid;
  final bool faceProofValid;
  final bool poseProofValid;
  final Map<String, CharacterSheetFaceProofMetadata> proofsByFace;
  final Map<String, CharacterSheetPoseProofMetadata> proofsByPose;

  bool get isValid =>
      errors.isEmpty &&
      canvasValid &&
      fingerprintValid &&
      geometryValid &&
      slotValid &&
      sideValid &&
      seamValid &&
      lockedAssetsValid &&
      identityValid &&
      faceProofValid &&
      poseProofValid;

  String get errorMessage => errors.isEmpty
      ? 'The character-sheet package needs attention.'
      : errors.join(' ');

  Map<String, dynamic> toJson() => {
    'valid': isValid,
    'canvasValid': canvasValid,
    'fingerprintValid': fingerprintValid,
    'geometryValid': geometryValid,
    'slotValid': slotValid,
    'sideValid': sideValid,
    'seamValid': seamValid,
    'lockedAssetsValid': lockedAssetsValid,
    'identityValid': identityValid,
    'faceProofValid': faceProofValid,
    'poseProofValid': poseProofValid,
    'proofsByFace': {
      for (final entry in proofsByFace.entries) entry.key: entry.value.toJson(),
    },
    'proofsByPose': {
      for (final entry in proofsByPose.entries) entry.key: entry.value.toJson(),
    },
    'errors': errors,
    'visiblePixelsByRegion': visiblePixelsByRegion,
    'rejectedPixelsByRegion': rejectedPixelsByRegion,
    'greenPixelsRemovedByRegion': greenPixelsRemovedByRegion,
  };
}

class CharacterSheetPackage {
  CharacterSheetPackage({
    required this.packageId,
    required this.bookId,
    required this.characterId,
    required this.characterName,
    required this.outfitId,
    required this.skinTone,
    required this.frontHairId,
    required this.backHairId,
    required this.selectedBackHairRegion,
    required this.contract,
    required this.generation,
    required this.sourceAssetId,
    required this.cleanAssetId,
    required this.facePreviewAssetIds,
    required this.previewAssetIds,
    required this.layerMetadata,
    required this.layerBytes,
    required this.sourceBytes,
    required this.cleanBytes,
    required this.facePreviewBytesByExpression,
    required this.previewBytesByPose,
    required this.validation,
    required this.createdAt,
  });

  final String packageId;
  final String bookId;
  final String characterId;
  final String characterName;
  final String outfitId;
  final String skinTone;
  final String frontHairId;
  final String backHairId;
  final String selectedBackHairRegion;
  final CharacterSheetContract contract;
  final CharacterSheetGenerationResult generation;
  final String sourceAssetId;
  final String cleanAssetId;
  final Map<String, String> facePreviewAssetIds;
  final Map<String, String> previewAssetIds;
  final Map<String, CharacterSheetLayerMetadata> layerMetadata;
  final Map<String, Uint8List> layerBytes;
  final Uint8List sourceBytes;
  final Uint8List cleanBytes;
  final Map<String, Uint8List> facePreviewBytesByExpression;
  final Map<String, Uint8List> previewBytesByPose;
  final CharacterSheetPackageValidation validation;
  final String createdAt;

  CharacterSheetPackageStatus get status => validation.isValid
      ? CharacterSheetPackageStatus.ready
      : CharacterSheetPackageStatus.needsAttention;

  int get nonEmptyLayerCount =>
      layerMetadata.values.where((layer) => !layer.empty).length;

  String get neutralPreviewAssetId => previewAssetIds['neutral']!;
  /// The neutral pose proof, falling back to the cleaned sheet when the proof
  /// pass was skipped for testing. Callers use this as a safe preview, so it
  /// must not throw just because there is nothing composed to show.
  Uint8List get neutralProofBytes =>
      previewBytesByPose['neutral'] ?? cleanBytes;

  Map<String, dynamic> appearanceJson() => {
    'packageId': packageId,
    'status': status.name,
    'bookId': bookId,
    'characterId': characterId,
    'characterName': characterName,
    'outfitId': outfitId,
    'skinTone': skinTone,
    'frontHairId': frontHairId,
    'backHairId': backHairId,
    'selectedBackHairRegion': selectedBackHairRegion,
    'designHash': generation.requestFingerprint,
    'contractId': contract.contractId,
    'contractVersion': contract.contractVersion,
    'geometryHash': contract.lockedRig.geometryHash,
    'createdAt': createdAt,
    'sourceAssetId': sourceAssetId,
    'cleanAssetId': cleanAssetId,
    'facePreviewAssetIds': facePreviewAssetIds,
    'previewAssetIds': previewAssetIds,
    'layers': {
      for (final entry in layerMetadata.entries)
        entry.key: entry.value.toJson(),
    },
  };

  Map<String, dynamic> requestJson() => {
    'requestFingerprint': generation.requestFingerprint,
    'prompt': generation.prompt,
    'contractId': contract.contractId,
    'contractVersion': contract.contractVersion,
    'selectedBackHairRegion': selectedBackHairRegion,
  };

  Map<String, dynamic> responseJson() => generation.metadataJson();
}

/// Registers the logical Phase 7G.1B appearance package while generated image
/// bytes remain session-only. Phase 8 can replace this store without changing
/// the stable asset IDs or package metadata.
class CharacterSheetPackageStore {
  const CharacterSheetPackageStore._();

  static final Map<String, CharacterSheetPackage> _byFingerprint = {};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static CharacterSheetPackage? read(String requestFingerprint) =>
      _byFingerprint[requestFingerprint];

  static void save(CharacterSheetPackage package) {
    StoryAssetBinaryStore.write(package.sourceAssetId, package.sourceBytes);
    StoryAssetBinaryStore.write(package.cleanAssetId, package.cleanBytes);
    for (final entry in package.previewBytesByPose.entries) {
      StoryAssetBinaryStore.write(
        package.previewAssetIds[entry.key]!,
        entry.value,
      );
    }
    for (final entry in package.facePreviewBytesByExpression.entries) {
      StoryAssetBinaryStore.write(
        package.facePreviewAssetIds[entry.key]!,
        entry.value,
      );
    }

    for (final entry in package.layerMetadata.entries) {
      final bytes = package.layerBytes[entry.key];
      if (bytes == null || bytes.isEmpty) {
        StoryAssetBinaryStore.remove(entry.value.assetId);
      } else {
        StoryAssetBinaryStore.write(entry.value.assetId, bytes);
      }
    }

    void writeJson(String path, Map<String, dynamic> value) {
      StoryAssetBinaryStore.write(
        path,
        Uint8List.fromList(utf8.encode(jsonEncode(value))),
      );
    }

    writeJson('${package.packageId}/appearance.json', package.appearanceJson());
    writeJson(
      '${package.packageId}/generation/request.json',
      package.requestJson(),
    );
    writeJson(
      '${package.packageId}/generation/response.json',
      package.responseJson(),
    );
    writeJson(
      '${package.packageId}/generation/validation.json',
      package.validation.toJson(),
    );
    writeJson('${package.packageId}/outfits/${package.outfitId}/outfit.json', {
      'outfitId': package.outfitId,
      'designHash': package.generation.requestFingerprint,
      'fittedLayers': [
        for (final layer in package.layerMetadata.values)
          if (layer.kind == 'fittedClothing' && !layer.empty) layer.assetId,
      ],
    });

    _byFingerprint[package.generation.requestFingerprint] = package;
    revision.value++;
  }
}
