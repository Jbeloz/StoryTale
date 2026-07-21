import 'dart:convert';

import 'package:flutter/services.dart';

class SpriteFaceProfileCatalog {
  SpriteFaceProfileCatalog({
    required this.defaultProfileId,
    required this.profiles,
  }) : profilesById = {for (final profile in profiles) profile.id: profile};

  final String defaultProfileId;
  final List<SpriteFaceProfileEntry> profiles;
  final Map<String, SpriteFaceProfileEntry> profilesById;

  static Future<SpriteFaceProfileCatalog> load(
    String assetPath, {
    AssetBundle? bundle,
  }) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    return SpriteFaceProfileCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  factory SpriteFaceProfileCatalog.fromJson(Map<String, dynamic> json) {
    return SpriteFaceProfileCatalog(
      defaultProfileId: json['defaultProfileId'] as String,
      profiles: (json['profiles'] as List<dynamic>)
          .map(
            (value) =>
                SpriteFaceProfileEntry.fromJson(value as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  String resolveProfileId(String? requestedId) {
    return requestedId != null && profilesById.containsKey(requestedId)
        ? requestedId
        : defaultProfileId;
  }

  SpriteFaceProfileEntry entryFor(String? requestedId) {
    return profilesById[resolveProfileId(requestedId)]!;
  }

  Future<SpriteFaceProfileBundle> loadProfile(
    String? requestedId, {
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    final entry = entryFor(requestedId);
    final profile = await SpriteFaceProfile.load(
      entry.manifest,
      bundle: assets,
    );
    final sets = await SpriteFaceSetCatalog.load(
      profile.setsAsset,
      bundle: assets,
    );
    if (entry.id != profile.id || profile.id != sets.profileId) {
      throw FormatException('Face profile IDs do not match for ${entry.id}.');
    }
    return SpriteFaceProfileBundle(profile: profile, sets: sets);
  }
}

class SpriteFaceProfileEntry {
  const SpriteFaceProfileEntry({
    required this.id,
    required this.label,
    required this.manifest,
  });

  final String id;
  final String label;
  final String manifest;

  factory SpriteFaceProfileEntry.fromJson(Map<String, dynamic> json) {
    return SpriteFaceProfileEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      manifest: json['manifest'] as String,
    );
  }
}

class SpriteFaceProfile {
  const SpriteFaceProfile({
    required this.id,
    required this.label,
    required this.rigId,
    required this.headPartId,
    required this.headTemplateId,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.defaultSetId,
    required this.status,
    required this.parts,
    required this.setsAsset,
    this.approvedReference,
  });

  final String id;
  final String label;
  final String rigId;
  final String headPartId;
  final String headTemplateId;
  final int canvasWidth;
  final int canvasHeight;
  final String defaultSetId;
  final String status;
  final String? approvedReference;
  final SpriteFacePartDirectories parts;
  final String setsAsset;

  bool get isReady => status == 'ready';

  static Future<SpriteFaceProfile> load(
    String assetPath, {
    AssetBundle? bundle,
  }) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    return SpriteFaceProfile.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  factory SpriteFaceProfile.fromJson(Map<String, dynamic> json) {
    final canvas = json['canvas'] as Map<String, dynamic>;
    return SpriteFaceProfile(
      id: json['id'] as String,
      label: json['label'] as String,
      rigId: json['rigId'] as String,
      headPartId: json['headPartId'] as String,
      headTemplateId: json['headTemplateId'] as String,
      canvasWidth: (canvas['width'] as num).toInt(),
      canvasHeight: (canvas['height'] as num).toInt(),
      defaultSetId: json['defaultSetId'] as String,
      status: json['status'] as String,
      approvedReference: json['approvedReference'] as String?,
      parts: SpriteFacePartDirectories.fromJson(
        json['parts'] as Map<String, dynamic>,
      ),
      setsAsset: json['sets'] as String,
    );
  }
}

class SpriteFacePartDirectories {
  const SpriteFacePartDirectories({
    required this.eyes,
    required this.noses,
    required this.mouths,
    required this.details,
  });

  final String eyes;
  final String noses;
  final String mouths;
  final String details;

  factory SpriteFacePartDirectories.fromJson(Map<String, dynamic> json) {
    return SpriteFacePartDirectories(
      eyes: json['eyes'] as String,
      noses: json['noses'] as String,
      mouths: json['mouths'] as String,
      details: json['details'] as String,
    );
  }

  String asset(String directory, String id) {
    final separator = directory.endsWith('/') ? '' : '/';
    return '$directory$separator$id.png';
  }
}

class SpriteFaceSetCatalog {
  SpriteFaceSetCatalog({
    required this.profileId,
    required this.defaultSetId,
    required this.sets,
  }) : setsById = {for (final set in sets) set.id: set};

  static const legacySetIds = {
    'neutral': 'neutral',
    'talking': 'talking',
    'happy': 'happy',
    'sad': 'sad',
    'angry': 'angry',
  };

  final String profileId;
  final String defaultSetId;
  final List<SpriteFaceSet> sets;
  final Map<String, SpriteFaceSet> setsById;

  static Future<SpriteFaceSetCatalog> load(
    String assetPath, {
    AssetBundle? bundle,
  }) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    return SpriteFaceSetCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  factory SpriteFaceSetCatalog.fromJson(Map<String, dynamic> json) {
    return SpriteFaceSetCatalog(
      profileId: json['profileId'] as String,
      defaultSetId: json['defaultSetId'] as String,
      sets: (json['sets'] as List<dynamic>)
          .map((value) => SpriteFaceSet.fromJson(value as Map<String, dynamic>))
          .toList(),
    );
  }

  String resolveSetId(
    String? requestedId, {
    String? legacyExpressionId,
    bool isSpeaking = false,
  }) {
    final legacyId = legacySetIds[legacyExpressionId];
    final candidate = requestedId?.trim().isNotEmpty == true
        ? requestedId!
        : legacyId ?? defaultSetId;
    var safeId = setsById.containsKey(candidate) ? candidate : defaultSetId;
    if (isSpeaking &&
        safeId == defaultSetId &&
        setsById.containsKey('talking')) {
      safeId = 'talking';
    }
    return safeId;
  }

  SpriteFaceSet setFor(
    String? requestedId, {
    String? legacyExpressionId,
    bool isSpeaking = false,
  }) {
    return setsById[resolveSetId(
      requestedId,
      legacyExpressionId: legacyExpressionId,
      isSpeaking: isSpeaking,
    )]!;
  }
}

class SpriteFaceSet {
  const SpriteFaceSet({
    required this.id,
    required this.label,
    required this.eyes,
    required this.nose,
    required this.mouth,
    required this.details,
  });

  final String id;
  final String label;
  final String eyes;
  final String nose;
  final String mouth;
  final List<String> details;

  factory SpriteFaceSet.fromJson(Map<String, dynamic> json) {
    return SpriteFaceSet(
      id: json['id'] as String,
      label: json['label'] as String,
      eyes: json['eyes'] as String,
      nose: json['nose'] as String,
      mouth: json['mouth'] as String,
      details: (json['details'] as List<dynamic>).cast<String>(),
    );
  }
}

class SpriteFaceProfileBundle {
  const SpriteFaceProfileBundle({required this.profile, required this.sets});

  final SpriteFaceProfile profile;
  final SpriteFaceSetCatalog sets;

  SpriteFaceComposition compositionFor(
    String? requestedSetId, {
    String? legacyExpressionId,
    bool isSpeaking = false,
  }) {
    final set = sets.setFor(
      requestedSetId,
      legacyExpressionId: legacyExpressionId,
      isSpeaking: isSpeaking,
    );
    final parts = profile.parts;
    return SpriteFaceComposition(
      profileId: profile.id,
      setId: set.id,
      layerAssets: [
        parts.asset(parts.eyes, set.eyes),
        parts.asset(parts.noses, set.nose),
        parts.asset(parts.mouths, set.mouth),
        for (final detail in set.details) parts.asset(parts.details, detail),
      ],
    );
  }
}

class SpriteFaceComposition {
  const SpriteFaceComposition({
    required this.profileId,
    required this.setId,
    required this.layerAssets,
  });

  final String profileId;
  final String setId;
  final List<String> layerAssets;
}
