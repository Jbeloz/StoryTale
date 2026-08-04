import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _canvasWidth = 4096;
const _canvasHeight = 1024;
const _v1Root =
    'assets/images/characters/generation_templates/humanoid_v1/'
    'character_sheet_v1';
const _v3Root =
    'assets/images/characters/generation_templates/humanoid_v1/'
    'character_sheet_v3';
const _rigManifestPath = 'assets/images/characters/rigs/humanoid_v1/rig.json';

const _targets = <_TargetSpec>[
  _TargetSpec(
    id: 'back_hair_short',
    sourceRegionId: 'back_hair_short',
    crop: _Rect(32, 112, 429, 800),
  ),
  _TargetSpec(
    id: 'back_hair_medium',
    sourceRegionId: 'back_hair_medium',
    crop: _Rect(493, 112, 429, 800),
  ),
  _TargetSpec(
    id: 'back_hair_long',
    sourceRegionId: 'back_hair_long',
    crop: _Rect(954, 112, 429, 800),
  ),
  _TargetSpec(
    id: 'front_hair',
    sourceRegionId: 'front_hair',
    crop: _Rect(1415, 293, 429, 438),
  ),
  _TargetSpec(
    id: 'head',
    sourceRegionId: 'head',
    crop: _Rect(1876, 329, 357, 367),
  ),
  _TargetSpec(
    id: 'torso',
    sourceRegionId: 'torso',
    crop: _Rect(2265, 395, 165, 234),
  ),
  _TargetSpec(
    id: 'upper_arm_right',
    sourceRegionId: 'upper_arm_right',
    crop: _Rect(2567, 291, 67, 118),
  ),
  _TargetSpec(
    id: 'upper_leg_right',
    sourceRegionId: 'upper_leg_right',
    crop: _Rect(2553, 600, 94, 150),
  ),
  _TargetSpec(
    id: 'lower_arm_right',
    sourceRegionId: 'lower_arm_right',
    crop: _Rect(2961, 278, 77, 145),
  ),
  _TargetSpec(
    id: 'lower_leg_right',
    sourceRegionId: 'lower_leg_right',
    crop: _Rect(2958, 597, 84, 156),
  ),
  _TargetSpec(
    id: 'upper_arm_left',
    sourceRegionId: 'upper_arm_left',
    crop: _Rect(3361, 286, 78, 128),
  ),
  _TargetSpec(
    id: 'upper_leg_left',
    sourceRegionId: 'upper_leg_left',
    crop: _Rect(3358, 605, 85, 141),
  ),
  _TargetSpec(
    id: 'lower_arm_left',
    sourceRegionId: 'lower_arm_left',
    crop: _Rect(3757, 286, 86, 129),
  ),
  _TargetSpec(
    id: 'lower_leg_left',
    sourceRegionId: 'lower_leg_left',
    crop: _Rect(3756, 605, 88, 140),
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

  final outputDirectory = Directory(_v3Root)..createSync(recursive: true);
  _writePng('${outputDirectory.path}/guide.png', guide);
  _writePng('${outputDirectory.path}/allowed_regions.png', allowed);
  _writePng('${outputDirectory.path}/protected_regions.png', protected);
  _writePng('${outputDirectory.path}/seam_allowances.png', seams);
  File(
    '$_v1Root/assembled_reference.png',
  ).copySync('${outputDirectory.path}/assembled_reference.png');

  final assetPaths = <String, String>{
    'guide': '$_v3Root/guide.png',
    'assembledReference': '$_v3Root/assembled_reference.png',
    'allowedRegions': '$_v3Root/allowed_regions.png',
    'protectedRegions': '$_v3Root/protected_regions.png',
    'seamAllowances': '$_v3Root/seam_allowances.png',
    'promptContract': '$_v3Root/prompt_contract.md',
  };
  final assetHashes = <String, String>{
    for (final entry in assetPaths.entries) entry.key: _sha256(entry.value),
  };

  final manifest = <String, dynamic>{
    'contractId': 'character_sheet_v3',
    'contractVersion': 3,
    'canvas': <String, dynamic>{
      'width': _canvasWidth,
      'height': _canvasHeight,
      'providerAspectRatio': '4:1',
      'providerImageSize': '2K',
      'mimeType': 'image/png',
      'backgroundColor': '#00FF00',
    },
    'assets': assetPaths,
    'assetSha256': assetHashes,
    'maskEncoding': v1Manifest['maskEncoding'],
    'lockedRig': v1Manifest['lockedRig'],
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
          'pack the complete front/back hair option catalog and exact Sprite Studio parts into one landscape sheet',
      'extractFrom': 'crop',
      'outputPolicy': 'preserve each crop exactly as outputCanvas',
      'originalRuntimeAssetsRemainImmutable': true,
    },
    'selectionContract': <String, dynamic>{
      'frontHairRegionId': 'front_hair',
      'backHairRegionById': <String, String?>{
        'short': 'back_hair_short',
        'medium': 'back_hair_medium',
        'long': 'back_hair_long',
        'none': null,
      },
      'generatedBackHairOptions': <String>['short', 'medium', 'long'],
      'defaultBackHairId': 'medium',
      'noneMeansHideBackHairAtRuntime': true,
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

  stdout.writeln('Generated character_sheet_v3 locally.');
  stdout.writeln('Canvas: $_canvasWidth x $_canvasHeight (4:1 2K)');
  stdout.writeln('Regions: ${manifestRegions.length}');
  stdout.writeln('Guide actor: default; compatible future actor: heroine');
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
    if (target.crop.x < 0 ||
        target.crop.y < 0 ||
        target.crop.right > _canvasWidth ||
        target.crop.bottom > _canvasHeight) {
      throw StateError('${target.id} is outside the V3 canvas.');
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
  });

  final String id;
  final String sourceRegionId;
  final _Rect crop;

  String get rigPartId => id.startsWith('back_hair_') ? 'back_hair' : id;
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

  Map<String, int> toJson() => <String, int>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}
