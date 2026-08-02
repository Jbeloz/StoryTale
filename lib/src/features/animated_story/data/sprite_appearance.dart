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

class SpriteActorAppearanceSelection {
  const SpriteActorAppearanceSelection({
    required this.frontHairId,
    required this.backHairId,
    required this.skinTone,
  });

  final String frontHairId;
  final String backHairId;
  final String skinTone;

  SpriteActorAppearanceSelection copyWith({
    String? frontHairId,
    String? backHairId,
    String? skinTone,
  }) {
    return SpriteActorAppearanceSelection(
      frontHairId: frontHairId ?? this.frontHairId,
      backHairId: backHairId ?? this.backHairId,
      skinTone: skinTone ?? this.skinTone,
    );
  }

  Map<String, dynamic> toJson() => {
    'frontHairId': frontHairId,
    'backHairId': backHairId,
    'skinTone': skinTone,
  };
}

class SpriteAppearanceSelection {
  const SpriteAppearanceSelection({
    this.actorId = 'default',
    this.actorAppearances = const {},
    this.hairFits = const {},
  });

  final String actorId;
  final Map<String, SpriteActorAppearanceSelection> actorAppearances;
  final Map<String, Map<String, SpriteHairFit>> hairFits;

  SpriteActorAppearanceSelection actorAppearance([String? requestedActorId]) {
    final actor = SpriteAppearanceCatalog.actor(requestedActorId ?? actorId);
    final saved = actorAppearances[actor.id];
    final frontHairId =
        SpriteAppearanceCatalog.isFrontHairCompatible(
          actor.id,
          saved?.frontHairId,
        )
        ? saved!.frontHairId
        : actor.defaultFrontHairId;
    final backHairId = SpriteAppearanceCatalog.containsHair(saved?.backHairId)
        ? saved!.backHairId
        : actor.defaultHairStyleId;
    return SpriteActorAppearanceSelection(
      frontHairId: frontHairId,
      backHairId: backHairId,
      skinTone: SpriteAppearanceCatalog.normalizedSkinTone(
        saved?.skinTone,
        actor.defaultSkinTone,
      ),
    );
  }

  String get frontHairId => actorAppearance().frontHairId;
  String get hairStyleId => actorAppearance().backHairId;
  String get skinTone => actorAppearance().skinTone;

  SpriteAppearanceSelection copyWith({
    String? actorId,
    String? frontHairId,
    String? hairStyleId,
    String? skinTone,
    Map<String, SpriteActorAppearanceSelection>? actorAppearances,
    Map<String, Map<String, SpriteHairFit>>? hairFits,
  }) {
    final nextActorId = SpriteAppearanceCatalog.actor(
      actorId ?? this.actorId,
    ).id;
    var nextActorAppearances = actorAppearances ?? this.actorAppearances;
    if (frontHairId != null || hairStyleId != null || skinTone != null) {
      final current = SpriteAppearanceSelection(
        actorId: nextActorId,
        actorAppearances: nextActorAppearances,
      ).actorAppearance();
      nextActorAppearances = {
        ...nextActorAppearances,
        nextActorId: current.copyWith(
          frontHairId: frontHairId,
          backHairId: hairStyleId,
          skinTone: skinTone,
        ),
      };
    }
    return SpriteAppearanceSelection(
      actorId: nextActorId,
      actorAppearances: nextActorAppearances,
      hairFits: hairFits ?? this.hairFits,
    );
  }

  String hairFitKey(String partId) {
    if (partId == 'front_hair') return '$partId:$frontHairId';
    if (partId == 'back_hair') return '$partId:$hairStyleId';
    return partId;
  }

  SpriteHairFit hairFitForPart(String partId) {
    final actorFits = hairFits[actorId];
    return actorFits?[hairFitKey(partId)] ??
        actorFits?[partId] ??
        const SpriteHairFit();
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
    final actorAppearances = <String, SpriteActorAppearanceSelection>{};
    final appearanceSource = json['actorAppearances'];
    if (appearanceSource is Map) {
      for (final entry in appearanceSource.entries) {
        final actorId = entry.key.toString();
        if (!SpriteAppearanceCatalog.containsActor(actorId) ||
            entry.value is! Map) {
          continue;
        }
        final actor = SpriteAppearanceCatalog.actor(actorId);
        final value = Map<String, dynamic>.from(entry.value as Map);
        actorAppearances[actor.id] = SpriteActorAppearanceSelection(
          frontHairId:
              value['frontHairId'] as String? ?? actor.defaultFrontHairId,
          backHairId:
              value['backHairId'] as String? ?? actor.defaultHairStyleId,
          skinTone: value['skinTone'] as String? ?? actor.defaultSkinTone,
        );
      }
    }
    final activeActor = SpriteAppearanceCatalog.actor(
      json['actorId'] as String? ?? 'default',
    );
    if (!actorAppearances.containsKey(activeActor.id) &&
        (json.containsKey('frontHairId') ||
            json.containsKey('hairStyleId') ||
            json.containsKey('skinTone'))) {
      actorAppearances[activeActor.id] = SpriteActorAppearanceSelection(
        frontHairId:
            json['frontHairId'] as String? ?? activeActor.defaultFrontHairId,
        backHairId:
            json['hairStyleId'] as String? ?? activeActor.defaultHairStyleId,
        skinTone: json['skinTone'] as String? ?? activeActor.defaultSkinTone,
      );
    }
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
      actorId: activeActor.id,
      actorAppearances: actorAppearances,
      hairFits: hairFits,
    );
  }

  Map<String, dynamic> toJson() {
    final savedActors = {
      for (final actor in SpriteAppearanceCatalog.actors)
        actor.id: actorAppearance(actor.id),
    };
    return {
      'actorId': actorId,
      'frontHairId': frontHairId,
      'hairStyleId': hairStyleId,
      'skinTone': skinTone,
      'actorAppearances': {
        for (final entry in savedActors.entries)
          entry.key: entry.value.toJson(),
      },
      'hairFits': {
        for (final actorEntry in hairFits.entries)
          actorEntry.key: {
            for (final fitEntry in actorEntry.value.entries)
              fitEntry.key: fitEntry.value.toJson(),
          },
      },
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class SpriteActorAppearance {
  const SpriteActorAppearance({
    required this.id,
    required this.label,
    required this.faceProfileId,
    required this.defaultFrontHairId,
    required this.frontHairAsset,
    required this.defaultHairStyleId,
    required this.defaultSkinTone,
  });

  final String id;
  final String label;
  final String faceProfileId;
  final String defaultFrontHairId;
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
      defaultFrontHairId: 'front_default',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_default.png',
      defaultHairStyleId: 'medium',
      defaultSkinTone: '#F2EDEF',
    ),
    SpriteActorAppearance(
      id: 'hero',
      label: 'Hero',
      faceProfileId: 'hero',
      defaultFrontHairId: 'front_hero',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_hero.png',
      defaultHairStyleId: 'short',
      defaultSkinTone: '#EFC9AA',
    ),
    SpriteActorAppearance(
      id: 'heroine',
      label: 'Heroine',
      faceProfileId: 'heroine',
      defaultFrontHairId: 'front_heroine_v8',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_heroine_v8.png',
      defaultHairStyleId: 'none',
      defaultSkinTone: '#F3D2BD',
    ),
    SpriteActorAppearance(
      id: 'elder',
      label: 'Elder',
      faceProfileId: 'elder',
      defaultFrontHairId: 'front_elder',
      frontHairAsset:
          'assets/images/characters/rigs/humanoid_v1/hair/front_elder.png',
      defaultHairStyleId: 'none',
      defaultSkinTone: '#DDB99D',
    ),
    SpriteActorAppearance(
      id: 'adult',
      label: 'Adult',
      faceProfileId: 'adult_deep',
      defaultFrontHairId: 'front_adult',
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

  static bool containsActor(String? id) {
    return id != null && actors.any((actor) => actor.id == id);
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

  static bool containsHair(String? id) {
    return id != null && hairStyles.any((hair) => hair.id == id);
  }

  static bool isFrontHairCompatible(String actorId, String? frontHairId) {
    return frontHairId != null &&
        actor(actorId).defaultFrontHairId == frontHairId;
  }

  static String frontHairAsset(String actorId, String frontHairId) {
    final selectedActor = actor(actorId);
    if (!isFrontHairCompatible(selectedActor.id, frontHairId)) {
      return selectedActor.frontHairAsset;
    }
    return actors
        .firstWhere(
          (actor) => actor.defaultFrontHairId == frontHairId,
          orElse: () => selectedActor,
        )
        .frontHairAsset;
  }

  static String normalizedSkinTone(String? source, String fallback) {
    final value = source?.trim().toUpperCase();
    return value != null && RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)
        ? value
        : fallback;
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
