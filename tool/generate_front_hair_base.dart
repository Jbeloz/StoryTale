import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;

const _headReference = 'docs/ui-concepts/ui/character_head_no_space.png';
const _styleReference =
    'C:/Users/Houro/AppData/Local/Temp/'
    'codex-clipboard-764f192a-f62d-4011-9bb4-a93fec341c85.png';
const _reviewFolder = 'docs/ui-concepts/ui/gemini_front_hair_base_test';
const _assetPath =
    'assets/images/characters/rigs/humanoid_v1/hair/front_default.png';

const _prompt =
    'Dark navy-blue chibi front hair with a softly rounded crown, several '
    'playful upward crown tufts, layered side spikes, and long tapered bangs '
    'that frame the forehead like the hairstyle inspiration. Keep the center '
    'bangs above or between the eyes so both eyes and the lower face remain '
    'clearly visible. This is the reusable neutral StoryTale front-hair base. '
    'Generate only the isolated front-hair layer; no back hair.';

Future<void> main(List<String> arguments) async {
  final env = _readEnv(File('.env'));
  final endpoint =
      env['CLOUDFLARE_IMAGE_URL'] ??
      'https://storytale-image-worker.jbalejoshift0928.workers.dev';
  final token = env['CLOUDFLARE_IMAGE_TOKEN'] ?? '';
  if (token.isEmpty) {
    throw StateError('CLOUDFLARE_IMAGE_TOKEN is missing.');
  }

  final review = Directory(_reviewFolder)..createSync(recursive: true);
  final asset = File(_assetPath)..parent.createSync(recursive: true);
  final sourceFile = File('${review.path}/gemini_source.jpg');
  final Uint8List source;
  if (arguments.contains('--process-only')) {
    source = await sourceFile.readAsBytes();
  } else {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$endpoint/generate?kind=sprite&mode=front-hair'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['prompt'] = _prompt;

    for (final entry in [_headReference, _styleReference].indexed) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'input_image_${entry.$1}',
          entry.$2,
          filename: File(entry.$2).uri.pathSegments.last,
        ),
      );
    }

    final response = await request.send();
    source = await response.stream.toBytes();
    if (response.statusCode != 200) {
      throw HttpException(utf8.decode(source));
    }
    await sourceFile.writeAsBytes(source);
  }

  final transparent = _isolateFrontHair(
    _removeGreenBackground(
      Uint8List.fromList(source),
      width: 1254,
      height: 1254,
    ),
  );
  await File(
    '${review.path}/front_hair_transparent.png',
  ).writeAsBytes(transparent);
  await asset.writeAsBytes(transparent);

  final preview = _composeLayers(
    await File(_headReference).readAsBytes(),
    transparent,
  );
  await File('${review.path}/front_hair_on_head.png').writeAsBytes(preview);

  stdout.writeln('Gemini front-hair layer generated.');
  stdout.writeln('Asset: ${asset.path}');
  stdout.writeln('Preview: ${review.path}/front_hair_on_head.png');
}

Uint8List _removeGreenBackground(
  Uint8List source, {
  required int width,
  required int height,
}) {
  final decoded = image.decodeImage(source);
  if (decoded == null) throw const FormatException('Invalid sprite image.');
  final resized = image.copyResize(
    decoded,
    width: width,
    height: height,
    interpolation: image.Interpolation.linear,
  )..channels = image.Channels.rgba;

  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      final red = image.getRed(pixel);
      final green = image.getGreen(pixel);
      final blue = image.getBlue(pixel);
      if (green > 45 && green > red + 18 && green > blue + 18) {
        resized.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  return Uint8List.fromList(image.encodePng(resized));
}

Uint8List _isolateFrontHair(Uint8List source) {
  final sprite = image.decodeImage(source);
  if (sprite == null) throw const FormatException('Invalid hair layer.');
  sprite.channels = image.Channels.rgba;

  var mask = Uint8List(sprite.width * sprite.height);
  for (var y = 0; y < sprite.height; y++) {
    for (var x = 0; x < sprite.width; x++) {
      final pixel = sprite.getPixel(x, y);
      final red = image.getRed(pixel);
      final green = image.getGreen(pixel);
      final blue = image.getBlue(pixel);
      final alpha = image.getAlpha(pixel);
      if (alpha > 0 && blue > red + 8 && blue > green + 5 && blue < 190) {
        mask[y * sprite.width + x] = 1;
      }
    }
  }

  for (var pass = 0; pass < 7; pass++) {
    final expanded = Uint8List.fromList(mask);
    for (var y = 1; y < sprite.height - 1; y++) {
      for (var x = 1; x < sprite.width - 1; x++) {
        final index = y * sprite.width + x;
        if (mask[index] == 0) continue;
        expanded[index - sprite.width] = 1;
        expanded[index + sprite.width] = 1;
        expanded[index - 1] = 1;
        expanded[index + 1] = 1;
      }
    }
    mask = expanded;
  }

  for (var y = 0; y < sprite.height; y++) {
    for (var x = 0; x < sprite.width; x++) {
      final pixel = sprite.getPixel(x, y);
      final red = image.getRed(pixel);
      final green = image.getGreen(pixel);
      final blue = image.getBlue(pixel);
      final brightest = [red, green, blue].reduce((a, b) => a > b ? a : b);
      final darkest = [red, green, blue].reduce((a, b) => a < b ? a : b);
      final isPaleHeadPixel = darkest > 135 && brightest - darkest < 45;
      if (mask[y * sprite.width + x] == 0 || isPaleHeadPixel) {
        sprite.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  return Uint8List.fromList(image.encodePng(sprite));
}

Uint8List _composeLayers(Uint8List base, Uint8List overlay) {
  final baseImage = image.decodeImage(base);
  final overlayImage = image.decodeImage(overlay);
  if (baseImage == null || overlayImage == null) {
    throw const FormatException('Invalid preview layer.');
  }
  image.drawImage(baseImage, overlayImage);
  return Uint8List.fromList(image.encodePng(baseImage));
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
