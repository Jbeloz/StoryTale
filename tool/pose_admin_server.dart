import 'dart:convert';
import 'dart:io';

const _port = 52828;
const _builtInPoses = {'neutral', 'talking', 'pointing', 'walking'};
final _safePoseId = RegExp(r'^[a-z][a-z0-9_]{1,39}$');
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
};
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
