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
  // Bottom row, read left to right in limb order: right arm, left arm, left leg.
  // Side ownership is a contract rule, so cells are grouped by side rather than
  // packed in whatever order fits best.
  _TargetSpec(
    id: 'upper_arm_right',
    sourceRegionId: 'upper_arm_right',
    crop: _Rect(18, 859, 67, 118),
  ),
  _TargetSpec(
    id: 'lower_arm_right',
    sourceRegionId: 'lower_arm_right',
    crop: _Rect(103, 859, 77, 145),
  ),
  _TargetSpec(
    id: 'upper_arm_left',
    sourceRegionId: 'upper_arm_left',
    crop: _Rect(198, 859, 78, 128),
  ),
  _TargetSpec(
    id: 'lower_arm_left',
    sourceRegionId: 'lower_arm_left',
    crop: _Rect(294, 859, 86, 129),
  ),
  _TargetSpec(
    id: 'upper_leg_left',
    sourceRegionId: 'upper_leg_left',
    crop: _Rect(398, 859, 85, 141),
  ),
  _TargetSpec(
    id: 'lower_leg_left',
    sourceRegionId: 'lower_leg_left',
    crop: _Rect(501, 859, 88, 140),
  ),
  // The two right-leg cells are 150 and 156 tall, which the bottom row cannot
  // take, so they occupy the right-hand strip in hip-to-ankle order.
  _TargetSpec(
    id: 'upper_leg_right',
    sourceRegionId: 'upper_leg_right',
    crop: _Rect(912, 18, 94, 150),
  ),
  _TargetSpec(
    id: 'lower_leg_right',
    sourceRegionId: 'lower_leg_right',
    crop: _Rect(912, 186, 84, 156),
  ),
];

void main() {
  final rigManifest =
      jsonDecode(File(_rigManifestPath).readAsStringSync())
          as Map<String, dynamic>;
  _validateTargetSizesAgainstRig(rigManifest);
  _validateTargetLayout();

  final v1Manifest =
      jsonDecode(File('$_v1Root/crop_manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final v1Regions = <String, Map<String, dynamic>>{
    for (final raw in v1Manifest['regions'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw,
  };

  final guide = _solidImage(0, 255, 0);
  final allowed = _solidImage(0, 0, 0);
  final protected = _solidImage(0, 0, 0);
  final seams = _solidImage(0, 0, 0);

  final v1Allowed = _decode('$_v1Root/allowed_regions.png');
  final v1Protected = _decode('$_v1Root/protected_regions.png');
  final v1Seams = _decode('$_v1Root/seam_allowances.png');
  final manifestRegions = <Map<String, dynamic>>[];

  for (final target in _targets) {
    final sourceRegion = v1Regions[target.sourceRegionId]!;
    final sourceCanvas = sourceRegion['outputCanvas'] as Map<String, dynamic>;
    final sourceAsset = sourceRegion['sourceAsset'] as String;
    final sourceArtwork = _decode(sourceAsset)..channels = image.Channels.rgba;
    final resizedArtwork = image.copyResize(
      sourceArtwork,
      width: target.crop.width,
      height: target.crop.height,
      interpolation: image.Interpolation.linear,
    );
    image.drawImage(
      guide,
      resizedArtwork,
      dstX: target.crop.x,
      dstY: target.crop.y,
    );

    final sourceCrop = _Rect.fromJson(
      sourceRegion['crop'] as Map<String, dynamic>,
    );
    _copyMask(
      source: v1Allowed,
      destinationImage: allowed,
      sourceCrop: sourceCrop,
      destinationRect: target.crop,
    );
    _copyMask(
      source: v1Protected,
      destinationImage: protected,
      sourceCrop: sourceCrop,
      destinationRect: target.crop,
    );
    _copyMask(
      source: v1Seams,
      destinationImage: seams,
      sourceCrop: sourceCrop,
      destinationRect: target.crop,
    );

    final region = Map<String, dynamic>.from(sourceRegion)
      ..['id'] = target.id
      ..['rigPartId'] = target.rigPartId
      ..['crop'] = target.crop.toJson()
      ..['sourceCanvas'] = Map<String, dynamic>.from(sourceCanvas)
      ..['outputCanvas'] = <String, int>{
        'width': target.crop.width,
        'height': target.crop.height,
      }
      ..['attachmentAnchor'] = _scalePoint(
        sourceRegion['attachmentAnchor'] as Map<String, dynamic>,
        sourceCanvas,
        target.crop,
      )
      ..['seamAnchors'] = _scaleSeamAnchors(
        sourceRegion['seamAnchors'] as List<dynamic>? ?? const <dynamic>[],
        sourceCanvas,
        target.crop,
      )
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

  final outputDirectory = Directory(_v4Root)..createSync(recursive: true);
  _writePng('${outputDirectory.path}/guide.png', guide);
  _writePng('${outputDirectory.path}/allowed_regions.png', allowed);
  _writePng('${outputDirectory.path}/protected_regions.png', protected);
  _writePng('${outputDirectory.path}/seam_allowances.png', seams);
  // The assembled reference is an actor-neutral full-body render, not a sheet,
  // so it is canvas independent and shared unchanged across every version.
  File(
    '$_v1Root/assembled_reference.png',
  ).copySync('${outputDirectory.path}/assembled_reference.png');

  final assetPaths = <String, String>{
    'guide': '$_v4Root/guide.png',
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

void _copyMask({
  required image.Image source,
  required image.Image destinationImage,
  required _Rect sourceCrop,
  required _Rect destinationRect,
}) {
  final crop = image.copyCrop(
    source,
    sourceCrop.x,
    sourceCrop.y,
    sourceCrop.width,
    sourceCrop.height,
  );
  final resized = image.copyResize(
    crop,
    width: destinationRect.width,
    height: destinationRect.height,
    interpolation: image.Interpolation.nearest,
  );
  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      if (image.getRed(pixel) >= 250 &&
          image.getGreen(pixel) >= 250 &&
          image.getBlue(pixel) >= 250) {
        destinationImage.setPixelRgba(
          destinationRect.x + x,
          destinationRect.y + y,
          255,
          255,
          255,
          255,
        );
      }
    }
  }
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
