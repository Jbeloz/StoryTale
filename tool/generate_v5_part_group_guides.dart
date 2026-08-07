import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _canvasWidth = 1024;
const _canvasHeight = 1024;
const _chromaGreen = 0x00FF00;
const _outputRoot =
    'assets/images/characters/garment_guides/humanoid_v1/v5_groups';

const _partAssets = <String, String>{
  'upper_leg_left':
      'assets/images/characters/rigs/humanoid_v1/base/upper_leg_left.png',
  'lower_leg_left':
      'assets/images/characters/rigs/humanoid_v1/base/lower_leg_left.png',
  'upper_leg_right':
      'assets/images/characters/rigs/humanoid_v1/base/upper_leg_right.png',
  'lower_leg_right':
      'assets/images/characters/rigs/humanoid_v1/base/lower_leg_right.png',
  'upper_arm_left':
      'assets/images/characters/rigs/humanoid_v1/base/upper_arm_left.png',
  'lower_arm_left':
      'assets/images/characters/rigs/humanoid_v1/base/lower_arm_left.png',
  'upper_arm_right':
      'assets/images/characters/rigs/humanoid_v1/base/upper_arm_right.png',
  'lower_arm_right':
      'assets/images/characters/rigs/humanoid_v1/base/lower_arm_right.png',
  'torso': 'assets/images/characters/rigs/humanoid_v1/base/torso.png',
};

const _partSizes = <String, List<int>>{
  'upper_leg_left': [85, 141],
  'lower_leg_left': [88, 140],
  'upper_leg_right': [94, 150],
  'lower_leg_right': [84, 156],
  'upper_arm_left': [78, 128],
  'lower_arm_left': [86, 129],
  'upper_arm_right': [67, 118],
  'lower_arm_right': [77, 145],
  'torso': [165, 234],
};

const _groups = <String, List<_Placement>>{
  'legs': [
    _Placement('upper_leg_left', 170, 160),
    _Placement('lower_leg_left', 170, 650),
    _Placement('upper_leg_right', 760, 160),
    _Placement('lower_leg_right', 760, 650),
  ],
  'arms': [
    _Placement('upper_arm_left', 170, 145),
    _Placement('lower_arm_left', 170, 640),
    _Placement('upper_arm_right', 760, 145),
    _Placement('lower_arm_right', 760, 620),
  ],
  'torso': [_Placement('torso', 430, 395)],
};

void main() {
  final manifest = <String, Object?>{
    'version': 'v5-part-group-guide-1',
    'canvas': {
      'width': _canvasWidth,
      'height': _canvasHeight,
      'format': 'PNG',
      'background': '#00FF00',
      'purpose': 'geometry reference for separated clothing generation',
    },
    'rules': [
      'Every source part is copied at its immutable humanoid_v1 native size.',
      'The green background is removable chroma key; it is not clothing.',
      'The guide parts are geometry references, not generated garment output.',
      'Generated output must contain clothing overlays only, never skin or rig replacement.',
      'Left/right identity is represented by the sheet column and the manifest part id.',
    ],
    'groups': <String, Object?>{},
  };

  for (final entry in _groups.entries) {
    final result = _buildGroup(entry.key, entry.value);
    final output = File('$_outputRoot/${entry.key}_1k_reference.png');
    output.parent.createSync(recursive: true);
    output.writeAsBytesSync(image.encodePng(result.canvas));
    (manifest['groups']! as Map<String, Object?>)[entry.key] = {
      'file': output.path.replaceAll('\\', '/'),
      'parts': result.parts,
    };
    stdout.writeln(
      'Generated ${entry.key}: ${output.path} '
      '(${_canvasWidth}x$_canvasHeight, ${entry.value.length} native-size parts)',
    );
  }

  final manifestFile = File('$_outputRoot/manifest.json');
  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
  File('$_outputRoot/README.md').writeAsStringSync(_readme);
  stdout.writeln('Wrote ${manifestFile.path}');
}

_GroupResult _buildGroup(String group, List<_Placement> placements) {
  final canvas = image.Image(_canvasWidth, _canvasHeight)
    ..channels = image.Channels.rgba;
  image.fill(canvas, image.getColor(0, 255, 0, 255));

  final parts = <Map<String, Object?>>[];
  for (final placement in placements) {
    final sourcePath = _partAssets[placement.partId]!;
    final sourceBytes = File(sourcePath).readAsBytesSync();
    final decoded = image.decodeImage(sourceBytes);
    if (decoded == null) {
      throw FormatException('Cannot decode $sourcePath');
    }
    final expected = _partSizes[placement.partId]!;
    if (decoded.width != expected[0] || decoded.height != expected[1]) {
      throw StateError(
        '${placement.partId} is ${decoded.width}x${decoded.height}; '
        'expected ${expected[0]}x${expected[1]}',
      );
    }
    if (placement.x < 0 ||
        placement.y < 0 ||
        placement.x + decoded.width > _canvasWidth ||
        placement.y + decoded.height > _canvasHeight) {
      throw StateError('${placement.partId} falls outside the 1K canvas');
    }
    image.drawImage(canvas, decoded, dstX: placement.x, dstY: placement.y);
    parts.add({
      'partId': placement.partId,
      'sourceAsset': sourcePath,
      'sourceSha256': sha256.convert(sourceBytes).toString(),
      'nativeSize': {'width': decoded.width, 'height': decoded.height},
      'canvasPosition': {'x': placement.x, 'y': placement.y},
      'column': placement.partId == 'torso'
          ? 'center'
          : placement.x < _canvasWidth ~/ 2
          ? 'left'
          : 'right',
    });
  }
  return _GroupResult(canvas: canvas, parts: parts);
}

class _Placement {
  const _Placement(this.partId, this.x, this.y);

  final String partId;
  final int x;
  final int y;
}

class _GroupResult {
  const _GroupResult({required this.canvas, required this.parts});

  final image.Image canvas;
  final List<Map<String, Object?>> parts;
}

const _readme = '''# V5 part-group 1K reference sheets

These three PNGs are deterministic geometry references for the V5 clothing
groups. They are not generated garments and are not runtime replacements for
the immutable `humanoid_v1` parts.

## Files

- `legs_1k_reference.png` — left column: left upper/lower leg; right column: right upper/lower leg.
- `arms_1k_reference.png` — left column: left upper/lower arm; right column: right upper/lower arm.
- `torso_1k_reference.png` — one centered torso reference.

Each canvas is exactly 1024x1024. Every source part is copied at its exact
native runtime size. The flat `#00FF00` background is intentionally removable
by `SpriteGarmentSeparator`; it is not part of the clothing output.

The later provider prompt must request clothing overlays only, with no skin,
no replacement body geometry, and no text or labels. The `manifest.json` file
records the exact source hash, native size, and canvas placement for every part.
''';
