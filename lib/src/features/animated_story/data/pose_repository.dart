import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sprite_rig.dart';

class PoseRepository {
  PoseRepository({this.rigId = 'humanoid_v1'});

  final String rigId;

  String get _storageKey => 'sprite_studio.$rigId.custom_poses';

  Future<List<SpriteRigPose>> loadProjectPoses() async {
    try {
      final root = 'assets/images/characters/rigs/$rigId';
      final source = await rootBundle.loadString('$root/pose_manifest.json');
      final manifest = jsonDecode(source) as Map<String, dynamic>;
      final entries = manifest['poses'] as List<dynamic>? ?? const [];
      final ids = entries
          .map((value) => value as Map<String, dynamic>)
          .where((value) => value['builtIn'] != true)
          .map((value) => value['id'] as String)
          .where(SpritePoseRules.validId);
      final poses = await Future.wait(
        ids.map((id) => SpriteRigPose.load('$root/poses/$id.json')),
      );
      return poses.where((pose) => pose.rigId == rigId).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SpriteRigPose>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_storageKey);
    if (source == null) return [];

    try {
      final values = jsonDecode(source) as List<dynamic>;
      final poses = values
          .map((value) => SpriteRigPose.fromJson(value as Map<String, dynamic>))
          .where(
            (pose) => pose.rigId == rigId && SpritePoseRules.validId(pose.id),
          )
          .toList();
      poses.sort((a, b) => a.displayName.compareTo(b.displayName));
      return poses;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(SpriteRigPose pose) async {
    if (pose.rigId != rigId || !SpritePoseRules.validId(pose.id)) {
      throw ArgumentError('The pose is not compatible with this rig.');
    }
    final poses = await loadAll();
    final index = poses.indexWhere((value) => value.id == pose.id);
    if (index == -1) {
      poses.add(pose);
    } else {
      poses[index] = pose;
    }
    poses.sort((a, b) => a.displayName.compareTo(b.displayName));
    await _write(poses);
  }

  Future<void> delete(String poseId) async {
    final poses = await loadAll()
      ..removeWhere((pose) => pose.id == poseId);
    await _write(poses);
  }

  Future<void> _write(List<SpriteRigPose> poses) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(poses.map((pose) => pose.toJson()).toList()),
    );
  }
}

class SpritePoseRules {
  const SpritePoseRules._();

  static final _safeId = RegExp(r'^[a-z][a-z0-9_]{1,39}$');

  static bool validId(String value) => _safeId.hasMatch(value);

  static String? nameError(String name, Iterable<String> existingNames) {
    final trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 40) {
      return 'Use 2 to 40 visible characters.';
    }
    final lower = trimmed.toLowerCase();
    if (existingNames.any((value) => value.trim().toLowerCase() == lower)) {
      return 'That pose name already exists.';
    }
    return null;
  }

  static String createId(String name, Iterable<String> existingIds) {
    var base = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty || !RegExp(r'^[a-z]').hasMatch(base)) {
      base = 'pose_$base';
    }
    if (base.length > 34) base = base.substring(0, 34);

    final used = existingIds.toSet();
    var id = base;
    var suffix = 2;
    while (used.contains(id)) {
      id = '${base}_$suffix';
      suffix++;
    }
    return id;
  }
}
