import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'face_profile_catalog.dart';

enum SpriteFacePartType { eyes, nose, mouth, details }

extension SpriteFacePartTypeLabel on SpriteFacePartType {
  String get storageName => name;

  String get label => switch (this) {
    SpriteFacePartType.eyes => 'Eyes',
    SpriteFacePartType.nose => 'Nose',
    SpriteFacePartType.mouth => 'Mouth',
    SpriteFacePartType.details => 'Details',
  };
}

class LocalSpriteFacePart {
  const LocalSpriteFacePart({
    required this.profileId,
    required this.type,
    required this.id,
    required this.label,
    required this.bytes,
  });

  final String profileId;
  final SpriteFacePartType type;
  final String id;
  final String label;
  final Uint8List bytes;

  String get key => '$profileId|${type.storageName}|$id';

  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'type': type.storageName,
    'id': id,
    'label': label,
    'bytes': base64Encode(bytes),
  };

  factory LocalSpriteFacePart.fromJson(Map<String, dynamic> json) {
    return LocalSpriteFacePart(
      profileId: json['profileId'] as String,
      type: SpriteFacePartType.values.byName(json['type'] as String),
      id: json['id'] as String,
      label: json['label'] as String,
      bytes: base64Decode(json['bytes'] as String),
    );
  }
}

class SpriteFaceLocalData {
  const SpriteFaceLocalData({required this.parts, required this.sets});

  final List<LocalSpriteFacePart> parts;
  final Map<String, List<SpriteFaceSet>> sets;

  static const empty = SpriteFaceLocalData(parts: [], sets: {});

  Map<String, dynamic> toJson() => {
    'parts': parts.map((part) => part.toJson()).toList(),
    'sets': {
      for (final entry in sets.entries)
        entry.key: entry.value.map((set) => set.toJson()).toList(),
    },
  };

  factory SpriteFaceLocalData.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as Map<String, dynamic>? ?? const {};
    return SpriteFaceLocalData(
      parts: (json['parts'] as List<dynamic>? ?? const [])
          .map(
            (value) =>
                LocalSpriteFacePart.fromJson(value as Map<String, dynamic>),
          )
          .toList(),
      sets: {
        for (final entry in rawSets.entries)
          entry.key: (entry.value as List<dynamic>)
              .map(
                (value) =>
                    SpriteFaceSet.fromJson(value as Map<String, dynamic>),
              )
              .toList(),
      },
    );
  }
}

class FaceLocalRepository {
  static const _storageKey = 'sprite_studio.face_profiles.v1';

  Future<SpriteFaceLocalData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_storageKey);
    if (source == null) return SpriteFaceLocalData.empty;
    try {
      return SpriteFaceLocalData.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
    } catch (_) {
      return SpriteFaceLocalData.empty;
    }
  }

  Future<void> save(SpriteFaceLocalData data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(data.toJson()));
  }
}
