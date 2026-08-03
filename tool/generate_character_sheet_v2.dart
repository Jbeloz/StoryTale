import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _canvasSize = 2048;
const _v1Root =
    'assets/images/characters/generation_templates/humanoid_v1/'
    'character_sheet_v1';
const _v2Root =
    'assets/images/characters/generation_templates/humanoid_v1/'
    'character_sheet_v2';

const _targets = <_TargetSpec>[
  _TargetSpec(
    id: 'back_hair_selected',
    sourceRegionId: 'back_hair_medium',
    maskSourceRegionIds: <String>[
      'back_hair_short',
      'back_hair_medium',
      'back_hair_long',
    ],
    crop: _Rect(32, 32, 576, 988),
  ),
  _TargetSpec(
    id: 'front_hair',
    sourceRegionId: 'front_hair',
    crop: _Rect(640, 32, 576, 576),
  ),
  _TargetSpec(
    id: 'head',
    sourceRegionId: 'head',
    crop: _Rect(1280, 32, 512, 512),
  ),
  _TargetSpec(
    id: 'torso',
    sourceRegionId: 'torso',
    crop: _Rect(1280, 608, 360, 512),
  ),
  _TargetSpec(
    id: 'upper_arm_right',
    sourceRegionId: 'upper_arm_right',
    crop: _Rect(1680, 608, 67, 118),
  ),
  _TargetSpec(
    id: 'upper_arm_left',
    sourceRegionId: 'upper_arm_left',
    crop: _Rect(1790, 608, 78, 128),
  ),
  _TargetSpec(
    id: 'lower_arm_right',
    sourceRegionId: 'lower_arm_right',
    crop: _Rect(1680, 768, 77, 145),
  ),
  _TargetSpec(
    id: 'lower_arm_left',
    sourceRegionId: 'lower_arm_left',
    crop: _Rect(1790, 768, 86, 129),
  ),
  _TargetSpec(
    id: 'upper_leg_right',
    sourceRegionId: 'upper_leg_right',
    crop: _Rect(1680, 960, 94, 150),
  ),
  _TargetSpec(
    id: 'upper_leg_left',
    sourceRegionId: 'upper_leg_left',
    crop: _Rect(1800, 960, 85, 141),
  ),
  _TargetSpec(
    id: 'lower_leg_right',
    sourceRegionId: 'lower_leg_right',
    crop: _Rect(1680, 1152, 84, 156),
  ),
  _TargetSpec(
    id: 'lower_leg_left',
    sourceRegionId: 'lower_leg_left',
    crop: _Rect(1800, 1152, 88, 140),
  ),
];

void main() {
  final v1ManifestFile = File('$_v1Root/crop_manifest.json');
  final v1Manifest =
      jsonDecode(v1ManifestFile.readAsStringSync()) as Map<String, dynamic>;
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
    final outputCanvas = sourceRegion['outputCanvas'] as Map<String, dynamic>;
    final content = _contain(
      sourceWidth: (outputCanvas['width'] as num).toInt(),
      sourceHeight: (outputCanvas['height'] as num).toInt(),
      targetWidth: target.crop.width,
      targetHeight: target.crop.height,
    );

    final sourceAsset = sourceRegion['sourceAsset'] as String;
    final sourceArtwork = _decode(sourceAsset)..channels = image.Channels.rgba;
    final resizedArtwork = image.copyResize(
      sourceArtwork,
      width: content.width,
      height: content.height,
      interpolation: image.Interpolation.linear,
    );
    image.drawImage(
      guide,
      resizedArtwork,
      dstX: target.crop.x + content.x,
      dstY: target.crop.y + content.y,
    );

    for (final sourceRegionId in target.effectiveMaskSourceRegionIds) {
      final maskRegion = v1Regions[sourceRegionId]!;
      _unionMask(
        source: v1Allowed,
        destination: allowed,
        sourceCrop: _Rect.fromJson(maskRegion['crop'] as Map<String, dynamic>),
        destinationX: target.crop.x + content.x,
        destinationY: target.crop.y + content.y,
        destinationWidth: content.width,
        destinationHeight: content.height,
      );
      _unionMask(
        source: v1Protected,
        destination: protected,
        sourceCrop: _Rect.fromJson(maskRegion['crop'] as Map<String, dynamic>),
        destinationX: target.crop.x + content.x,
        destinationY: target.crop.y + content.y,
        destinationWidth: content.width,
        destinationHeight: content.height,
      );
      _unionMask(
        source: v1Seams,
        destination: seams,
        sourceCrop: _Rect.fromJson(maskRegion['crop'] as Map<String, dynamic>),
        destinationX: target.crop.x + content.x,
        destinationY: target.crop.y + content.y,
        destinationWidth: content.width,
        destinationHeight: content.height,
      );
    }

    final region = Map<String, dynamic>.from(sourceRegion)
      ..['id'] = target.id
      ..['crop'] = target.crop.toJson()
      ..['maskRegionId'] = target.id
      ..['transportContent'] = content.toJson()
      ..['resampling'] = 'linear-once-after-masking';
    if (target.id == 'back_hair_selected') {
      region
        ..['sourceAsset'] = v1Regions['back_hair_medium']!['sourceAsset']
        ..['sourceVariants'] = <String, dynamic>{
          'short': v1Regions['back_hair_short']!['sourceAsset'],
          'medium': v1Regions['back_hair_medium']!['sourceAsset'],
          'long': v1Regions['back_hair_long']!['sourceAsset'],
          'none': null,
        }
        ..['selectionField'] = 'backHairId';
    }
    manifestRegions.add(region);
  }

  final outputDirectory = Directory(_v2Root)..createSync(recursive: true);
  _writePng('${outputDirectory.path}/guide.png', guide);
  _writePng('${outputDirectory.path}/allowed_regions.png', allowed);
  _writePng('${outputDirectory.path}/protected_regions.png', protected);
  _writePng('${outputDirectory.path}/seam_allowances.png', seams);
  File(
    '$_v1Root/assembled_reference.png',
  ).copySync('${outputDirectory.path}/assembled_reference.png');

  final assetPaths = <String, String>{
    'guide': '$_v2Root/guide.png',
    'assembledReference': '$_v2Root/assembled_reference.png',
    'allowedRegions': '$_v2Root/allowed_regions.png',
    'protectedRegions': '$_v2Root/protected_regions.png',
    'seamAllowances': '$_v2Root/seam_allowances.png',
    'promptContract': '$_v2Root/prompt_contract.md',
  };
  final assetHashes = <String, String>{
    for (final entry in assetPaths.entries) entry.key: _sha256(entry.value),
  };

  final manifest = <String, dynamic>{
    'contractId': 'character_sheet_v2',
    'contractVersion': 2,
    'canvas': <String, dynamic>{
      'width': _canvasSize,
      'height': _canvasSize,
      'providerImageSize': '2K',
      'mimeType': 'image/png',
      'backgroundColor': '#00FF00',
    },
    'assets': assetPaths,
    'assetSha256': assetHashes,
    'maskEncoding': v1Manifest['maskEncoding'],
    'lockedRig': v1Manifest['lockedRig'],
    'transport': <String, dynamic>{
      'purpose':
          'resize hair transport only while preserving reviewed head and torso sizes and native limb cells',
      'extractFrom': 'transportContent',
      'outputPolicy': 'resize once to outputCanvas after masking',
      'originalRuntimeAssetsRemainImmutable': true,
    },
    'selectionContract': <String, dynamic>{
      'backHairRegionId': 'back_hair_selected',
      'acceptedValues': <String>['short', 'medium', 'long', 'none'],
      'noneMeansEmptyRegion': true,
    },
    'rules': <String, dynamic>{
      'cropCoordinatesAreInclusiveExclusive': true,
      'resizeRegions': true,
      'cropToVisiblePixels': false,
      'inactiveOptionalRegionsRemainGreen': true,
      'visibleCellBorders': false,
    },
    'regions': manifestRegions,
  };
  File('${outputDirectory.path}/crop_manifest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  stdout.writeln('Generated character_sheet_v2 locally.');
  stdout.writeln('Canvas: $_canvasSize x $_canvasSize');
  stdout.writeln('Regions: ${manifestRegions.length}');
  stdout.writeln('No network or provider request was used.');
}

image.Image _solidImage(int red, int green, int blue) {
  final result = image.Image(_canvasSize, _canvasSize)
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

void _unionMask({
  required image.Image source,
  required image.Image destination,
  required _Rect sourceCrop,
  required int destinationX,
  required int destinationY,
  required int destinationWidth,
  required int destinationHeight,
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
    width: destinationWidth,
    height: destinationHeight,
    interpolation: image.Interpolation.nearest,
  );
  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      if (image.getRed(pixel) >= 250 &&
          image.getGreen(pixel) >= 250 &&
          image.getBlue(pixel) >= 250) {
        destination.setPixelRgba(
          destinationX + x,
          destinationY + y,
          255,
          255,
          255,
          255,
        );
      }
    }
  }
}

_Rect _contain({
  required int sourceWidth,
  required int sourceHeight,
  required int targetWidth,
  required int targetHeight,
}) {
  final scale = math.min(
    targetWidth / sourceWidth,
    targetHeight / sourceHeight,
  );
  final width = math.max(1, (sourceWidth * scale).round());
  final height = math.max(1, (sourceHeight * scale).round());
  return _Rect(
    ((targetWidth - width) / 2).round(),
    ((targetHeight - height) / 2).round(),
    width,
    height,
  );
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
    this.maskSourceRegionIds = const <String>[],
  });

  final String id;
  final String sourceRegionId;
  final List<String> maskSourceRegionIds;
  final _Rect crop;

  List<String> get effectiveMaskSourceRegionIds => maskSourceRegionIds.isEmpty
      ? <String>[sourceRegionId]
      : maskSourceRegionIds;
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

  Map<String, int> toJson() => <String, int>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}
