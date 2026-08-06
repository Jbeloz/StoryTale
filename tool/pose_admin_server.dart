import 'dart:convert';
import 'dart:io';

const _port = 52828;
const _builtInPoses = {'neutral', 'talking', 'pointing', 'walking'};
final _safePoseId = RegExp(r'^[a-z][a-z0-9_]{1,39}$');

/// A provider request ID, used as a directory name, so it may not carry a path
/// separator or traversal.
final _safeDiagnosticsId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');
const _faceNames = {'neutral', 'talking', 'happy', 'sad', 'angry'};
const _partNames = {
  'head',
  'torso',
  'upper_arm_right',
  'lower_arm_right',
  'upper_arm_left',
  'lower_arm_left',
  'upper_leg_right',
  'lower_leg_right',
  'upper_leg_left',
  'lower_leg_left',
  'front_hair',
  'back_hair',
};

/// DeepL accepts up to 50 `text` values per request.
const _maxTranslateTexts = 50;
const _maxTranslateBytes = 131072;
final _safeLangCode = RegExp(r'^[A-Z]{2}(-[A-Z]{2})?$');
const _actorIds = {'default', 'hero', 'heroine', 'elder', 'adult'};
const _hairStyleIds = {'none', 'short', 'medium', 'long'};
const _origins = {
  'http://127.0.0.1:52827',
  'http://localhost:52827',
  'http://127.0.0.1:52830',
};

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  stdout.writeln('StoryTale pose admin: http://127.0.0.1:$_port');
  await for (final request in server) {
    await _handle(request);
  }
}

Future<void> _handle(HttpRequest request) async {
  final origin = request.headers.value('origin');
  if (origin != null && !_origins.contains(origin)) {
    return _reply(request, HttpStatus.forbidden, {'error': 'Origin denied.'});
  }
  _cors(request, origin);

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    return request.response.close();
  }
  if (request.method == 'GET' && request.uri.path == '/health') {
    return _reply(request, HttpStatus.ok, {'ready': true});
  }
  if (request.method == 'POST' && request.uri.path == '/appearance') {
    return _saveAppearance(request);
  }
  if (request.method == 'POST' && request.uri.path == '/translate') {
    return _translate(request);
  }
  if (request.method == 'POST' &&
      request.uri.path == '/character-sheet-diagnostics') {
    return _saveCharacterSheetDiagnostics(request);
  }

  final segments = request.uri.pathSegments;
  if (request.method == 'DELETE' &&
      segments.length == 2 &&
      segments.first == 'poses' &&
      _safePoseId.hasMatch(segments.last)) {
    if (_builtInPoses.contains(segments.last)) {
      return _reply(request, HttpStatus.badRequest, {
        'error': 'Built-in poses cannot be deleted.',
      });
    }
    await _deleteProjectPose(segments.last);
    return _reply(request, HttpStatus.ok, {'deleted': segments.last});
  }
  if (request.method != 'POST' ||
      segments.length != 2 ||
      segments.first != 'poses' ||
      !_safePoseId.hasMatch(segments.last)) {
    return _reply(request, HttpStatus.notFound, {'error': 'Unknown pose.'});
  }
  if (request.contentLength > 65536) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Pose is too big.',
    });
  }

  try {
    final source = await utf8.decoder.bind(request).join();
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> || !_validPose(value, segments.last)) {
      return _reply(request, HttpStatus.badRequest, {'error': 'Invalid pose.'});
    }

    final file = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'assets${Platform.pathSeparator}images${Platform.pathSeparator}'
      'characters${Platform.pathSeparator}rigs${Platform.pathSeparator}'
      'humanoid_v1${Platform.pathSeparator}poses${Platform.pathSeparator}'
      '${segments.last}.json',
    );
    final formatted = const JsonEncoder.withIndent('  ').convert(value);
    await file.writeAsString('$formatted\n');
    await _updateManifest(value);
    return _reply(request, HttpStatus.ok, {'saved': segments.last});
  } catch (_) {
    return _reply(request, HttpStatus.badRequest, {'error': 'Invalid JSON.'});
  }
}

Future<void> _saveAppearance(HttpRequest request) async {
  if (request.contentLength > 4096) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Appearance is too big.',
    });
  }
  try {
    final source = await utf8.decoder.bind(request).join();
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> || !_validAppearance(value)) {
      return _reply(request, HttpStatus.badRequest, {
        'error': 'Invalid appearance.',
      });
    }
    final file = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'assets${Platform.pathSeparator}images${Platform.pathSeparator}'
      'characters${Platform.pathSeparator}rigs${Platform.pathSeparator}'
      'humanoid_v1${Platform.pathSeparator}appearance.json',
    );
    final formatted = const JsonEncoder.withIndent('  ').convert(value);
    await file.writeAsString('$formatted\n');
    return _reply(request, HttpStatus.ok, {'saved': true});
  } catch (_) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Invalid appearance.',
    });
  }
}

/// Writes one returned character sheet, its prompt, and its validation report to
/// disk so a failed sheet can be re-examined without buying it again.
///
/// Every character-sheet request costs money and, before this, the result lived
/// only in the browser tab that made it. A defect could therefore only be
/// diagnosed from a screenshot, and re-measuring one meant paying for another
/// request. Three of the seven sheets bought so far were spent discovering
/// things a saved file would have answered for free.
///
/// The directory is git-ignored: these are provider outputs for local analysis,
/// not project assets.
Future<void> _saveCharacterSheetDiagnostics(HttpRequest request) async {
  // A 1024x1024 JPEG runs about 500 KB, roughly 700 KB once base64 encoded, and
  // the prompt adds ~10 KB. Four megabytes leaves room without inviting an
  // arbitrary upload.
  if (request.contentLength > 4 * 1024 * 1024) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Diagnostics payload is too big.',
    });
  }
  try {
    final source = await utf8.decoder.bind(request).join();
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      return _reply(request, HttpStatus.badRequest, {
        'error': 'Invalid diagnostics.',
      });
    }
    final sheet = value['sheetBase64'];
    final requestId = value['requestId'];
    if (sheet is! String ||
        sheet.isEmpty ||
        requestId is! String ||
        !_safeDiagnosticsId.hasMatch(requestId)) {
      return _reply(request, HttpStatus.badRequest, {
        'error': 'Invalid diagnostics.',
      });
    }

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final sep = Platform.pathSeparator;
    final directory = Directory(
      '${Directory.current.path}${sep}diagnostics${sep}character_sheets$sep'
      '${stamp}_$requestId',
    );
    await directory.create(recursive: true);

    final extension = value['mimeType'] == 'image/png' ? 'png' : 'jpg';
    await File('${directory.path}${sep}sheet.$extension')
        .writeAsBytes(base64Decode(sheet));
    final prompt = value['prompt'];
    if (prompt is String && prompt.isNotEmpty) {
      await File('${directory.path}${sep}prompt.txt').writeAsString(prompt);
    }
    final report = Map<String, dynamic>.from(value)
      ..remove('sheetBase64')
      ..remove('prompt');
    await File('${directory.path}${sep}report.json').writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );

    stdout.writeln('Saved character-sheet diagnostics: ${directory.path}');
    return _reply(request, HttpStatus.ok, {'saved': directory.path});
  } catch (_) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Invalid diagnostics.',
    });
  }
}

/// Forwards one batch of text to DeepL.
///
/// The API key stays in this process. Flutter never receives it, so it never
/// reaches the web bundle where anyone could read it out of devtools. DeepL also
/// sends no CORS headers, so the browser could not call it directly anyway.
Future<void> _translate(HttpRequest request) async {
  final key = Platform.environment['DEEPL_API_KEY']?.trim() ?? '';
  if (key.isEmpty) {
    return _reply(request, HttpStatus.serviceUnavailable, {
      'error':
          'DEEPL_API_KEY is not set. Add it to .env and restart the launcher.',
    });
  }
  if (request.contentLength > _maxTranslateBytes) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Translation request is too big.',
    });
  }

  final List<String> texts;
  final String targetLang;
  try {
    final source = await utf8.decoder.bind(request).join();
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) throw const FormatException();
    texts = (value['texts'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    targetLang = (value['targetLang'] as String? ?? 'TL').toUpperCase();
  } catch (_) {
    return _reply(request, HttpStatus.badRequest, {'error': 'Invalid JSON.'});
  }
  if (texts.isEmpty) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Send at least one text.',
    });
  }
  if (texts.length > _maxTranslateTexts) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Send at most $_maxTranslateTexts texts per request.',
    });
  }
  if (!_safeLangCode.hasMatch(targetLang)) {
    return _reply(request, HttpStatus.badRequest, {
      'error': 'Invalid target language.',
    });
  }

  // A free-tier key ends with ":fx" and must use the api-free host.
  final host = key.endsWith(':fx') ? 'api-free.deepl.com' : 'api.deepl.com';
  final client = HttpClient();
  try {
    final upstream = await client.postUrl(Uri.https(host, '/v2/translate'));
    upstream.headers
      ..set(HttpHeaders.authorizationHeader, 'DeepL-Auth-Key $key')
      ..contentType = ContentType.json;
    upstream.write(jsonEncode({'text': texts, 'target_lang': targetLang}));

    final response = await upstream.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      // Surface the real provider status and message; never retry here.
      return _reply(request, response.statusCode, {
        'error': 'DeepL returned ${response.statusCode}.',
        'detail': body.isEmpty ? null : body,
      });
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    final translations = (decoded['translations'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => item['text'])
        .whereType<String>()
        .toList();
    if (translations.length != texts.length) {
      return _reply(request, HttpStatus.badGateway, {
        'error':
            'DeepL returned ${translations.length} translations '
            'for ${texts.length} texts.',
      });
    }
    return _reply(request, HttpStatus.ok, {'translations': translations});
  } on SocketException catch (error) {
    return _reply(request, HttpStatus.badGateway, {
      'error': 'Could not reach DeepL: ${error.message}',
    });
  } catch (_) {
    return _reply(request, HttpStatus.badGateway, {
      'error': 'DeepL sent an unreadable response.',
    });
  } finally {
    client.close();
  }
}

bool _validAppearance(Map<String, dynamic> value) {
  final actorId = value['actorId'];
  final hairStyleId = value['hairStyleId'];
  final skinTone = value['skinTone'];
  return actorId is String &&
      _actorIds.contains(actorId) &&
      hairStyleId is String &&
      _hairStyleIds.contains(hairStyleId) &&
      skinTone is String &&
      RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(skinTone);
}

bool _validPose(Map<String, dynamic> pose, String name) {
  final displayName = pose['name'];
  if (pose['id'] != name ||
      displayName is! String ||
      displayName.trim().length < 2 ||
      displayName.trim().length > 40 ||
      pose['rigId'] != 'humanoid_v1' ||
      !_faceNames.contains(pose['faceExpressionId']) ||
      pose['layerPolicyVersion'] != 1 ||
      pose['parts'] is! Map<String, dynamic>) {
    return false;
  }
  final parts = pose['parts'] as Map<String, dynamic>;
  for (final entry in parts.entries) {
    if (!_partNames.contains(entry.key) || entry.value is! Map) {
      return false;
    }
    final transform = entry.value as Map;
    for (final key in ['rotation', 'x', 'y']) {
      final value = transform[key];
      if (value is! num || !value.isFinite) {
        return false;
      }
    }
    final layer = transform['layer'];
    if (layer != null && (layer is! int || !layer.isFinite)) {
      return false;
    }
    final scale = transform['scale'];
    if (scale != null &&
        (scale is! num || !scale.isFinite || scale < 0.5 || scale > 1.8)) {
      return false;
    }
  }
  return true;
}

Future<void> _updateManifest(Map<String, dynamic> pose) async {
  final file = _manifestFile();
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final poses = (manifest['poses'] as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();
  final entry = {
    'id': pose['id'],
    'name': pose['name'],
    'builtIn': _builtInPoses.contains(pose['id']),
  };
  final index = poses.indexWhere((value) => value['id'] == pose['id']);
  if (index == -1) {
    poses.add(entry);
  } else {
    poses[index] = entry;
  }
  await _writeManifest(file, manifest, poses);
}

Future<void> _deleteProjectPose(String poseId) async {
  final poseFile = File(
    '${Directory.current.path}${Platform.pathSeparator}'
    'assets${Platform.pathSeparator}images${Platform.pathSeparator}'
    'characters${Platform.pathSeparator}rigs${Platform.pathSeparator}'
    'humanoid_v1${Platform.pathSeparator}poses${Platform.pathSeparator}'
    '$poseId.json',
  );
  if (await poseFile.exists()) await poseFile.delete();

  final file = _manifestFile();
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final poses = (manifest['poses'] as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .where((value) => value['id'] != poseId)
      .toList();
  await _writeManifest(file, manifest, poses);
}

File _manifestFile() => File(
  '${Directory.current.path}${Platform.pathSeparator}'
  'assets${Platform.pathSeparator}images${Platform.pathSeparator}'
  'characters${Platform.pathSeparator}rigs${Platform.pathSeparator}'
  'humanoid_v1${Platform.pathSeparator}pose_manifest.json',
);

Future<void> _writeManifest(
  File file,
  Map<String, dynamic> manifest,
  List<Map<String, dynamic>> poses,
) async {
  manifest['poses'] = poses;
  final formatted = const JsonEncoder.withIndent('  ').convert(manifest);
  await file.writeAsString('$formatted\n');
}

void _cors(HttpRequest request, String? origin) {
  if (origin != null) {
    request.response.headers.set('Access-Control-Allow-Origin', origin);
  }
  request.response.headers
    ..set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type');
}

Future<void> _reply(
  HttpRequest request,
  int status,
  Map<String, dynamic> body,
) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}
