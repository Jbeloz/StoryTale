import 'dart:convert';

import 'package:flutter/services.dart';

class CharacterSheetContractRepository {
  CharacterSheetContractRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const assetPath =
      'assets/images/characters/generation_templates/humanoid_v1/'
      'character_sheet_v1/crop_manifest.json';

  final AssetBundle _bundle;

  Future<CharacterSheetContract> load() async {
    final source = await _bundle.loadString(assetPath);
    final contract = CharacterSheetContract.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
    contract.validateOrThrow();
    return contract;
  }
}

class CharacterSheetContract {
  CharacterSheetContract({
    required this.contractId,
    required this.contractVersion,
    required this.canvas,
    required this.assets,
    required this.assetSha256,
    required this.lockedRig,
    required this.rules,
    required this.regions,
  }) : regionsById = {for (final region in regions) region.id: region};

  static const supportedContractId = 'character_sheet_v1';
  static const supportedContractVersion = 1;
  static const expectedRegionIds = {
    'back_hair_short',
    'back_hair_medium',
    'back_hair_long',
    'front_hair',
    'head',
    'torso',
    'upper_arm_right',
    'upper_arm_left',
    'lower_arm_right',
    'lower_arm_left',
    'upper_leg_right',
    'upper_leg_left',
    'lower_leg_right',
    'lower_leg_left',
  };

  final String contractId;
  final int contractVersion;
  final CharacterSheetCanvas canvas;
  final CharacterSheetAssets assets;
  final Map<String, String> assetSha256;
  final CharacterSheetLockedRig lockedRig;
  final CharacterSheetRules rules;
  final List<CharacterSheetRegion> regions;
  final Map<String, CharacterSheetRegion> regionsById;

  static const requiredHashIds = {
    'guide',
    'assembledReference',
    'allowedRegions',
    'protectedRegions',
    'seamAllowances',
    'promptContract',
  };

  factory CharacterSheetContract.fromJson(Map<String, dynamic> json) {
    return CharacterSheetContract(
      contractId: json['contractId'] as String,
      contractVersion: (json['contractVersion'] as num).toInt(),
      canvas: CharacterSheetCanvas.fromJson(
        json['canvas'] as Map<String, dynamic>,
      ),
      assets: CharacterSheetAssets.fromJson(
        json['assets'] as Map<String, dynamic>,
      ),
      assetSha256: (json['assetSha256'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      lockedRig: CharacterSheetLockedRig.fromJson(
        json['lockedRig'] as Map<String, dynamic>,
      ),
      rules: CharacterSheetRules.fromJson(
        json['rules'] as Map<String, dynamic>,
      ),
      regions: (json['regions'] as List<dynamic>)
          .map(
            (value) =>
                CharacterSheetRegion.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  void validateOrThrow() {
    final errors = validationErrors();
    if (errors.isNotEmpty) {
      throw FormatException(
        'Invalid $supportedContractId contract: ${errors.join(' ')}',
      );
    }
  }

  List<String> validationErrors() {
    final errors = <String>[];
    if (contractId != supportedContractId) {
      errors.add('Unsupported contract ID $contractId.');
    }
    if (contractVersion != supportedContractVersion) {
      errors.add('Unsupported contract version $contractVersion.');
    }
    if (canvas.width != 4096 || canvas.height != 4096) {
      errors.add('The V1 canvas must be 4096 x 4096.');
    }
    if (canvas.mimeType != 'image/png' ||
        canvas.backgroundColor.toUpperCase() != '#00FF00') {
      errors.add('The V1 output must be a PNG with #00FF00 background.');
    }
    if (lockedRig.id != 'humanoid_v1' || !_isSha256(lockedRig.geometryHash)) {
      errors.add('The locked humanoid_v1 geometry hash is missing.');
    }
    if (!rules.cropCoordinatesAreInclusiveExclusive ||
        rules.resizeRegions ||
        rules.cropToVisiblePixels ||
        rules.visibleCellBorders) {
      errors.add('The fixed crop and no-resize rules were changed.');
    }
    for (final asset in assets.requiredPaths) {
      if (asset.trim().isEmpty) {
        errors.add('A required contract asset path is empty.');
        break;
      }
    }
    for (final entry in assetSha256.entries) {
      if (!_isSha256(entry.value)) {
        errors.add('Invalid SHA-256 for ${entry.key}.');
      }
    }
    if (!assetSha256.keys.toSet().containsAll(requiredHashIds)) {
      errors.add('One or more required contract asset hashes are missing.');
    }

    final seen = <String>{};
    for (final region in regions) {
      if (!seen.add(region.id)) {
        errors.add('Duplicate region ${region.id}.');
      }
      if (!region.crop.isInside(canvas.width, canvas.height)) {
        errors.add('Region ${region.id} is outside the sheet canvas.');
      }
      if (region.crop.width != region.outputCanvas.width ||
          region.crop.height != region.outputCanvas.height) {
        errors.add('Region ${region.id} changes its native output size.');
      }
      if (!region.attachmentAnchor.isInside(region.outputCanvas)) {
        errors.add('Region ${region.id} has an invalid attachment anchor.');
      }
      if (region.maskRegionId != region.id) {
        errors.add('Region ${region.id} has a mismatched mask ID.');
      }
      if (!const {'left', 'right', 'center'}.contains(region.side)) {
        errors.add('Region ${region.id} has an invalid side.');
      }
      for (final seam in region.seamAnchors) {
        if (!seam.point.isInside(region.outputCanvas) || seam.radius <= 0) {
          errors.add('Region ${region.id} has an invalid seam anchor.');
        }
      }
    }
    if (seen.length != expectedRegionIds.length ||
        !seen.containsAll(expectedRegionIds)) {
      errors.add('The V1 contract must contain all 14 fixed regions once.');
    }
    return errors;
  }

  static bool _isSha256(String value) {
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(value.toLowerCase());
  }
}

class CharacterSheetCanvas {
  const CharacterSheetCanvas({
    required this.width,
    required this.height,
    required this.mimeType,
    required this.backgroundColor,
  });

  final int width;
  final int height;
  final String mimeType;
  final String backgroundColor;

  factory CharacterSheetCanvas.fromJson(Map<String, dynamic> json) {
    return CharacterSheetCanvas(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      mimeType: json['mimeType'] as String,
      backgroundColor: json['backgroundColor'] as String,
    );
  }
}

class CharacterSheetAssets {
  const CharacterSheetAssets({
    required this.guide,
    required this.assembledReference,
    required this.allowedRegions,
    required this.protectedRegions,
    required this.seamAllowances,
    required this.promptContract,
  });

  final String guide;
  final String assembledReference;
  final String allowedRegions;
  final String protectedRegions;
  final String seamAllowances;
  final String promptContract;

  List<String> get requiredPaths => [
    guide,
    assembledReference,
    allowedRegions,
    protectedRegions,
    seamAllowances,
    promptContract,
  ];

  factory CharacterSheetAssets.fromJson(Map<String, dynamic> json) {
    return CharacterSheetAssets(
      guide: json['guide'] as String,
      assembledReference: json['assembledReference'] as String,
      allowedRegions: json['allowedRegions'] as String,
      protectedRegions: json['protectedRegions'] as String,
      seamAllowances: json['seamAllowances'] as String,
      promptContract: json['promptContract'] as String,
    );
  }
}

class CharacterSheetLockedRig {
  const CharacterSheetLockedRig({required this.id, required this.geometryHash});

  final String id;
  final String geometryHash;

  factory CharacterSheetLockedRig.fromJson(Map<String, dynamic> json) {
    return CharacterSheetLockedRig(
      id: json['id'] as String,
      geometryHash: json['geometryHash'] as String,
    );
  }
}

class CharacterSheetRules {
  const CharacterSheetRules({
    required this.cropCoordinatesAreInclusiveExclusive,
    required this.resizeRegions,
    required this.cropToVisiblePixels,
    required this.inactiveOptionalRegionsRemainGreen,
    required this.visibleCellBorders,
  });

  final bool cropCoordinatesAreInclusiveExclusive;
  final bool resizeRegions;
  final bool cropToVisiblePixels;
  final bool inactiveOptionalRegionsRemainGreen;
  final bool visibleCellBorders;

  factory CharacterSheetRules.fromJson(Map<String, dynamic> json) {
    return CharacterSheetRules(
      cropCoordinatesAreInclusiveExclusive:
          json['cropCoordinatesAreInclusiveExclusive'] as bool,
      resizeRegions: json['resizeRegions'] as bool,
      cropToVisiblePixels: json['cropToVisiblePixels'] as bool,
      inactiveOptionalRegionsRemainGreen:
          json['inactiveOptionalRegionsRemainGreen'] as bool,
      visibleCellBorders: json['visibleCellBorders'] as bool,
    );
  }
}

class CharacterSheetRegion {
  const CharacterSheetRegion({
    required this.id,
    required this.kind,
    required this.crop,
    required this.outputCanvas,
    required this.sourceAsset,
    required this.parentPart,
    required this.side,
    required this.attachmentAnchor,
    required this.seamAnchors,
    required this.defaultLayerOrder,
    required this.maskRegionId,
    required this.requirement,
  });

  final String id;
  final String kind;
  final CharacterSheetRect crop;
  final CharacterSheetDimensions outputCanvas;
  final String sourceAsset;
  final String parentPart;
  final String side;
  final CharacterSheetPoint attachmentAnchor;
  final List<CharacterSheetSeamAnchor> seamAnchors;
  final int defaultLayerOrder;
  final String maskRegionId;
  final String requirement;

  factory CharacterSheetRegion.fromJson(Map<String, dynamic> json) {
    return CharacterSheetRegion(
      id: json['id'] as String,
      kind: json['kind'] as String,
      crop: CharacterSheetRect.fromJson(json['crop'] as Map<String, dynamic>),
      outputCanvas: CharacterSheetDimensions.fromJson(
        json['outputCanvas'] as Map<String, dynamic>,
      ),
      sourceAsset: json['sourceAsset'] as String,
      parentPart: json['parentPart'] as String,
      side: json['side'] as String,
      attachmentAnchor: CharacterSheetPoint.fromJson(
        json['attachmentAnchor'] as Map<String, dynamic>,
      ),
      seamAnchors: (json['seamAnchors'] as List<dynamic>? ?? const [])
          .map(
            (value) => CharacterSheetSeamAnchor.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      defaultLayerOrder: (json['defaultLayerOrder'] as num).toInt(),
      maskRegionId: json['maskRegionId'] as String,
      requirement: json['requirement'] as String,
    );
  }
}

class CharacterSheetRect {
  const CharacterSheetRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  bool isInside(int canvasWidth, int canvasHeight) {
    return x >= 0 &&
        y >= 0 &&
        width > 0 &&
        height > 0 &&
        x + width <= canvasWidth &&
        y + height <= canvasHeight;
  }

  factory CharacterSheetRect.fromJson(Map<String, dynamic> json) {
    return CharacterSheetRect(
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }
}

class CharacterSheetDimensions {
  const CharacterSheetDimensions({required this.width, required this.height});

  final int width;
  final int height;

  factory CharacterSheetDimensions.fromJson(Map<String, dynamic> json) {
    return CharacterSheetDimensions(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }
}

class CharacterSheetPoint {
  const CharacterSheetPoint({required this.x, required this.y});

  final double x;
  final double y;

  bool isInside(CharacterSheetDimensions dimensions) {
    return x >= 0 && y >= 0 && x < dimensions.width && y < dimensions.height;
  }

  factory CharacterSheetPoint.fromJson(Map<String, dynamic> json) {
    return CharacterSheetPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

class CharacterSheetSeamAnchor {
  const CharacterSheetSeamAnchor({required this.point, required this.radius});

  final CharacterSheetPoint point;
  final double radius;

  factory CharacterSheetSeamAnchor.fromJson(Map<String, dynamic> json) {
    return CharacterSheetSeamAnchor(
      point: CharacterSheetPoint.fromJson(json),
      radius: (json['radius'] as num).toDouble(),
    );
  }
}
