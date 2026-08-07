import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _root =
    'assets/images/characters/garment_fixtures/v5/user_supplied_part_sheets_1k';
const _sourceRoot = '$_root/source';

void main() {
  final outputs = <String, Map<String, Object?>>{};
  _copyExact('arms_clothing_source_1k.png', 'arms_clothing_1k.png', outputs);
  _copyExact('legs_clothing_source_1k.png', 'legs_clothing_1k.png', outputs);
  _padTorso(outputs);

  final manifest = {
    'version': 'user-supplied-part-sheets-1k-1',
    'purpose': 'Owner-supplied clothing review sheets for V5-3.',
    'canvas': {'width': 1024, 'height': 1024, 'format': 'PNG'},
    'sheets': outputs,
    'flutterRegistered': false,
    'providerGenerated': false,
  };
  File('$_root/manifest.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  stdout.writeln('Wrote $_root');
}

void _copyExact(
  String sourceName,
  String outputName,
  Map<String, Map<String, Object?>> outputs,
) {
  final sourcePath = '$_sourceRoot/$sourceName';
  final outputPath = '$_root/$outputName';
  final sourceBytes = File(sourcePath).readAsBytesSync();
  File(outputPath).writeAsBytesSync(sourceBytes);
  final decoded = image.decodeImage(sourceBytes);
  if (decoded == null) throw FormatException('Invalid PNG: $sourcePath');
  if (decoded.width != 1024 || decoded.height != 1024) {
    throw FormatException('Expected a 1024x1024 sheet: $sourcePath');
  }
  outputs[outputName] = {
    'source': sourcePath,
    'sourceSha256': sha256.convert(sourceBytes).toString(),
    'outputSha256': sha256.convert(sourceBytes).toString(),
    'width': decoded.width,
    'height': decoded.height,
    'normalization': 'byte-exact copy',
  };
}

void _padTorso(Map<String, Map<String, Object?>> outputs) {
  const sourceName = 'torso_clothing_source_1022.png';
  const outputName = 'torso_clothing_1k.png';
  final sourcePath = '$_sourceRoot/$sourceName';
  final sourceBytes = File(sourcePath).readAsBytesSync();
  final source = image.decodeImage(sourceBytes);
  if (source == null) throw FormatException('Invalid PNG: $sourcePath');
  if (source.width != 1022 || source.height != 1022) {
    throw FormatException('Expected the supplied torso to be 1022x1022.');
  }

  final padded = image.Image(1024, 1024)..channels = image.Channels.rgba;
  for (var y = 0; y < padded.height; y++) {
    for (var x = 0; x < padded.width; x++) {
      final sourceX = (x - 1).clamp(0, source.width - 1);
      final sourceY = (y - 1).clamp(0, source.height - 1);
      padded.setPixel(x, y, source.getPixel(sourceX, sourceY));
    }
  }
  final outputBytes = image.encodePng(padded);
  File('$_root/$outputName').writeAsBytesSync(outputBytes);
  outputs[outputName] = {
    'source': sourcePath,
    'sourceSha256': sha256.convert(sourceBytes).toString(),
    'outputSha256': sha256.convert(outputBytes).toString(),
    'width': padded.width,
    'height': padded.height,
    'normalization': 'one-pixel replicated edge border; artwork not rescaled',
  };
}
