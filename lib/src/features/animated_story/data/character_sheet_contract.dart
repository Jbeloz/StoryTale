import 'dart:convert';

import 'package:flutter/services.dart';

class CharacterSheetContractRepository {
  CharacterSheetContractRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const assetPath =
      'assets/images/characters/generation_templates/humanoid_v1/'
      'character_sheet_v4/crop_manifest.json';

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
    required this.selection,
  }) : regionsById = {for (final region in regions) region.id: region};

  static const supportedContractId = 'character_sheet_v4';
  static const supportedContractVersion = 4;

  /// V4's twelve cells. The three V1/V3 rear-hair alternatives collapse into one
  /// `back_hair_selected` cell, because a request only ever activates one
  /// length and the other two were green waste rather than extra capability.
  static const expectedRegionIds = {
    'back_hair_selected',
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

  /// The `1:1` tiers the provider documents. The active canvas must be one of
  /// them, so a repack cannot quietly request a shape the provider may reject.
  static const supportedCanvasSizes = {1024, 2048, 4096};

  final String contractId;
  final int contractVersion;
  final CharacterSheetCanvas canvas;
  final CharacterSheetAssets assets;
  final Map<String, String> assetSha256;
  final CharacterSheetLockedRig lockedRig;
  final CharacterSheetRules rules;
  final List<CharacterSheetRegion> regions;
  final Map<String, CharacterSheetRegion> regionsById;
  final CharacterSheetSelection selection;

  static const requiredHashIds = {
    'guide',
    'assembledReference',
    'allowedRegions',
    'protectedRegions',
    'seamAllowances',
    'promptContract',
  };

  static const requiredLockedAssetPaths = {
    'assets/images/characters/rigs/humanoid_v1/faces/head_base.png',
    'assets/images/characters/rigs/humanoid_v1/base/torso.png',
    'assets/images/characters/rigs/humanoid_v1/base/upper_arm_right.png',
    'assets/images/characters/rigs/humanoid_v1/base/upper_arm_left.png',
    'assets/images/characters/rigs/humanoid_v1/base/lower_arm_right.png',
    'assets/images/characters/rigs/humanoid_v1/base/lower_arm_left.png',
    'assets/images/characters/rigs/humanoid_v1/base/upper_leg_right.png',
    'assets/images/characters/rigs/humanoid_v1/base/upper_leg_left.png',
    'assets/images/characters/rigs/humanoid_v1/base/lower_leg_right.png',
    'assets/images/characters/rigs/humanoid_v1/base/lower_leg_left.png',
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
      selection: CharacterSheetSelection.fromJson(
        json['selectionContract'] as Map<String, dynamic>?,
        guideVariantSha256: json['guideVariantSha256'] as Map<String, dynamic>?,
        allowedVariantSha256:
            json['allowedVariantSha256'] as Map<String, dynamic>?,
        fallbackGuide: (json['assets'] as Map<String, dynamic>)['guide']
            as String,
        fallbackGuideSha256:
            (json['assetSha256'] as Map<String, dynamic>)['guide'] as String,
        fallbackAllowedRegions:
            (json['assets'] as Map<String, dynamic>)['allowedRegions']
                as String,
        fallbackAllowedRegionsSha256:
            (json['assetSha256'] as Map<String, dynamic>)['allowedRegions']
                as String,
      ),
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
    // Square, and one of the provider's documented `1:1` tiers. V4 is the `1K`
    // tier; the rule stays general so a later repack is checked rather than
    // trusted.
    if (canvas.width != canvas.height ||
        !supportedCanvasSizes.contains(canvas.width)) {
      errors.add(
        'The canvas must be a square 1:1 provider tier, not '
        '${canvas.width} x ${canvas.height}.',
      );
    }
    // The provider decides the output format; the contract only has to name one
    // this pipeline can decode. Measured on 2026-08-06: the Interactions API
    // rejects `image/png` for `response_format.mime_type` and supports only
    // `image/jpeg`. The green background is what actually matters, and its
    // detection is tolerant rather than an exact match, so JPEG is workable.
    if (!const {'image/png', 'image/jpeg'}.contains(canvas.mimeType) ||
        canvas.backgroundColor.toUpperCase() != '#00FF00') {
      errors.add(
        'The sheet output must be a PNG or JPEG with #00FF00 background.',
      );
    }
    if (lockedRig.id != 'humanoid_v1' || !_isSha256(lockedRig.geometryHash)) {
      errors.add('The locked humanoid_v1 geometry hash is missing.');
    }
    if (!_isSha256(lockedRig.manifestSha256)) {
      errors.add('The locked humanoid_v1 rig manifest hash is missing.');
    }
    if (!lockedRig.assetSha256.keys.toSet().containsAll(
          requiredLockedAssetPaths,
        ) ||
        lockedRig.assetSha256.entries.any(
          (entry) =>
              !requiredLockedAssetPaths.contains(entry.key) ||
              !_isSha256(entry.value),
        )) {
      errors.add(
        'The ten locked humanoid_v1 runtime asset hashes are invalid.',
      );
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
      errors.add(
        'The contract must contain all ${expectedRegionIds.length} fixed '
        'regions once.',
      );
    }
    if (selection.backHairRegionId != null &&
        !seen.contains(selection.backHairRegionId)) {
      errors.add(
        'The selection contract names missing region '
        '${selection.backHairRegionId}.',
      );
    }
    for (final entry in selection.guideByBackHairId.entries) {
      if (!selection.guideSha256ByBackHairId.containsKey(entry.key)) {
        errors.add('The ${entry.key} guide variant has no recorded hash.');
      }
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

/// How a request turns its chosen rear-hair length into a region and a guide.
///
/// V1 published one cell per length and one guide. V4 publishes one
/// `back_hair_selected` cell and one guide per length, because the single cell
/// has to show the silhouette the request is actually asking for. Reading both
/// shapes from the manifest keeps that difference out of the calling code, and
/// keeps V1 loadable for rollback.
class CharacterSheetSelection {
  const CharacterSheetSelection({
    required this.backHairRegionId,
    required this.acceptedValues,
    required this.guideByBackHairId,
    required this.guideSha256ByBackHairId,
    required this.allowedRegionsByBackHairId,
    required this.allowedRegionsSha256ByBackHairId,
    required this.canonicalBackHairId,
    required this.fallbackGuide,
    required this.fallbackGuideSha256,
    required this.fallbackAllowedRegions,
    required this.fallbackAllowedRegionsSha256,
  });

  /// The single cell every length shares, or `null` on a sheet that publishes
  /// one cell per length.
  final String? backHairRegionId;
  final Set<String> acceptedValues;
  final Map<String, String> guideByBackHairId;
  final Map<String, String> guideSha256ByBackHairId;

  /// The allowed window varies with the rear-hair length, because it is now the
  /// hair silhouette rather than the whole cell, and the three silhouettes fill
  /// `404`, `546`, and `784` px of the same `800`-tall cell. Sending or
  /// validating against the wrong one would either clip real hair or re-open the
  /// empty space this narrowing exists to close.
  final Map<String, String> allowedRegionsByBackHairId;
  final Map<String, String> allowedRegionsSha256ByBackHairId;
  final String? canonicalBackHairId;
  final String fallbackGuide;
  final String fallbackGuideSha256;
  final String fallbackAllowedRegions;
  final String fallbackAllowedRegionsSha256;

  factory CharacterSheetSelection.fromJson(
    Map<String, dynamic>? json, {
    required Map<String, dynamic>? guideVariantSha256,
    required Map<String, dynamic>? allowedVariantSha256,
    required String fallbackGuide,
    required String fallbackGuideSha256,
    required String fallbackAllowedRegions,
    required String fallbackAllowedRegionsSha256,
  }) {
    Map<String, String> stringMap(Object? value) => switch (value) {
      final Map<String, dynamic> map => map.map(
        (key, value) => MapEntry(key, value as String),
      ),
      _ => const {},
    };
    return CharacterSheetSelection(
      backHairRegionId: json?['backHairRegionId'] as String?,
      acceptedValues:
          (json?['acceptedValues'] as List<dynamic>?)
              ?.map((value) => value as String)
              .toSet() ??
          const {'short', 'medium', 'long', 'none'},
      guideByBackHairId: stringMap(json?['guideByBackHairId']),
      guideSha256ByBackHairId: stringMap(guideVariantSha256),
      allowedRegionsByBackHairId: stringMap(
        json?['allowedRegionsByBackHairId'],
      ),
      allowedRegionsSha256ByBackHairId: stringMap(allowedVariantSha256),
      canonicalBackHairId: json?['canonicalBackHairId'] as String?,
      fallbackGuide: fallbackGuide,
      fallbackGuideSha256: fallbackGuideSha256,
      fallbackAllowedRegions: fallbackAllowedRegions,
      fallbackAllowedRegionsSha256: fallbackAllowedRegionsSha256,
    );
  }

  /// The region a chosen length activates. `none` activates nothing.
  ///
  /// On a one-cell-per-length sheet the length names its own region; on a
  /// single-cell sheet every length maps to the same one.
  String regionFor(String backHairId) {
    if (backHairId == 'none') return 'none';
    if (!acceptedValues.contains(backHairId)) {
      throw FormatException('Unsupported back-hair ID: $backHairId.');
    }
    return backHairRegionId ?? 'back_hair_$backHairId';
  }

  /// The guide whose rear-hair silhouette matches the chosen length, with its
  /// hash. `none` uses the canonical variant and leaves the cell green.
  ({String path, String sha256}) guideFor(String backHairId) {
    final variantId = backHairId == 'none'
        ? (canonicalBackHairId ?? backHairId)
        : backHairId;
    final path = guideByBackHairId[variantId];
    final hash = guideSha256ByBackHairId[variantId];
    if (path == null || hash == null) {
      return (path: fallbackGuide, sha256: fallbackGuideSha256);
    }
    return (path: path, sha256: hash);
  }

  /// The allowed mask matching the chosen length, with its hash.
  ///
  /// Resolved exactly like [guideFor], including the fallback, so a contract
  /// that publishes no variants — V1 and V3 — keeps working on its single mask.
  ({String path, String sha256}) allowedRegionsFor(String backHairId) {
    final variantId = backHairId == 'none'
        ? (canonicalBackHairId ?? backHairId)
        : backHairId;
    final path = allowedRegionsByBackHairId[variantId];
    final hash = allowedRegionsSha256ByBackHairId[variantId];
    if (path == null || hash == null) {
      return (
        path: fallbackAllowedRegions,
        sha256: fallbackAllowedRegionsSha256,
      );
    }
    return (path: path, sha256: hash);
  }

  /// Every guide the provider may legitimately be sent, so a verifier can
  /// accept a variant without loosening to "any file".
  Set<String> get acceptedGuideSha256 => {
    fallbackGuideSha256,
    ...guideSha256ByBackHairId.values,
  };
}

class CharacterSheetLockedRig {
  const CharacterSheetLockedRig({
    required this.id,
    required this.geometryHash,
    required this.manifestSha256,
    required this.assetSha256,
  });

  final String id;
  final String geometryHash;
  final String manifestSha256;
  final Map<String, String> assetSha256;

  factory CharacterSheetLockedRig.fromJson(Map<String, dynamic> json) {
    return CharacterSheetLockedRig(
      id: json['id'] as String,
      geometryHash: json['geometryHash'] as String,
      manifestSha256: json['manifestSha256'] as String? ?? '',
      assetSha256: (json['assetSha256'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value as String)),
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
