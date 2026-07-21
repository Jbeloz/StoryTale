import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:storytale/src/features/animated_story/data/sprite_layer_processor.dart';

const _outputRoot = 'docs/ui-concepts/ui/gemini_layered_sprite_test';
const _headReference = 'docs/ui-concepts/ui/character_head_no_face.png';
const _faceReference = 'docs/ui-concepts/ui/character_face.png';
const _bodyReference = 'docs/ui-concepts/ui/character_body.png';

const _variants = [
  _Variant(
    folder: 'faces',
    fileName: 'face_talking.png',
    mode: 'face-layer',
    reference: _faceReference,
    width: 1254,
    height: 1254,
    isFace: true,
    prompt:
        'Make this exact facial-feature layer look like it is talking by changing only the mouth into a small relaxed open shape; keep the eyes, eyebrows, nose mark, positions, spacing, scale, grayscale style, and square 1254 x 1254 canvas exactly unchanged, and output no head or skin.',
  ),
  _Variant(
    folder: 'faces',
    fileName: 'face_happy.png',
    mode: 'face-layer',
    reference: _faceReference,
    width: 1254,
    height: 1254,
    isFace: true,
    prompt:
        'Make this exact facial-feature layer look happy by gently curving the eyes, slightly raising the eyebrows, and changing only the mouth into a warm smile; keep the nose mark, positions, spacing, scale, grayscale style, and square 1254 x 1254 canvas exactly unchanged, and output no head or skin.',
  ),
  _Variant(
    folder: 'faces',
    fileName: 'face_sad.png',
    mode: 'face-layer',
    reference: _faceReference,
    width: 1254,
    height: 1254,
    isFace: true,
    prompt:
        'Make this exact facial-feature layer look sad by lowering the eyes, raising the inner eyebrows, and changing only the mouth into a small frown; keep the nose mark, positions, spacing, scale, grayscale style, and square 1254 x 1254 canvas exactly unchanged, and output no head or skin.',
  ),
  _Variant(
    folder: 'faces',
    fileName: 'face_angry.png',
    mode: 'face-layer',
    reference: _faceReference,
    width: 1254,
    height: 1254,
    isFace: true,
    prompt:
        'Make this exact facial-feature layer look angry by narrowing the eyes, lowering the eyebrows toward the center, and changing only the mouth to show a small row of clenched teeth; keep the nose mark, positions, spacing, scale, grayscale style, and square 1254 x 1254 canvas exactly unchanged, and output no head or skin.',
  ),
  _Variant(
    folder: 'bodies',
    fileName: 'body_talking.png',
    mode: 'body-pose',
    reference: _bodyReference,
    width: 263,
    height: 462,
    isFace: false,
    prompt:
        'Make this exact headless body use a simple talking pose by bending only its left forearm outward with one small open palm while the right arm stays down; keep the torso, legs, closed rounded feet with no toes, neck opening, colors, shading, line art, scale, and 263 x 462 canvas unchanged.',
  ),
  _Variant(
    folder: 'bodies',
    fileName: 'body_action.png',
    mode: 'body-pose',
    reference: _bodyReference,
    width: 263,
    height: 462,
    isFace: false,
    prompt:
        'Make this exact headless body use a simple action pose by extending only its right forearm sideways to point while the left arm stays down; keep the torso, legs, closed rounded feet with no toes, neck opening, colors, shading, line art, scale, and 263 x 462 canvas unchanged.',
  ),
  _Variant(
    folder: 'bodies',
    fileName: 'body_reaction.png',
    mode: 'body-pose',
    reference: _bodyReference,
    width: 263,
    height: 462,
    isFace: false,
    prompt:
        'Make this exact headless body use a simple reaction pose by bending both forearms upward with small hands near the chest; keep the torso, legs, closed rounded feet with no toes, neck opening, pale colors, original shading, line art, scale, and 263 x 462 canvas unchanged with no new colored shadows.',
  ),
];

Future<void> main() async {
  final env = _readEnv(File('.env'));
  final endpoint =
      env['CLOUDFLARE_IMAGE_URL'] ??
      'https://storytale-image-worker.jbalejoshift0928.workers.dev';
  final token = env['CLOUDFLARE_IMAGE_TOKEN'] ?? '';
  if (token.isEmpty) throw StateError('CLOUDFLARE_IMAGE_TOKEN is missing.');

  final processor = const SpriteLayerProcessor();
  final headBase = processor.removeGreenBackground(
    await File(_headReference).readAsBytes(),
    width: 1254,
    height: 1254,
  );
  final neutralFace = processor.removeGreenBackground(
    await File(_faceReference).readAsBytes(),
    width: 1254,
    height: 1254,
  );
  final neutralBody = processor.removeGreenBackground(
    await File(_bodyReference).readAsBytes(),
    width: 263,
    height: 462,
  );

  await _save('base/head_base.png', headBase);
  await _save('faces/face_neutral.png', neutralFace);
  await _save('bodies/body_neutral.png', neutralBody);
  await _save(
    'previews/head_neutral.png',
    processor.composeLayers(headBase, neutralFace),
  );

  for (var index = 0; index < _variants.length; index++) {
    final variant = _variants[index];
    stdout.writeln(
      'Generating ${index + 1}/${_variants.length}: ${variant.fileName}',
    );
    final generated = await _generate(endpoint, token, variant);
    final png = processor.removeGreenBackground(
      generated,
      width: variant.width,
      height: variant.height,
    );
    await _save('${variant.folder}/${variant.fileName}', png);
    if (variant.isFace) {
      await _save(
        'previews/head_${variant.fileName.substring(5)}',
        processor.composeLayers(headBase, png),
      );
    }

    if (index < _variants.length - 1) {
      await Future<void>.delayed(const Duration(seconds: 21));
    }
  }
  stdout.writeln('Saved the layered sprite test to $_outputRoot.');
}

Future<void> _save(String path, Uint8List bytes) async {
  final file = File('$_outputRoot/$path');
  file.parent.createSync(recursive: true);
  await file.writeAsBytes(bytes);
}

Future<Uint8List> _generate(
  String endpoint,
  String token,
  _Variant variant,
) async {
  for (var attempt = 1; attempt <= 3; attempt++) {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$endpoint/generate?kind=sprite&mode=${variant.mode}'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['prompt'] = variant.prompt
          ..files.add(
            await http.MultipartFile.fromPath(
              'input_image_0',
              variant.reference,
              filename: variant.reference.split('/').last,
            ),
          );
    final response = await request.send();
    final bytes = await response.stream.toBytes();
    if (response.statusCode == 200) return Uint8List.fromList(bytes);
    if (response.statusCode == 429 && attempt < 3) {
      stdout.writeln('Rate limited; retrying in 25 seconds.');
      await Future<void>.delayed(const Duration(seconds: 25));
      continue;
    }
    throw HttpException(utf8.decode(bytes));
  }
  throw const HttpException('Image generation failed.');
}

Map<String, String> _readEnv(File file) {
  final values = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) continue;
    final separator = line.indexOf('=');
    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return values;
}

class _Variant {
  const _Variant({
    required this.folder,
    required this.fileName,
    required this.mode,
    required this.reference,
    required this.width,
    required this.height,
    required this.isFace,
    required this.prompt,
  });

  final String folder;
  final String fileName;
  final String mode;
  final String reference;
  final int width;
  final int height;
  final bool isFace;
  final String prompt;
}
