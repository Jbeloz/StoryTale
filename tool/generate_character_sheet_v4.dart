import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

/// Builds `character_sheet_v4` locally, without any network or provider call.
///
/// V4 is V2's single-back-hair cell set repacked onto a `1024 x 1024` canvas.
/// Two things make that worth doing:
///
/// * **`1:1` is a supported provider aspect ratio and `4:1` is not.** V3's
///   `4096 x 1024` canvas assumed a `4:1` output tier that the current provider
///   documentation does not list; `1:1` at `1K` is the safest shape available.
/// * **Cells keep their native size.** The canvas shrinks by deleting wasted
///   green, not by scaling artwork, so every extracted part has exactly the same
///   pixels it has in V2 and V3 while the sheet costs a cheaper tier.
///
/// V1, V2, and V3 are left untouched behind their recorded hashes.
const _canvasWidth = 1024;
const _canvasHeight = 1024;

/// Green gap kept on every side of every cell, and against the canvas edge, so
/// generated content cannot bleed between neighbouring cells.
///
/// Found by search, not by hand: this cell set packs at `18` and fails at `20`.
/// [_validateTargetLayout] re-proves it on every build.
const _cellPadding = 18;

const _v1Root =
    'assets/images/characters/generation_templates/humanoid_v1/'
    'character_sheet_v1';
const _v4Root =
    'assets/images/characters/generation_templates/humanoid_v1/'
    'character_sheet_v4';
const _rigManifestPath = 'assets/images/characters/rigs/humanoid_v1/rig.json';

/// One guide per rear-hair length, per actor.
///
/// V4 carries a single `back_hair_selected` cell, so the guide has to show the
/// silhouette the request actually wants. Rather than pack three alternatives
/// into one sheet and leave two of them green, the same layout is published
/// three times with a different rear-hair source in that one cell. Every other
/// cell, mask, anchor, and seam is identical across the variants.
const _backHairVariants = <_BackHairVariant>[
  _BackHairVariant(
    id: 'short',
    sourceAsset:
        'assets/images/characters/rigs/humanoid_v1/hair/back_short.png',
  ),
  _BackHairVariant(
    id: 'medium',
    sourceAsset:
        'assets/images/characters/rigs/humanoid_v1/hair/back_default.png',
  ),
  _BackHairVariant(
    id: 'long',
    sourceAsset: 'assets/images/characters/rigs/humanoid_v1/hair/back_long.png',
  ),
];

/// The actor the checked-in guides depict. Other actors reuse the identical
/// geometry and only swap their hair sources; see `actorContract` below.
const _guideActorId = 'default';

/// The variant `assets.guide` points at, so the six required contract hashes
/// keep their existing shape.
const _canonicalBackHairId = 'medium';

/// One back-hair cell, matching V2's `back_hair_selected` contract. V1 and V3
/// carry three back-hair cells but a request only ever activates one, so the
/// other two are green waste rather than extra capability.
const _targets = <_TargetSpec>[
  _TargetSpec(
    id: 'back_hair_selected',
    sourceRegionId: 'back_hair_medium',
    rigPartId: 'back_hair',
    crop: _Rect(18, 18, 429, 800),
  ),
  _TargetSpec(
    id: 'front_hair',
    sourceRegionId: 'front_hair',
    crop: _Rect(465, 18, 429, 438),
  ),
  _TargetSpec(
    id: 'head',
    sourceRegionId: 'head',
    crop: _Rect(465, 474, 357, 367),
  ),
  _TargetSpec(
    id: 'torso',
    sourceRegionId: 'torso',
    crop: _Rect(840, 474, 165, 234),
  ),
  // Limbs sit in two clearly separated blocks so the provider is never asked to
  // tell eight similar white shapes apart from position alone. Each block reads
  // right limb first, then left, and hip/shoulder before knee/elbow.
  //
  // Legs take the space under the back-hair column and arms the space under the
  // head column, not the other way round: the tallest leg cell is 156 px and
  // only 147 px is free under the head, while 170 px is free under the hair.
  //
  // Legs block, lower left.
  _TargetSpec(
    id: 'upper_leg_right',
    sourceRegionId: 'upper_leg_right',
    crop: _Rect(18, 836, 94, 150),
  ),
  _TargetSpec(
    id: 'lower_leg_right',
    sourceRegionId: 'lower_leg_right',
    crop: _Rect(130, 836, 84, 156),
  ),
  _TargetSpec(
    id: 'upper_leg_left',
    sourceRegionId: 'upper_leg_left',
    crop: _Rect(232, 836, 85, 141),
  ),
  _TargetSpec(
    id: 'lower_leg_left',
    sourceRegionId: 'lower_leg_left',
    crop: _Rect(335, 836, 88, 140),
  ),
  // Arms block, lower right. The 42 px channel between the blocks is more than
  // twice the normal cell gap, so the split reads as deliberate.
  _TargetSpec(
    id: 'upper_arm_right',
    sourceRegionId: 'upper_arm_right',
    crop: _Rect(465, 859, 67, 118),
  ),
  _TargetSpec(
    id: 'lower_arm_right',
    sourceRegionId: 'lower_arm_right',
    crop: _Rect(550, 859, 77, 145),
  ),
  _TargetSpec(
    id: 'upper_arm_left',
    sourceRegionId: 'upper_arm_left',
    crop: _Rect(645, 859, 78, 128),
  ),
  _TargetSpec(
    id: 'lower_arm_left',
    sourceRegionId: 'lower_arm_left',
    crop: _Rect(741, 859, 86, 129),
  ),
];

void main() {
  final rigManifest =
      jsonDecode(File(_rigManifestPath).readAsStringSync())
          as Map<String, dynamic>;
  final rigAssetByPartId = _rigAssetsByPartId(rigManifest);
  _validateTargetSizesAgainstRig(rigManifest);
  _validateTargetLayout();

  final v1Manifest =
      jsonDecode(File('$_v1Root/crop_manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final v1Regions = <String, Map<String, dynamic>>{
    for (final raw in v1Manifest['regions'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw,
  };

  // V1 drew its `head` cell from `base/head.png`, which carries a face and is
  // not the asset the rig composes. V4 takes every cell's artwork from the rig
  // part instead, so the sheet cannot drift from the runtime again. The head
  // then needs its masks and anchors moved with it, because the real head is
  // smaller inside the same cell.
  final headTarget = _targets.firstWhere((target) => target.id == 'head');
  final headRemap = _ContentRemap.between(
    previousAsset: v1Regions['head']!['sourceAsset'] as String,
    currentAsset: rigAssetByPartId['head']!,
    cell: headTarget.crop,
  );
  final correctedSources = <String, Map<String, String>>{
    for (final target in _targets)
      if (v1Regions[target.sourceRegionId]!['sourceAsset'] !=
          rigAssetByPartId[target.rigPartId])
        target.id: <String, String>{
          'wasInV1':
              v1Regions[target.sourceRegionId]!['sourceAsset'] as String,
          'nowUsesRigPart': rigAssetByPartId[target.rigPartId]!,
        },
  };

  final guide = _solidImage(0, 255, 0);
  final allowed = _solidImage(0, 0, 0);
  final protected = _solidImage(0, 0, 0);
  final seams = _solidImage(0, 0, 0);

  final v1Allowed = _decode('$_v1Root/allowed_regions.png');
  final v1Protected = _decode('$_v1Root/protected_regions.png');
  final v1Seams = _decode('$_v1Root/seam_allowances.png');
  final manifestRegions = <Map<String, dynamic>>[];

  _TargetSpec? backHairTarget;
  final referenceContent = <String, _Rect>{};
  for (final target in _targets) {
    final sourceRegion = v1Regions[target.sourceRegionId]!;
    // V1 records its anchors in its own output-canvas space, and V4's cells are
    // the same size, so this is the space the anchors are read from. It is not
    // always the source PNG's canvas; `sourceCanvas` below records that.
    final anchorSpace = sourceRegion['outputCanvas'] as Map<String, dynamic>;
    final sourceAsset = rigAssetByPartId[target.rigPartId]!;
    final remap = target.id == 'head' ? headRemap : _ContentRemap.identity;
    if (sourceRegion['kind'] == 'backHair') {
      // Drawn once per variant below, not into the shared base guide.
      backHairTarget = target;
    } else {
      referenceContent[target.id] = _drawCell(guide, sourceAsset, target.crop);
    }

    final sourceCrop = _Rect.fromJson(
      sourceRegion['crop'] as Map<String, dynamic>,
    );
    final seamAnchors = _scaleSeamAnchors(
      sourceRegion['seamAnchors'] as List<dynamic>? ?? const <dynamic>[],
      anchorSpace,
      target.crop,
    ).map(remap.anchor).toList(growable: false);
    final allowedCell = _cellMask(
      source: v1Allowed,
      sourceCrop: sourceCrop,
      cell: target.crop,
      remap: remap,
    );
    _writeCellMask(allowed, allowedCell, target.crop);
    _writeCellMask(
      protected,
      // V1's convention, measured rather than assumed: inside a cell the
      // allowed window and the protected area are disjoint and together cover
      // every pixel. Deriving the head's protected area from its own allowed
      // window keeps that true after the artwork moves, which copying V1's
      // protected mask through the same remap would not.
      target.id == 'head'
          ? _invertedMask(allowedCell)
          : _cellMask(
              source: v1Protected,
              sourceCrop: sourceCrop,
              cell: target.crop,
              remap: remap,
            ),
      target.crop,
    );
    _writeCellMask(
      seams,
      // Nine of the ten body cells carry a seam marker painted exactly at their
      // own recorded anchors. The head does not: measured against V1, none of
      // its 181 seam pixels fall within its single anchor, and the blob sits on
      // green well left of the neck the anchor names. Painting the head's
      // marker from its anchor makes it agree with both its own metadata and
      // the other nine cells.
      target.id == 'head'
          ? _seamMaskFromAnchors(seamAnchors, target.crop)
          : _cellMask(
              source: v1Seams,
              sourceCrop: sourceCrop,
              cell: target.crop,
              remap: remap,
            ),
      target.crop,
    );

    final region = Map<String, dynamic>.from(sourceRegion)
      ..['id'] = target.id
      ..['rigPartId'] = target.rigPartId
      ..['crop'] = target.crop.toJson()
      ..['sourceAsset'] = sourceAsset
      ..['sourceCanvas'] = _canvasOf(sourceAsset)
      ..['outputCanvas'] = <String, int>{
        'width': target.crop.width,
        'height': target.crop.height,
      }
      ..['attachmentAnchor'] = remap.point(
        _scalePoint(
          sourceRegion['attachmentAnchor'] as Map<String, dynamic>,
          anchorSpace,
          target.crop,
        ),
      )
      ..['seamAnchors'] = seamAnchors
      ..['maskRegionId'] = target.id
      ..['transportContent'] = _Rect(
        0,
        0,
        target.crop.width,
        target.crop.height,
      ).toJson()
      ..['resampling'] = 'none-after-provider';
    manifestRegions.add(region);
  }

  if (backHairTarget == null) {
    throw StateError('V4 must contain exactly one back-hair cell.');
  }
  // The rear-hair cell is the one place a variant legitimately replaces the rig
  // asset, because the request picks a length. The canonical variant must still
  // be the length the rig actually carries, or the sheet and the runtime would
  // disagree again by a different route.
  final rigBackHair = rigAssetByPartId[backHairTarget.rigPartId];
  final canonicalBackHair = _backHairVariants
      .firstWhere((variant) => variant.id == _canonicalBackHairId)
      .sourceAsset;
  if (rigBackHair != canonicalBackHair) {
    throw StateError(
      'The $_canonicalBackHairId rear-hair variant must be the rig asset '
      '$rigBackHair, found $canonicalBackHair.',
    );
  }

  final outputDirectory = Directory(_v4Root)..createSync(recursive: true);

  // One guide per rear-hair length. Everything except that single cell is
  // identical, so the variants are the same sheet with a different silhouette
  // in the slot the request is asking the provider to draw.
  // The rear-hair artwork is narrower than the front hair because its source
  // PNG carries more transparent padding, so at equal cell width the visible
  // hair comes out smaller and the front hair overhangs it. Scale the rear hair
  // up until the two match. Derived from the drawn cells rather than hardcoded,
  // so it stays correct if either source is ever replaced.
  final backHairScale = _rearHairScale(
    frontContent: referenceContent['front_hair']!,
    backHairCrop: backHairTarget.crop,
  );

  final guidePathByBackHairId = <String, String>{};
  final backHairContentById = <String, _Rect>{};
  for (final variant in _backHairVariants) {
    final variantGuide = image.Image.from(guide);
    backHairContentById[variant.id] = _drawCell(
      variantGuide,
      variant.sourceAsset,
      backHairTarget.crop,
      scale: backHairScale,
    );
    final fileName = variant.guideFileName(_guideActorId);
    _writePng('${outputDirectory.path}/$fileName', variantGuide);
    guidePathByBackHairId[variant.id] = '$_v4Root/$fileName';
  }
  referenceContent[backHairTarget.id] =
      backHairContentById[_canonicalBackHairId]!;

  // How much of each cell the template artwork actually occupies. Several cells
  // are deliberately larger than their content, so "fill the cell" is the wrong
  // instruction and this records the right one.
  for (final region in manifestRegions) {
    final bounds = referenceContent[region['id'] as String]!;
    final crop = _Rect.fromJson(region['crop'] as Map<String, dynamic>);
    region['referenceContent'] = <String, dynamic>{
      ...bounds.toJson(),
      'coverage': double.parse(
        (bounds.width * bounds.height / (crop.width * crop.height))
            .toStringAsFixed(4),
      ),
    };
  }

  _writePng('${outputDirectory.path}/allowed_regions.png', allowed);
  _writePng('${outputDirectory.path}/protected_regions.png', protected);
  _writePng('${outputDirectory.path}/seam_allowances.png', seams);
  // The assembled reference is an actor-neutral full-body render, not a sheet,
  // so it is canvas independent and shared unchanged across every version.
  File(
    '$_v1Root/assembled_reference.png',
  ).copySync('${outputDirectory.path}/assembled_reference.png');

  final assetPaths = <String, String>{
    'guide': guidePathByBackHairId[_canonicalBackHairId]!,
    'assembledReference': '$_v4Root/assembled_reference.png',
    'allowedRegions': '$_v4Root/allowed_regions.png',
    'protectedRegions': '$_v4Root/protected_regions.png',
    'seamAllowances': '$_v4Root/seam_allowances.png',
    'promptContract': '$_v4Root/prompt_contract.md',
  };
  final assetHashes = <String, String>{
    for (final entry in assetPaths.entries) entry.key: _sha256(entry.value),
  };

  final cellArea = _targets.fold<int>(
    0,
    (sum, target) => sum + target.crop.width * target.crop.height,
  );

  final manifest = <String, dynamic>{
    'contractId': 'character_sheet_v4',
    'contractVersion': 4,
    'canvas': <String, dynamic>{
      'width': _canvasWidth,
      'height': _canvasHeight,
      'providerAspectRatio': '1:1',
      'providerImageSize': '1K',
      'mimeType': 'image/png',
      'backgroundColor': '#00FF00',
    },
    'assets': assetPaths,
    'assetSha256': assetHashes,
    'maskEncoding': v1Manifest['maskEncoding'],
    'lockedRig': v1Manifest['lockedRig'],
    'layout': <String, dynamic>{
      'cellPadding': _cellPadding,
      'cellArea': cellArea,
      'canvasArea': _canvasWidth * _canvasHeight,
      'note':
          'cells keep their native size; the smaller canvas removes green '
          'waste rather than scaling artwork',
    },
    'actorContract': <String, dynamic>{
      'currentGuideActorId': 'default',
      'currentAssembledReferenceActorId': 'default',
      'compatibleActorIds': <String>['default', 'heroine'],
      'sharedRigGeometry': true,
      'frontHairSourceByActor': <String, String>{
        'default':
            'assets/images/characters/rigs/humanoid_v1/hair/front_default.png',
        'heroine':
            'assets/images/characters/rigs/humanoid_v1/hair/front_heroine_v8.png',
      },
      'longBackHairSourceByActor': <String, String>{
        'default':
            'assets/images/characters/rigs/humanoid_v1/hair/back_long.png',
        'heroine':
            'assets/images/characters/rigs/humanoid_v1/hair/back_heroine_long.png',
      },
      'heroineReuseRule':
          'keep every crop, output canvas, mask, anchor, and seam unchanged; '
          'switch only the actor brief and actor-specific hair references',
    },
    'sourceContract': <String, dynamic>{
      'everyRegionDrawsItsRigPartAsset': true,
      'rule':
          'a cell shows the exact asset the rig composes at runtime, fitted to '
          'the cell; anything else shows the provider a character the runtime '
          'cannot reproduce',
      'correctedFromV1': correctedSources,
      'headContentRemap': headRemap.toJson(),
      'headContentRemapReason':
          'V1 drew the head cell from base/head.png, which carries a drawn face '
          'and is trimmed to its own artwork. The rig composes '
          'faces/head_base.png, whose head is smaller and inset once fitted to '
          'the same cell, so the head allowed window, protected area, seam '
          'allowance, and anchors were moved with it',
    },
    'transport': <String, dynamic>{
      'purpose':
          'pack the exact Sprite Studio parts and one selected back-hair cell '
          'into the smallest supported square sheet',
      'extractFrom': 'crop',
      'outputPolicy': 'preserve each crop exactly as outputCanvas',
      'originalRuntimeAssetsRemainImmutable': true,
    },
    'selectionContract': <String, dynamic>{
      'backHairRegionId': 'back_hair_selected',
      'acceptedValues': <String>['short', 'medium', 'long', 'none'],
      'noneMeansEmptyRegion': true,
      'frontHairRegionId': 'front_hair',
      'guideByBackHairId': guidePathByBackHairId,
      'canonicalBackHairId': _canonicalBackHairId,
      'rule':
          'send the guide whose rear-hair silhouette matches '
          'BACK_HAIR_SELECTION; every variant shares the same cells, masks, '
          'anchors, and seams',
      'noneUsesGuide': _canonicalBackHairId,
      'noneLeavesRegionGreen': true,
      'referenceContentByBackHairId': <String, dynamic>{
        for (final entry in backHairContentById.entries)
          entry.key: entry.value.toJson(),
      },
      'rearHairReferenceScale': backHairScale,
      'rearHairReferenceScaleReason':
          'the rear-hair source carries more transparent padding than the '
          'front-hair source, so at equal cell width its visible art was '
          'narrower and the front hair overhung it; the artwork is enlarged '
          'inside the unchanged cell until the two widths match',
    },
    'guideVariantSha256': <String, String>{
      for (final entry in guidePathByBackHairId.entries)
        entry.key: _sha256(entry.value),
    },
    'backHairSourceByIdForActor': <String, dynamic>{
      _guideActorId: <String, String>{
        for (final variant in _backHairVariants)
          variant.id: variant.sourceAsset,
      },
    },
    'rules': <String, dynamic>{
      'cropCoordinatesAreInclusiveExclusive': true,
      'resizeRegions': false,
      'cropToVisiblePixels': false,
      'inactiveOptionalRegionsRemainGreen': true,
      'visibleCellBorders': false,
    },
    'regions': manifestRegions,
  };
  File('${outputDirectory.path}/crop_manifest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  final fill = cellArea / (_canvasWidth * _canvasHeight) * 100;
  stdout.writeln('Generated character_sheet_v4 locally.');
  stdout.writeln('Canvas: $_canvasWidth x $_canvasHeight (1:1 1K)');
  stdout.writeln('Regions: ${manifestRegions.length}');
  stdout.writeln('Cell padding: $_cellPadding px');
  stdout.writeln('Cell fill: ${fill.toStringAsFixed(1)}%');
  stdout.writeln(
    'Guides for $_guideActorId: '
    '${_backHairVariants.map((variant) => variant.id).join(', ')}',
  );
  for (final entry in correctedSources.entries) {
    stdout.writeln(
      'Corrected ${entry.key}: ${entry.value['wasInV1']} -> '
      '${entry.value['nowUsesRigPart']}',
    );
  }
  stdout.writeln('No network or provider request was used.');
}

void _validateTargetSizesAgainstRig(Map<String, dynamic> rigManifest) {
  final rigParts = <String, Map<String, dynamic>>{
    for (final raw in rigManifest['parts'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw,
  };
  for (final target in _targets) {
    final rigPart = rigParts[target.rigPartId];
    if (rigPart == null) {
      throw StateError('Missing Sprite Studio rig part ${target.rigPartId}.');
    }
    final size = rigPart['size'] as Map<String, dynamic>;
    final expectedWidth = (size['width'] as num).toDouble().round();
    final expectedHeight = (size['height'] as num).toDouble().round();
    if (target.crop.width != expectedWidth ||
        target.crop.height != expectedHeight) {
      throw StateError(
        '${target.id} must match Sprite Studio rig part ${target.rigPartId}: '
        '${expectedWidth}x$expectedHeight, found '
        '${target.crop.width}x${target.crop.height}.',
      );
    }
  }
}

void _validateTargetLayout() {
  for (final target in _targets) {
    if (target.crop.x < _cellPadding ||
        target.crop.y < _cellPadding ||
        target.crop.right > _canvasWidth - _cellPadding ||
        target.crop.bottom > _canvasHeight - _cellPadding) {
      throw StateError(
        '${target.id} breaks the $_cellPadding px V4 canvas margin.',
      );
    }
  }
  for (var index = 0; index < _targets.length; index++) {
    for (
      var otherIndex = index + 1;
      otherIndex < _targets.length;
      otherIndex++
    ) {
      final first = _targets[index];
      final second = _targets[otherIndex];
      if (first.crop.overlaps(second.crop)) {
        throw StateError('${first.id} overlaps ${second.id}.');
      }
      if (first.crop.gapTo(second.crop) < _cellPadding) {
        throw StateError(
          '${first.id} and ${second.id} are closer than $_cellPadding px.',
        );
      }
    }
  }
}

/// Draws one source PNG into its cell at the cell's exact native size, and
/// returns the opaque part's bounds in cell-local coordinates.
///
/// The bounds matter because several cells are deliberately larger than the
/// artwork they hold. The rear-hair cell is sized for the longest style, so a
/// short style leaves most of the cell empty. A provider told only "here is a
/// cell" would fill it and return hair far larger than the template intends, so
/// the measured extent is published in the manifest and in the prompt contract.
_Rect _drawCell(
  image.Image destination,
  String sourceAsset,
  _Rect crop, {
  double scale = 1,
}) {
  final fitted = _fittedArtwork(sourceAsset, crop);
  if (scale == 1) {
    image.drawImage(destination, fitted, dstX: crop.x, dstY: crop.y);
    return _opaqueBounds(fitted);
  }

  // Enlarging happens inside the existing cell: the rig box does not change, so
  // the locked geometry and every recorded hash stay untouched. Only the
  // artwork inside the box grows.
  final before = _opaqueBounds(fitted);
  final grown = image.copyResize(
    fitted,
    width: (crop.width * scale).round(),
    height: (crop.height * scale).round(),
    interpolation: image.Interpolation.linear,
  );
  final after = _opaqueBounds(grown);

  // Keep the crown where it was and widen symmetrically, then pull back inside
  // the cell if the taller styles would spill past its edges.
  var dx = (before.x + before.width / 2) - (after.x + after.width / 2);
  var dy = before.y.toDouble() - after.y;
  dx = dx.clamp(-after.x.toDouble(), (crop.width - after.right).toDouble());
  dy = dy.clamp(-after.y.toDouble(), (crop.height - after.bottom).toDouble());

  // Compose through a cell-sized buffer so nothing can bleed into a neighbour.
  final cell = image.Image(crop.width, crop.height)
    ..channels = image.Channels.rgba;
  image.fill(cell, image.getColor(0, 0, 0, 0));
  // dstW/dstH must be explicit: drawImage otherwise shrinks a source larger
  // than the destination back down to fit, which would undo the enlargement.
  image.drawImage(
    cell,
    grown,
    dstX: dx.round(),
    dstY: dy.round(),
    dstW: grown.width,
    dstH: grown.height,
  );
  final placed = _opaqueBounds(cell);
  if (placed.x < 0 ||
      placed.y < 0 ||
      placed.right > crop.width ||
      placed.bottom > crop.height) {
    throw StateError('Scaled artwork for $sourceAsset does not fit its cell.');
  }
  image.drawImage(destination, cell, dstX: crop.x, dstY: crop.y);
  return placed;
}

/// How much to enlarge the rear hair so it matches the front hair's width.
///
/// Capped so the longest style still fits its cell: the cell was sized for the
/// long style, which already reaches near the bottom, so there is far less room
/// to grow vertically than horizontally.
double _rearHairScale({
  required _Rect frontContent,
  required _Rect backHairCrop,
}) {
  final contentByVariant = <String, _Rect>{
    for (final variant in _backHairVariants)
      variant.id: _opaqueBounds(
        _fittedArtwork(variant.sourceAsset, backHairCrop),
      ),
  };
  final canonical = contentByVariant[_canonicalBackHairId]!;
  final wanted = frontContent.width / canonical.width;

  var limit = double.infinity;
  for (final content in contentByVariant.values) {
    final byWidth = backHairCrop.width / content.width;
    final byHeight = backHairCrop.height / content.height;
    final smaller = byWidth < byHeight ? byWidth : byHeight;
    if (smaller < limit) limit = smaller;
  }
  final scale = wanted < limit ? wanted : limit;
  return scale < 1 ? 1 : double.parse(scale.toStringAsFixed(4));
}

image.Image _fittedArtwork(String sourceAsset, _Rect crop) {
  final artwork = _decode(sourceAsset)..channels = image.Channels.rgba;
  return image.copyResize(
    artwork,
    width: crop.width,
    height: crop.height,
    interpolation: image.Interpolation.linear,
  );
}

/// Smallest rectangle covering every pixel with any alpha, or the whole image
/// when it is fully transparent.
_Rect _opaqueBounds(image.Image value) {
  var minX = value.width;
  var minY = value.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < value.height; y++) {
    for (var x = 0; x < value.width; x++) {
      if (image.getAlpha(value.getPixel(x, y)) == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return _Rect(0, 0, value.width, value.height);
  return _Rect(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

image.Image _solidImage(int red, int green, int blue) {
  final result = image.Image(_canvasWidth, _canvasHeight)
    ..channels = image.Channels.rgb;
  image.fill(result, image.getColor(red, green, blue));
  return result;
}

image.Image _decode(String path) {
  final decoded = image.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) {
    throw FormatException('Could not decode $path.');
  }
  return decoded;
}

/// Lifts one V1 mask region into a cell-sized black-and-white buffer, moving it
/// through [remap] on the way so a mask still covers the artwork it describes
/// after that artwork changes size inside an unchanged cell.
///
/// Sampling runs backwards, from each destination pixel to its source, so a
/// shrinking remap cannot leave holes in the result.
image.Image _cellMask({
  required image.Image source,
  required _Rect sourceCrop,
  required _Rect cell,
  _ContentRemap remap = _ContentRemap.identity,
}) {
  final resized = image.copyResize(
    image.copyCrop(
      source,
      sourceCrop.x,
      sourceCrop.y,
      sourceCrop.width,
      sourceCrop.height,
    ),
    width: cell.width,
    height: cell.height,
    interpolation: image.Interpolation.nearest,
  );
  final result = image.Image(cell.width, cell.height)
    ..channels = image.Channels.rgb;
  image.fill(result, image.getColor(0, 0, 0));
  for (var y = 0; y < cell.height; y++) {
    for (var x = 0; x < cell.width; x++) {
      final source = remap.inverse(x, y);
      final sourceX = source.$1.round();
      final sourceY = source.$2.round();
      if (sourceX < 0 ||
          sourceY < 0 ||
          sourceX >= cell.width ||
          sourceY >= cell.height) {
        continue;
      }
      final pixel = resized.getPixel(sourceX, sourceY);
      if (image.getRed(pixel) >= 250 &&
          image.getGreen(pixel) >= 250 &&
          image.getBlue(pixel) >= 250) {
        result.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }
  return result;
}

/// One filled disc per seam anchor, the same shape the other nine body cells
/// already carry, clipped to the cell.
image.Image _seamMaskFromAnchors(
  List<Map<String, double>> anchors,
  _Rect cell,
) {
  final result = image.Image(cell.width, cell.height)
    ..channels = image.Channels.rgb;
  image.fill(result, image.getColor(0, 0, 0));
  for (final anchor in anchors) {
    final radius = anchor['radius']!;
    for (var y = 0; y < cell.height; y++) {
      for (var x = 0; x < cell.width; x++) {
        final dx = x + 0.5 - anchor['x']!;
        final dy = y + 0.5 - anchor['y']!;
        if (dx * dx + dy * dy <= radius * radius) {
          result.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
  }
  return result;
}

/// Every pixel the mask does not mark. Used for the head, where V1 keeps the
/// allowed window and the protected area exactly complementary.
image.Image _invertedMask(image.Image mask) {
  final result = image.Image(mask.width, mask.height)
    ..channels = image.Channels.rgb;
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      final white = image.getRed(mask.getPixel(x, y)) >= 250;
      result.setPixelRgba(x, y, white ? 0 : 255, white ? 0 : 255,
          white ? 0 : 255, 255);
    }
  }
  return result;
}

void _writeCellMask(image.Image destination, image.Image cellMask, _Rect cell) {
  for (var y = 0; y < cellMask.height; y++) {
    for (var x = 0; x < cellMask.width; x++) {
      if (image.getRed(cellMask.getPixel(x, y)) < 250) continue;
      destination.setPixelRgba(cell.x + x, cell.y + y, 255, 255, 255, 255);
    }
  }
}

Map<String, String> _rigAssetsByPartId(Map<String, dynamic> rigManifest) => {
  for (final raw in rigManifest['parts'] as List<dynamic>)
    (raw as Map<String, dynamic>)['id'] as String: raw['asset'] as String,
};

Map<String, int> _canvasOf(String sourceAsset) {
  final decoded = _decode(sourceAsset);
  return <String, int>{'width': decoded.width, 'height': decoded.height};
}

Map<String, double> _scalePoint(
  Map<String, dynamic> point,
  Map<String, dynamic> sourceCanvas,
  _Rect outputCanvas,
) => <String, double>{
  'x':
      (point['x'] as num).toDouble() *
      outputCanvas.width /
      (sourceCanvas['width'] as num).toDouble(),
  'y':
      (point['y'] as num).toDouble() *
      outputCanvas.height /
      (sourceCanvas['height'] as num).toDouble(),
};

List<Map<String, double>> _scaleSeamAnchors(
  List<dynamic> anchors,
  Map<String, dynamic> sourceCanvas,
  _Rect outputCanvas,
) {
  final scaleX = outputCanvas.width / (sourceCanvas['width'] as num).toDouble();
  final scaleY =
      outputCanvas.height / (sourceCanvas['height'] as num).toDouble();
  final radiusScale = (scaleX + scaleY) / 2;
  return anchors
      .map((raw) {
        final anchor = raw as Map<String, dynamic>;
        return <String, double>{
          'x': (anchor['x'] as num).toDouble() * scaleX,
          'y': (anchor['y'] as num).toDouble() * scaleY,
          'radius': (anchor['radius'] as num).toDouble() * radiusScale,
        };
      })
      .toList(growable: false);
}

void _writePng(String path, image.Image value) {
  File(path).writeAsBytesSync(image.encodePng(value));
}

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

class _BackHairVariant {
  const _BackHairVariant({required this.id, required this.sourceAsset});

  final String id;
  final String sourceAsset;

  String guideFileName(String actorId) => 'guide_${actorId}_$id.png';
}

/// Moves cell-local geometry from where one source PNG's artwork sits in a cell
/// to where another's sits in that same cell.
///
/// The head needs this. `base/head.png` is trimmed to its own artwork and fills
/// nearly the whole cell, while the rig's `faces/head_base.png` is a large
/// square canvas whose head, once fitted to the cell, is smaller and inset. The
/// cell, the crop, and the rig box do not change; only the artwork inside them
/// does, so every mask, anchor, and seam authored against the old artwork has
/// to travel the same distance.
class _ContentRemap {
  const _ContentRemap({
    required this.scaleX,
    required this.scaleY,
    required this.previous,
    required this.current,
  });

  factory _ContentRemap.between({
    required String previousAsset,
    required String currentAsset,
    required _Rect cell,
  }) {
    final previous = _opaqueBounds(_fittedArtwork(previousAsset, cell));
    final current = _opaqueBounds(_fittedArtwork(currentAsset, cell));
    return _ContentRemap(
      scaleX: current.width / previous.width,
      scaleY: current.height / previous.height,
      previous: previous,
      current: current,
    );
  }

  static const identity = _ContentRemap(
    scaleX: 1,
    scaleY: 1,
    previous: _Rect(0, 0, 1, 1),
    current: _Rect(0, 0, 1, 1),
  );

  final double scaleX;
  final double scaleY;
  final _Rect previous;
  final _Rect current;

  bool get isIdentity => identical(this, identity);

  double _mapX(double x) =>
      isIdentity ? x : current.x + (x - previous.x) * scaleX;

  double _mapY(double y) =>
      isIdentity ? y : current.y + (y - previous.y) * scaleY;

  /// Where a destination pixel reads from in the pre-remap cell.
  (double, double) inverse(int x, int y) {
    if (isIdentity) return (x.toDouble(), y.toDouble());
    return (
      previous.x + (x - current.x) / scaleX,
      previous.y + (y - current.y) / scaleY,
    );
  }

  /// Identity returns its input untouched rather than a rounded copy, so a cell
  /// that did not move keeps the exact values it already published.
  Map<String, double> point(Map<String, double> value) => isIdentity
      ? value
      : <String, double>{
          'x': _round(_mapX(value['x']!)),
          'y': _round(_mapY(value['y']!)),
        };

  Map<String, double> anchor(Map<String, double> value) => isIdentity
      ? value
      : <String, double>{
          ...point(value),
          'radius': _round(value['radius']! * (scaleX + scaleY) / 2),
        };

  static double _round(double value) =>
      double.parse(value.toStringAsFixed(2));

  Map<String, dynamic> toJson() => <String, dynamic>{
    'previousContent': previous.toJson(),
    'currentContent': current.toJson(),
    'scaleX': _round(scaleX),
    'scaleY': _round(scaleY),
  };
}

class _TargetSpec {
  const _TargetSpec({
    required this.id,
    required this.sourceRegionId,
    required this.crop,
    String? rigPartId,
  }) : _rigPartId = rigPartId;

  final String id;
  final String sourceRegionId;
  final _Rect crop;
  final String? _rigPartId;

  String get rigPartId => _rigPartId ?? id;
}

class _Rect {
  const _Rect(this.x, this.y, this.width, this.height);

  factory _Rect.fromJson(Map<String, dynamic> json) => _Rect(
    (json['x'] as num).toInt(),
    (json['y'] as num).toInt(),
    (json['width'] as num).toInt(),
    (json['height'] as num).toInt(),
  );

  final int x;
  final int y;
  final int width;
  final int height;

  int get right => x + width;
  int get bottom => y + height;

  bool overlaps(_Rect other) =>
      x < other.right &&
      right > other.x &&
      y < other.bottom &&
      bottom > other.y;

  /// Smallest gap between two non-overlapping cells, on either axis.
  int gapTo(_Rect other) {
    final horizontal = x >= other.right
        ? x - other.right
        : other.x >= right
        ? other.x - right
        : -1;
    final vertical = y >= other.bottom
        ? y - other.bottom
        : other.y >= bottom
        ? other.y - bottom
        : -1;
    if (horizontal < 0 && vertical < 0) return -1;
    if (horizontal < 0) return vertical;
    if (vertical < 0) return horizontal;
    return horizontal > vertical ? horizontal : vertical;
  }

  Map<String, int> toJson() => <String, int>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}
