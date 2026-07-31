import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SpriteAppearanceSelection {
  const SpriteAppearanceSelection({
    this.actorId = 'default',
    this.hairStyleId = 'medium',
    this.skinTone = '#F2EDEF',
  });

  final String actorId;
  final String hairStyleId;
  final String skinTone;

  SpriteAppearanceSelection copyWith({
    String? actorId,
    String? hairStyleId,
    String? skinTone,
  }) {
    return SpriteAppearanceSelection(
      actorId: actorId ?? this.actorId,
      hairStyleId: hairStyleId ?? this.hairStyleId,
      skinTone: skinTone ?? this.skinTone,
    );
  }

  factory SpriteAppearanceSelection.fromJson(Map<String, dynamic> json) {
    return SpriteAppearanceSelection(
      actorId: json['actorId'] as String? ?? 'default',
      hairStyleId: json['hairStyleId'] as String? ?? 'medium',
      skinTone: json['skinTone'] as String? ?? '#F2EDEF',
    );
  }

  Map<String, dynamic> toJson() => {
    'actorId': actorId,
    'hairStyleId': hairStyleId,
    'skinTone': skinTone,
  };
}

class SpriteActorAppearance {
  const SpriteActorAppearance({
    required this.id,
    required this.label,
    required this.faceProfileId,
    required this.defaultHairStyleId,
    required this.defaultSkinTone,
  });

  final String id;
  final String label;
  final String faceProfileId;
  final String defaultHairStyleId;
  final String defaultSkinTone;
}

class SpriteHairStyle {
  const SpriteHairStyle({
    required this.id,
    required this.label,
    required this.frontAsset,
    required this.backAsset,
  });

  final String id;
  final String label;
  final String frontAsset;
  final String backAsset;
}

class SpriteAppearanceCatalog {
  const SpriteAppearanceCatalog._();

  static const actors = [
    SpriteActorAppearance(
      id: 'default',
      label: 'Default',
      faceProfileId: 'default',
      defaultHairStyleId: 'medium',
      defaultSkinTone: '#F2EDEF',
    ),
    SpriteActorAppearance(
      id: 'hero',
      label: 'Hero',
      faceProfileId: 'hero',
      defaultHairStyleId: 'short',
      defaultSkinTone: '#EFC9AA',
    ),
    SpriteActorAppearance(
      id: 'heroine',
      label: 'Heroine',
      faceProfileId: 'heroine',
      defaultHairStyleId: 'long',
      defaultSkinTone: '#F3D2BD',
    ),
    SpriteActorAppearance(
      id: 'elder',
      label: 'Elder',
      faceProfileId: 'elder',
      defaultHairStyleId: 'medium',
      defaultSkinTone: '#DDB99D',
    ),
    SpriteActorAppearance(
      id: 'adult',
      label: 'Adult',
      faceProfileId: 'adult_deep',
      defaultHairStyleId: 'short',
      defaultSkinTone: '#C99575',
    ),
  ];

  static const hairStyles = [
    SpriteHairStyle(
      id: 'short',
      label: 'Short',
      frontAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_default.png',
      backAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/back_short.png',
    ),
    SpriteHairStyle(
      id: 'medium',
      label: 'Medium',
      frontAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_default.png',
      backAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/back_default.png',
    ),
    SpriteHairStyle(
      id: 'long',
      label: 'Long',
      frontAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_default.png',
      backAsset: 'assets/images/characters/rigs/humanoid_v1/hair/back_long.png',
    ),
  ];

  static SpriteActorAppearance actor(String id) {
    return actors.firstWhere(
      (value) => value.id == id,
      orElse: () => actors.first,
    );
  }

  static SpriteActorAppearance actorForProfile(String profileId) {
    return actors.firstWhere(
      (value) => value.faceProfileId == profileId,
      orElse: () => actors.first,
    );
  }

  static SpriteHairStyle hair(String id) {
    return hairStyles.firstWhere(
      (value) => value.id == id,
      orElse: () => hairStyles[1],
    );
  }
}

class SpriteAppearanceRepository {
  const SpriteAppearanceRepository({this.rigId = 'humanoid_v1'});

  final String rigId;

  String get _storageKey => 'sprite_studio.$rigId.appearance';

  Future<SpriteAppearanceSelection> load() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_storageKey);
    if (source == null) return const SpriteAppearanceSelection();
    try {
      return SpriteAppearanceSelection.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
    } catch (_) {
      return const SpriteAppearanceSelection();
    }
  }

  Future<void> save(SpriteAppearanceSelection appearance) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(appearance.toJson()));
  }
}
