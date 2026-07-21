import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:storytale/src/features/animated_story/data/sprite_layer_processor.dart';

const _outputRoot = 'docs/ui-concepts/ui/gemini_sprite_variant_test';

const _variants = [
  _Variant(
    folder: 'heads',
    fileName: 'head_talking.png',
    mode: 'head-expression',
    reference: 'docs/ui-concepts/ui/character_head_no_space.png',
    width: 1254,
    height: 1254,
    prompt:
        'Make this exact face look like it is naturally talking by changing only the mouth to a small relaxed open shape; keep the eyes, eyebrows, nose, ear, head outline, feature positions, scale, style, and square 1254 x 1254 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'heads',
    fileName: 'head_happy.png',
    mode: 'head-expression',
    reference: 'docs/ui-concepts/ui/character_head_no_space.png',
    width: 1254,
    height: 1254,
    prompt:
        'Make this exact face look happy by changing only the eyes into gentle happy curves, slightly raising the eyebrows, and changing the mouth into a warm smile; keep the nose, ear, head outline, feature positions, scale, style, and square 1254 x 1254 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'heads',
    fileName: 'head_sad.png',
    mode: 'head-expression',
    reference: 'docs/ui-concepts/ui/character_head_no_space.png',
    width: 1254,
    height: 1254,
    prompt:
        'Make this exact face look sad by lowering the eyes, raising only the inner ends of the eyebrows, and changing the mouth into a small frown; keep the nose, ear, head outline, feature positions, scale, style, and square 1254 x 1254 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'heads',
    fileName: 'head_angry.png',
    mode: 'head-expression',
    reference: 'docs/ui-concepts/ui/character_head_no_space.png',
    width: 1254,
    height: 1254,
    prompt:
        'Make this exact face look angry by narrowing the eyes, lowering the eyebrows sharply toward the center, and showing a small row of clenched teeth; keep the nose, ear, head outline, feature positions, scale, style, and square 1254 x 1254 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'heads',
    fileName: 'head_surprised.png',
    mode: 'head-expression',
    reference: 'docs/ui-concepts/ui/character_head_no_space.png',
    width: 1254,
    height: 1254,
    prompt:
        'Make this exact face look surprised by widening the eyes, raising the eyebrows, and changing the mouth into a small round open shape; keep the nose, ear, head outline, feature positions, scale, style, and square 1254 x 1254 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'bodies',
    fileName: 'body_waving.png',
    mode: 'body-pose',
    reference: 'docs/ui-concepts/ui/character_body.png',
    width: 263,
    height: 462,
    prompt:
        'Make this exact headless body wave by raising only its right arm with an open hand while keeping the other arm relaxed; preserve the neck opening, torso, limb thickness, hands, feet, proportions, scale, line art, colors, and tall 263 x 462 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'bodies',
    fileName: 'body_pointing.png',
    mode: 'body-pose',
    reference: 'docs/ui-concepts/ui/character_body.png',
    width: 263,
    height: 462,
    prompt:
        'Make this exact headless body point toward the right by extending only its right arm and index finger while keeping the other arm relaxed; preserve the neck opening, torso, limb thickness, hands, feet, proportions, scale, line art, colors, and tall 263 x 462 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'bodies',
    fileName: 'body_explaining.png',
    mode: 'body-pose',
    reference: 'docs/ui-concepts/ui/character_body.png',
    width: 263,
    height: 462,
    prompt:
        'Make this exact headless body look like it is explaining by bending both arms slightly outward with open palms; preserve the neck opening, torso, limb thickness, hands, feet, proportions, scale, line art, colors, and tall 263 x 462 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'bodies',
    fileName: 'body_defensive.png',
    mode: 'body-pose',
    reference: 'docs/ui-concepts/ui/character_body.png',
    width: 263,
    height: 462,
    prompt:
        'Make this exact headless body look defensive by raising both bent arms with the open palms facing forward; preserve the neck opening, torso, limb thickness, hands, feet, proportions, scale, line art, colors, and tall 263 x 462 framing exactly unchanged.',
  ),
  _Variant(
    folder: 'bodies',
    fileName: 'body_determined.png',
    mode: 'body-pose',
    reference: 'docs/ui-concepts/ui/character_body.png',
    width: 263,
    height: 462,
    prompt:
        'Make this exact headless body look determined by bending both elbows and placing lightly clenched fists beside the waist; preserve the neck opening, torso, limb thickness, hands, feet, proportions, scale, line art, colors, and tall 263 x 462 framing exactly unchanged.',
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
    final output = File('$_outputRoot/${variant.folder}/${variant.fileName}');
    output.parent.createSync(recursive: true);
    await output.writeAsBytes(png);

    if (index < _variants.length - 1) {
      await Future<void>.delayed(const Duration(seconds: 21));
    }
  }
  stdout.writeln(
    'Saved ${_variants.length} transparent PNG variants to $_outputRoot.',
  );
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
    required this.prompt,
  });

  final String folder;
  final String fileName;
  final String mode;
  final String reference;
  final int width;
  final int height;
  final String prompt;
}
