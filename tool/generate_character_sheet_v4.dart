import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _canvasWidth = 2048;
const _canvasHeight = 512;
const _transportScale = 0.58;
const _v3Root =
    'assets/images/characters/generation_templates/humanoid_v1/'
    'character_sheet_v3';
const _v4Root =
    'assets/images/characters/generation_templates/humanoid_v1/'
    'character_sheet_v4';
const _rigManifestPath = 'assets/images/characters/rigs/humanoid_v1/rig.json';

const _targets = <_TargetSpec>[
  _TargetSpec(id: 'back_hair_short', crop: _Rect(16, 24, 249, 464)),
  _TargetSpec(id: 'back_hair_medium', crop: _Rect(281, 24, 249, 464)),
  _TargetSpec(id: 'back_hair_long', crop: _Rect(546, 24, 249, 464)),
  _TargetSpec(id: 'front_hair', crop: _Rect(811, 129, 249, 254)),
  _TargetSpec(id: 'head', crop: _Rect(1076, 150, 207, 213)),
  _TargetSpec(id: 'torso', crop: _Rect(1299, 188, 96, 136)),
  _TargetSpec(id: 'upper_arm_right', crop: _Rect(1451, 150, 39, 68)),
  _TargetSpec(id: 'upper_leg_right', crop: _Rect(1443, 300, 55, 87)),
  _TargetSpec(id: 'lower_arm_right', crop: _Rect(1608, 142, 45, 84)),
  _TargetSpec(id: 'lower_leg_right', crop: _Rect(1606, 299, 49, 90)),
  _TargetSpec(id: 'upper_arm_left', crop: _Rect(1768, 147, 45, 74)),
  _TargetSpec(id: 'upper_leg_left', crop: _Rect(1766, 303, 49, 82)),
  _TargetSpec(id: 'lower_arm_left', crop: _Rect(1925, 146, 50, 75)),
  _TargetSpec(id: 'lower_leg_left', crop: _Rect(1925, 303, 51, 81)),
];

void main() {
  final rigManifest =
      jsonDecode(File(_rigManifestPath).readAsStringSync())
          as Map<String, dynamic>;
  final rigParts = <String, Map<String, dynamic>>{
    for (final raw in rigManifest['parts'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw,
  };
  _validateTargets(rigParts);

  final v3Manifest =
      jsonDecode(File('$_v3Root/crop_manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final v3Regions = <String, Map<String, dynamic>>{
    for (final raw in v3Manifest['regions'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw,
  };

  final guide = _solidImage(0, 255, 0);
  final allowed = _solidImage(0, 0, 0);
  final protected = _solidImage(0, 0, 0);
  final seams = _solidImage(0, 0, 0);
  final v3Allowed = _decode('$_v3Root/allowed_regions.png');
  final v3Protected = _decode('$_v3Root/protected_regions.png');
  final v3Seams = _decode('$_v3Root/seam_allowances.png');
  final manifestRegions = <Map<String, dynamic>>[];

  for (final target in _targets) {
    final sourceRegion = v3Regions[target.id];
    if (sourceRegion == null) {
      throw StateError('V3 is missing source region ${target.id}.');
    }
    final outputCanvas = sourceRegion['outputCanvas'] as Map<String, dynamic>;
    final sourceAsset = sourceRegion['sourceAsset'] as String;
    final sourceArtwork = _decode(sourceAsset)..channels = image.Channels.rgba;
    final transportArtwork = image.copyResize(
      sourceArtwork,
      width: target.crop.width,
      height: target.crop.height,
      interpolation: image.Interpolation.linear,
    );
    image.drawImage(
      guide,
      transportArtwork,
      dstX: target.crop.x,
      dstY: target.crop.y,
    );

    final sourceCrop = _Rect.fromJson(
      sourceRegion['crop'] as Map<String, dynamic>,
    );
    _copyMask(
      source: v3Allowed,
      destinationImage: allowed,
      sourceCrop: sourceCrop,
      destinationRect: target.crop,
    );
    _copyMask(
      source: v3Protected,
      destinationImage: protected,
      sourceCrop: sourceCrop,
      destinationRect: target.crop,
    );
    _copyMask(
      source: v3Seams,
      destinationImage: seams,
      sourceCrop: sourceCrop,
      destinationRect: target.crop,
    );

    final outputAnchor = Map<String, dynamic>.from(
      sourceRegion['attachmentAnchor'] as Map<String, dynamic>,
    );
    final outputSeams = (sourceRegion['seamAnchors'] as List<dynamic>? ?? [])
        .map((raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>))
        .toList(growable: false);
    final region = Map<String, dynamic>.from(sourceRegion)
      ..['id'] = target.id
      ..['rigPartId'] = target.rigPartId
      ..['crop'] = target.crop.toJson()
      ..['sourceCanvas'] = Map<String, dynamic>.from(
        sourceRegion['sourceCanvas'] as Map<String, dynamic>? ?? outputCanvas,
      )
      ..['outputCanvas'] = Map<String, dynamic>.from(outputCanvas)
      ..['transportScale'] = _transportScale
      ..['transportContent'] = _Rect(
        0,
        0,
        target.crop.width,
        target.crop.height,
      ).toJson()
      ..['attachmentAnchor'] = outputAnchor
      ..['transportAttachmentAnchor'] = _scalePoint(
        outputAnchor,
        outputCanvas,
        target.crop,
      )
      ..['seamAnchors'] = outputSeams
      ..['transportSeamAnchors'] = _scaleSeamAnchors(
        outputSeams,
        outputCanvas,
        target.crop,
      )
      ..['maskRegionId'] = target.id
      ..['resampling'] = 'cubic-once-after-masking';
    manifestRegions.add(region);
  }

  final outputDirectory = Directory(_v4Root)..createSync(recursive: true);
  _writePng('${outputDirectory.path}/guide.png', guide);
  _writePng('${outputDirectory.path}/allowed_regions.png', allowed);
  _writePng('${outputDirectory.path}/protected_regions.png', protected);
  _writePng('${outputDirectory.path}/seam_allowances.png', seams);
  File(
    '$_v3Root/assembled_reference.png',
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
  final manifest = <String, dynamic>{
    'contractId': 'character_sheet_v4',
    'contractVersion': 4,
    'canvas': <String, dynamic>{
      'width': _canvasWidth,
      'height': _canvasHeight,
      'providerAspectRatio': '4:1',
      'providerImageSize': '1K',
      'mimeType': 'image/png',
      'backgroundColor': '#00FF00',
    },
    'assets': assetPaths,
    'assetSha256': assetHashes,
    'maskEncoding': v3Manifest['maskEncoding'],
    'lockedRig': v3Manifest['lockedRig'],
    'actorContract': v3Manifest['actorContract'],
    'transport': <String, dynamic>{
      'derivedFromContractId': 'character_sheet_v3',
      'uniformScale': _transportScale,
      'dimensionRounding': 'nearest integer after scaling each V3 output axis',
      'extractFrom': 'crop',
      'outputPolicy':
          'mask the full transport crop, resize exactly once to outputCanvas with cubic interpolation, then reapply the hard output mask',
      'cropToVisiblePixels': false,
      'originalRuntimeAssetsRemainImmutable': true,
      'qualityGate':
          'owner must compare V4 face, hair edges, clothing seams, and assembled poses against the V3 fallback before migration',
    },
    'selectionContract': v3Manifest['selectionContract'],
    'rules': <String, dynamic>{
      'cropCoordinatesAreInclusiveExclusive': true,
      'resizeRegions': true,
      'resizeExactlyOnce': true,
      'cropToVisiblePixels': false,
      'inactiveOptionalRegionsRemainGreen': true,
      'visibleCellBorders': false,
    },
    'regions': manifestRegions,
  };
  File('${outputDirectory.path}/crop_manifest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  stdout.writeln('Generated character_sheet_v4 locally.');
  stdout.writeln('Canvas: $_canvasWidth x $_canvasHeight (4:1 1K)');
  stdout.writeln('Transport scale: $_transportScale');
  stdout.writeln('Regions: ${manifestRegions.length}');
  stdout.writeln('Guide actor: default; compatible future actor: heroine');
  stdout.writeln('No network or provider request was used.');
}

void _validateTargets(Map<String, Map<String, dynamic>> rigParts) {
  for (final target in _targets) {
    final rigPart = rigParts[target.rigPartId];
    if (rigPart == null) {
      throw StateError('Missing Sprite Studio rig part ${target.rigPartId}.');
    }
    final size = rigPart['size'] as Map<String, dynamic>;
    final outputWidth = (size['width'] as num).toDouble().round();
    final outputHeight = (size['height'] as num).toDouble().round();
    final expectedWidth = (outputWidth * _transportScale).round();
    final expectedHeight = (outputHeight * _transportScale).round();
    if (target.crop.width != expectedWidth ||
        target.crop.height != expectedHeight) {
      throw StateError(
        '${target.id} must use the uniform V4 transport size '
        '${expectedWidth}x$expectedHeight, found '
        '${target.crop.width}x${target.crop.height}.',
      );
    }
    if (target.crop.x < 0 ||
        target.crop.y < 0 ||
        target.crop.right > _canvasWidth ||
        target.crop.bottom > _canvasHeight) {
      throw StateError('${target.id} is outside the V4 canvas.');
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
  _Rect transportCanvas,
) => <String, double>{
  'x':
      (point['x'] as num).toDouble() *
      transportCanvas.width /
      (sourceCanvas['width'] as num).toDouble(),
  'y':
      (point['y'] as num).toDouble() *
      transportCanvas.height /
      (sourceCanvas['height'] as num).toDouble(),
};

List<Map<String, double>> _scaleSeamAnchors(
  List<Map<String, dynamic>> anchors,
  Map<String, dynamic> sourceCanvas,
  _Rect transportCanvas,
) {
  final scaleX =
      transportCanvas.width / (sourceCanvas['width'] as num).toDouble();
  final scaleY =
      transportCanvas.height / (sourceCanvas['height'] as num).toDouble();
  final radiusScale = (scaleX + scaleY) / 2;
  return anchors
      .map(
        (anchor) => <String, double>{
          'x': (anchor['x'] as num).toDouble() * scaleX,
          'y': (anchor['y'] as num).toDouble() * scaleY,
          'radius': (anchor['radius'] as num).toDouble() * radiusScale,
        },
      )
      .toList(growable: false);
}

void _writePng(String path, image.Image value) {
  File(path).writeAsBytesSync(image.encodePng(value));
}

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

class _TargetSpec {
  const _TargetSpec({required this.id, required this.crop});

  final String id;
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
