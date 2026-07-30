import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sprite_layer_processor.dart';
import 'story_asset_binary_store.dart';
import 'story_bible_models.dart';

enum StoryHumanAssetStatus { required, approved, needsReview }

class StoryHumanAssetData {
  const StoryHumanAssetData({
    required this.bookId,
    required this.entityId,
    required this.name,
    required this.description,
    required this.chapterIds,
    required this.actorProfileId,
    required this.faceProfileId,
    required this.rigId,
    required this.partAssetIds,
    required this.rigMetadata,
    this.voiceId,
    this.status = StoryHumanAssetStatus.required,
    this.width,
    this.height,
    this.generationPrompt,
    this.generatedAt,
    this.validationError,
  });

  final String bookId;
  final String entityId;
  final String name;
  final String description;
  final List<String> chapterIds;
  final String actorProfileId;
  final String faceProfileId;
  final String rigId;
  final Map<String, String> partAssetIds;
  final StoryHumanRigMetadata rigMetadata;
  final String? voiceId;
  final StoryHumanAssetStatus status;
  final int? width;
  final int? height;
  final String? generationPrompt;
  final String? generatedAt;
  final String? validationError;

  String get masterAssetId => '$rigId.master';
  String get rejoinedAssetId => '$rigId.rejoined';
  Uint8List get masterBytes =>
      StoryAssetBinaryStore.read(masterAssetId) ?? Uint8List(0);

  bool get hasReadyBytes =>
      masterBytes.isNotEmpty &&
      StoryAssetBinaryStore.contains(rejoinedAssetId) &&
      partAssetIds.values.every(StoryAssetBinaryStore.contains);

  StoryHumanAssetData copyWith({
    String? name,
    String? description,
    List<String>? chapterIds,
    String? actorProfileId,
    String? faceProfileId,
    String? voiceId,
    StoryHumanAssetStatus? status,
    int? width,
    int? height,
    String? generationPrompt,
    String? generatedAt,
    String? validationError,
    bool clearValidationError = false,
  }) {
    return StoryHumanAssetData(
      bookId: bookId,
      entityId: entityId,
      name: name ?? this.name,
      description: description ?? this.description,
      chapterIds: chapterIds ?? this.chapterIds,
      actorProfileId: actorProfileId ?? this.actorProfileId,
      faceProfileId: faceProfileId ?? this.faceProfileId,
      rigId: rigId,
      partAssetIds: partAssetIds,
      rigMetadata: rigMetadata,
      voiceId: voiceId ?? this.voiceId,
      status: status ?? this.status,
      width: width ?? this.width,
      height: height ?? this.height,
      generationPrompt: generationPrompt ?? this.generationPrompt,
      generatedAt: generatedAt ?? this.generatedAt,
      validationError: clearValidationError
          ? null
          : validationError ?? this.validationError,
    );
  }

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'entityId': entityId,
    'name': name,
    'description': description,
    'chapterIds': chapterIds,
    'actorProfileId': actorProfileId,
    'faceProfileId': faceProfileId,
    'rigId': rigId,
    'partAssetIds': partAssetIds,
    'rigMetadata': rigMetadata.toJson(),
    if (voiceId != null) 'voiceId': voiceId,
    'status': status.name,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (generationPrompt != null) 'generationPrompt': generationPrompt,
    if (generatedAt != null) 'generatedAt': generatedAt,
    if (validationError != null) 'validationError': validationError,
  };

  factory StoryHumanAssetData.fromJson(Map<String, dynamic> json) {
    return StoryHumanAssetData(
      bookId: json['bookId'] as String,
      entityId: json['entityId'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      chapterIds: _strings(json['chapterIds']),
      actorProfileId: json['actorProfileId'] as String? ?? 'default',
      faceProfileId: json['faceProfileId'] as String? ?? 'default',
      rigId: json['rigId'] as String,
      partAssetIds: Map<String, String>.from(
        json['partAssetIds'] as Map? ?? const {},
      ),
      rigMetadata: StoryHumanRigMetadata.fromJson(
        Map<String, dynamic>.from(json['rigMetadata'] as Map? ?? const {}),
      ),
      voiceId: json['voiceId'] as String?,
      status: StoryHumanAssetStatus.values.byName(
        json['status'] as String? ?? 'required',
      ),
      width: json['width'] as int?,
      height: json['height'] as int?,
      generationPrompt: json['generationPrompt'] as String?,
      generatedAt: json['generatedAt'] as String?,
      validationError: json['validationError'] as String?,
    );
  }

  static StoryHumanAssetData requiredFor(
    String bookId,
    StoryEntityData entity,
  ) {
    final profile = StoryHumanProfileSelector.select(entity);
    final rigId = 'human.${_segment(bookId)}.${_segment(entity.entityId)}';
    return StoryHumanAssetData(
      bookId: bookId,
      entityId: entity.entityId,
      name: entity.canonicalName,
      description: entity.description,
      chapterIds: entity.chapterAppearanceIds,
      actorProfileId: profile,
      faceProfileId: profile == 'adult' ? 'adult_deep' : profile,
      rigId: rigId,
      partAssetIds: {
        for (final partId in SpriteLayerProcessor.rigPartIds)
          partId: '$rigId.$partId',
      },
      rigMetadata: StoryHumanRigMetadata.standard(),
      voiceId: entity.voiceId,
    );
  }

  static String _segment(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static List<String> _strings(dynamic value) {
    return (value as List<dynamic>? ?? const []).whereType<String>().toList(
      growable: false,
    );
  }
}

class StoryHumanRigMetadata {
  const StoryHumanRigMetadata({
    required this.version,
    required this.parentByPart,
    required this.pivotByPart,
    required this.neutralOffsetByPart,
    required this.layerOrder,
    required this.poseIds,
    required this.faceSetIds,
  });

  final int version;
  final Map<String, String> parentByPart;
  final Map<String, List<double>> pivotByPart;
  final Map<String, List<double>> neutralOffsetByPart;
  final List<String> layerOrder;
  final List<String> poseIds;
  final List<String> faceSetIds;

  factory StoryHumanRigMetadata.standard() {
    const parts = SpriteLayerProcessor.rigPartIds;
    return StoryHumanRigMetadata(
      version: 1,
      parentByPart: const {
        'head': 'torso',
        'torso': '',
        'left_upper_arm': 'torso',
        'left_lower_arm': 'left_upper_arm',
        'right_upper_arm': 'torso',
        'right_lower_arm': 'right_upper_arm',
        'left_upper_leg': 'torso',
        'left_lower_leg': 'left_upper_leg',
        'right_upper_leg': 'torso',
        'right_lower_leg': 'right_upper_leg',
      },
      pivotByPart: const {
        'head': [0.50, 0.46],
        'torso': [0.50, 0.46],
        'left_upper_arm': [0.27, 0.50],
        'left_lower_arm': [0.22, 0.69],
        'right_upper_arm': [0.73, 0.50],
        'right_lower_arm': [0.78, 0.69],
        'left_upper_leg': [0.42, 0.69],
        'left_lower_leg': [0.42, 0.83],
        'right_upper_leg': [0.58, 0.69],
        'right_lower_leg': [0.58, 0.83],
      },
      neutralOffsetByPart: {
        for (final part in parts) part: const [0, 0],
      },
      layerOrder: const [
        'left_lower_leg',
        'left_upper_leg',
        'left_lower_arm',
        'left_upper_arm',
        'torso',
        'right_upper_leg',
        'right_lower_leg',
        'right_upper_arm',
        'right_lower_arm',
        'head',
      ],
      poseIds: const ['neutral', 'talking', 'pointing', 'walking'],
      faceSetIds: const [
        'neutral',
        'talking',
        'happy',
        'sad',
        'angry',
        'surprised',
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'parentByPart': parentByPart,
    'pivotByPart': pivotByPart,
    'neutralOffsetByPart': neutralOffsetByPart,
    'layerOrder': layerOrder,
    'poseIds': poseIds,
    'faceSetIds': faceSetIds,
  };

  factory StoryHumanRigMetadata.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return StoryHumanRigMetadata.standard();
    Map<String, List<double>> points(dynamic value) => {
      for (final entry in Map<String, dynamic>.from(
        value as Map? ?? const {},
      ).entries)
        entry.key: (entry.value as List<dynamic>)
            .whereType<num>()
            .map((number) => number.toDouble())
            .toList(growable: false),
    };
    return StoryHumanRigMetadata(
      version: json['version'] as int? ?? 1,
      parentByPart: Map<String, String>.from(
        json['parentByPart'] as Map? ?? const {},
      ),
      pivotByPart: points(json['pivotByPart']),
      neutralOffsetByPart: points(json['neutralOffsetByPart']),
      layerOrder: StoryHumanAssetData._strings(json['layerOrder']),
      poseIds: StoryHumanAssetData._strings(json['poseIds']),
      faceSetIds: StoryHumanAssetData._strings(json['faceSetIds']),
    );
  }
}

class StoryHumanProfileSelector {
  const StoryHumanProfileSelector._();

  static String select(StoryEntityData entity) {
    final text =
        '${entity.canonicalName} ${entity.aliases.join(' ')} '
                '${entity.description}'
            .toLowerCase();
    if (_has(text, [
      'elder',
      'elderly',
      'old man',
      'old woman',
      'grandfather',
      'grandmother',
    ])) {
      return 'elder';
    }
    if (_has(text, [
      'girl',
      'woman',
      'female',
      'heroine',
      'princess',
      'queen',
      'mother',
      'sister',
    ])) {
      return 'heroine';
    }
    if (_has(text, [
      'adult man',
      'grown man',
      'father',
      'guard',
      'soldier',
      'deep voice',
    ])) {
      return 'adult';
    }
    if (_has(text, ['hero', 'protagonist', 'prince', 'boy', 'young man'])) {
      return 'hero';
    }
    return 'default';
  }

  static bool _has(String text, List<String> values) =>
      values.any(text.contains);
}

class StoryHumanRepository {
  static const _keyPrefix = 'storytale.human_catalog.v1.';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<List<StoryHumanAssetData>> load(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString('$_keyPrefix$bookId');
    if (source == null) return const [];
    try {
      return (jsonDecode(source) as List<dynamic>)
          .map(
            (value) => StoryHumanAssetData.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .where((asset) => asset.bookId == bookId)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<StoryHumanAssetData>> sync(BookStoryBibleData bible) async {
    final existing = {
      for (final asset in await load(bible.bookId)) asset.entityId: asset,
    };
    final assets = [
      for (final entity in bible.entities)
        if (entity.kind == StoryEntityKind.human && entity.approved)
          if (existing[entity.entityId] case final saved?)
            saved.status == StoryHumanAssetStatus.approved
                ? saved
                : saved.copyWith(
                    name: entity.canonicalName,
                    description: entity.description,
                    chapterIds: entity.chapterAppearanceIds,
                    voiceId: entity.voiceId,
                  )
          else
            StoryHumanAssetData.requiredFor(bible.bookId, entity),
    ];
    return _persist(bible.bookId, assets);
  }

  Future<List<StoryHumanAssetData>> save(StoryHumanAssetData asset) async {
    final assets = [...await load(asset.bookId)];
    final index = assets.indexWhere((item) => item.entityId == asset.entityId);
    if (index < 0) {
      assets.add(asset);
    } else {
      assets[index] = asset;
    }
    return _persist(asset.bookId, assets);
  }

  Future<List<StoryHumanAssetData>> loadReady(String bookId) async {
    return List.unmodifiable(
      (await load(bookId)).where(
        (asset) =>
            asset.status == StoryHumanAssetStatus.approved &&
            asset.hasReadyBytes,
      ),
    );
  }

  Future<List<StoryHumanAssetData>> _persist(
    String bookId,
    List<StoryHumanAssetData> assets,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix$bookId',
      jsonEncode(assets.map((asset) => asset.toJson()).toList()),
    );
    revision.value++;
    return List.unmodifiable(assets);
  }
}
