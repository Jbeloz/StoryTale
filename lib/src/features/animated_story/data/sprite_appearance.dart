import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpriteHairFit {
  const SpriteHairFit({this.offsetX = 0, this.offsetY = 0, this.scale = 1});

  final double offsetX;
  final double offsetY;
  final double scale;

  factory SpriteHairFit.fromJson(Map<String, dynamic> json) {
    return SpriteHairFit(
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'offsetX': offsetX,
    'offsetY': offsetY,
    'scale': scale,
  };
}

class SpriteAppearanceSelection {
  const SpriteAppearanceSelection({
    this.actorId = 'default',
    this.hairStyleId = 'medium',
    this.skinTone = '#F2EDEF',
    this.hairFits = const {},
  });

  final String actorId;
  final String hairStyleId;
  final String skinTone;
  final Map<String, Map<String, SpriteHairFit>> hairFits;

  SpriteAppearanceSelection copyWith({
    String? actorId,
    String? hairStyleId,
    String? skinTone,
    Map<String, Map<String, SpriteHairFit>>? hairFits,
  }) {
    return SpriteAppearanceSelection(
      actorId: actorId ?? this.actorId,
      hairStyleId: hairStyleId ?? this.hairStyleId,
      skinTone: skinTone ?? this.skinTone,
      hairFits: hairFits ?? this.hairFits,
    );
  }

  String hairFitKey(String partId) {
    return partId == 'back_hair' ? '$partId:$hairStyleId' : partId;
  }

  SpriteHairFit hairFitForPart(String partId) {
    return hairFits[actorId]?[hairFitKey(partId)] ?? const SpriteHairFit();
  }

  SpriteAppearanceSelection withHairFitForPart(
    String partId,
    SpriteHairFit fit,
  ) {
    final actorFits = <String, SpriteHairFit>{
      ...?hairFits[actorId],
      hairFitKey(partId): fit,
    };
    return copyWith(hairFits: {...hairFits, actorId: actorFits});
  }

  factory SpriteAppearanceSelection.fromJson(Map<String, dynamic> json) {
    final hairFits = <String, Map<String, SpriteHairFit>>{};
    final source = json['hairFits'];
    if (source is Map) {
      for (final actorEntry in source.entries) {
        final actorSource = actorEntry.value;
        if (actorSource is! Map) continue;
        hairFits[actorEntry.key.toString()] = {
          for (final fitEntry in actorSource.entries)
            if (fitEntry.value is Map)
              fitEntry.key.toString(): SpriteHairFit.fromJson(
                Map<String, dynamic>.from(fitEntry.value as Map),
              ),
        };
      }
    }
    return SpriteAppearanceSelection(
      actorId: json['actorId'] as String? ?? 'default',
      hairStyleId: json['hairStyleId'] as String? ?? 'medium',
      skinTone: json['skinTone'] as String? ?? '#F2EDEF',
      hairFits: hairFits,
    );
  }

  Map<String, dynamic> toJson() => {
    'actorId': actorId,
    'hairStyleId': hairStyleId,
    'skinTone': skinTone,
    'hairFits': {
      for (final actorEntry in hairFits.entries)
        actorEntry.key: {
          for (final fitEntry in actorEntry.value.entries)
            fitEntry.key: fitEntry.value.toJson(),
        },
    },
  };

  String toJsonString() => jsonEncode(toJson());
}

class SpriteActorAppearance {
  const SpriteActorAppearance({
    required this.id,
    required this.label,
    required this.faceProfileId,
    required this.frontHairAsset,
    required this.defaultHairStyleId,
    required this.defaultSkinTone,
  });

  final String id;
  final String label;
  final String faceProfileId;
  final String frontHairAsset;
  final String defaultHairStyleId;
  final String defaultSkinTone;
}

class SpriteHairStyle {
  const SpriteHairStyle({
    required this.id,
    required this.label,
    required this.backAsset,
  });

  final String id;
  final String label;
  final String backAsset;

  bool get hasBackHair => backAsset.isNotEmpty;
}

class SpriteAppearanceCatalog {
  const SpriteAppearanceCatalog._();

  static const _heroineLongBackHair =
      'assets/images/characters/rigs/humanoid_v1/hair/back_heroine_long.png';

  static const actors = [
    SpriteActorAppearance(
      id: 'default',
      label: 'Default',
      faceProfileId: 'default',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_default.png',
      defaultHairStyleId: 'medium',
      defaultSkinTone: '#F2EDEF',
    ),
    SpriteActorAppearance(
      id: 'hero',
      label: 'Hero',
      faceProfileId: 'hero',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_hero.png',
      defaultHairStyleId: 'short',
      defaultSkinTone: '#EFC9AA',
    ),
    SpriteActorAppearance(
      id: 'heroine',
      label: 'Heroine',
      faceProfileId: 'heroine',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_heroine_v8.png',
      defaultHairStyleId: 'none',
      defaultSkinTone: '#F3D2BD',
    ),
    SpriteActorAppearance(
      id: 'elder',
      label: 'Elder',
      faceProfileId: 'elder',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_elder.png',
      defaultHairStyleId: 'none',
      defaultSkinTone: '#DDB99D',
    ),
    SpriteActorAppearance(
      id: 'adult',
      label: 'Adult',
      faceProfileId: 'adult_deep',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_adult.png',
      defaultHairStyleId: 'short',
      defaultSkinTone: '#C99575',
    ),
  ];

  static const hairStyles = [
    SpriteHairStyle(id: 'none', label: 'None', backAsset: ''),
    SpriteHairStyle(
      id: 'short',
      label: 'Short',
      backAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/back_short.png',
    ),
    SpriteHairStyle(
      id: 'medium',
      label: 'Medium',
      backAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/back_default.png',
    ),
    SpriteHairStyle(
      id: 'long',
      label: 'Long',
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
      orElse: () => hairStyles[2],
    );
  }

  static String backHairAsset(String actorId, String hairStyleId) {
    if (actorId == 'heroine' && hairStyleId == 'long') {
      return _heroineLongBackHair;
    }
    return hair(hairStyleId).backAsset;
  }
}

class SpriteAppearanceRepository {
  const SpriteAppearanceRepository({this.rigId = 'humanoid_v1'});

  final String rigId;

  String get _storageKey => 'sprite_studio.$rigId.appearance';
  String get _projectAsset =>
      'assets/images/characters/rigs/$rigId/appearance.json';

  Future<SpriteAppearanceSelection> load() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_storageKey);
    if (source == null) return _loadProjectDefault();
    try {
      return SpriteAppearanceSelection.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
    } catch (_) {
      return _loadProjectDefault();
    }
  }

  Future<SpriteAppearanceSelection> _loadProjectDefault() async {
    try {
      final source = await rootBundle.loadString(_projectAsset);
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
