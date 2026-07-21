import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:storytale/src/features/animated_story/data/sprite_layer_processor.dart';
import 'package:storytale/src/features/animated_story/data/sprite_references.dart';

Future<void> main(List<String> arguments) async {
  final headOnly = arguments.contains('--head');
  final folder = headOnly ? 'head-template-test-02' : 'attempt-01';
  final output = Directory('assets/images/characters/gemini_review/$folder')
    ..createSync(recursive: true);
  final sourceFile = File('${output.path}/gemini-source.jpg');
  final bytes = arguments.contains('--process-only')
      ? await sourceFile.readAsBytes()
      : await _generate(headOnly: headOnly);

  await sourceFile.writeAsBytes(bytes);
  if (headOnly) {
    final transparent = const SpriteLayerProcessor().removeGreenBackground(
      bytes,
    );
    await File('${output.path}/head-transparent.png').writeAsBytes(transparent);
  } else {
    final layers = const SpriteLayerProcessor().process(bytes);
    await File('${output.path}/head.png').writeAsBytes(layers.head);
    await File('${output.path}/body.png').writeAsBytes(layers.body);
    await File('${output.path}/rejoined.png').writeAsBytes(layers.rejoined);
  }

  stdout.writeln('Gemini sprite pipeline passed.');
  stdout.writeln('Saved review images to ${output.path}.');
}

Future<Uint8List> _generate({required bool headOnly}) async {
  final env = _readEnv(File('.env'));
  final endpoint =
      env['CLOUDFLARE_IMAGE_URL'] ??
      'https://storytale-image-worker.jbalejoshift0928.workers.dev';
  final token = env['CLOUDFLARE_IMAGE_TOKEN'] ?? '';
  if (token.isEmpty) throw StateError('CLOUDFLARE_IMAGE_TOKEN is missing.');

  final mode = headOnly ? '&mode=head-design' : '';
  final request =
      http.MultipartRequest(
          'POST',
          Uri.parse('$endpoint/generate?kind=sprite$mode'),
        )
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['prompt'] = headOnly
            ? 'a kind young prince with short layered golden hair, warm '
                  'amber-brown eyes, fair warm skin, and a calm friendly expression'
            : 'a kind young prince with short golden hair, a long blue coat, '
                  'cream trousers, and brown boots';

  final references = headOnly
      ? ['docs/ui-concepts/ui/character_head_no_space.png']
      : spriteReferencePaths;
  for (var index = 0; index < references.length; index++) {
    final path = references[index];
    request.files.add(
      await http.MultipartFile.fromPath(
        'input_image_$index',
        path,
        filename: path.split('/').last,
      ),
    );
  }

  final response = await request.send();
  final bytes = await response.stream.toBytes();
  if (response.statusCode != 200) {
    throw HttpException(utf8.decode(bytes));
  }

  return Uint8List.fromList(bytes);
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
