import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sprite_layer_processor.dart';
import 'sprite_rig.dart';
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
    this.packageVersion = 2,
    this.packageValidated = false,
    this.generationProvider,
    this.generationModel,
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
  final int packageVersion;
  final bool packageValidated;
  final String? generationProvider;
  final String? generationModel;

  String get masterAssetId => '$rigId.master';
  String get rejoinedAssetId => '$rigId.rejoined';
  Uint8List get masterBytes =>
      StoryAssetBinaryStore.read(masterAssetId) ?? Uint8List(0);

  Map<String, Uint8List> get partBytesById => Map.unmodifiable({
    for (final id in SpriteLayerProcessor.rigPartIds)
      id: StoryAssetBinaryStore.read(partAssetIds[id] ?? '') ?? Uint8List(0),
  });

  SpriteRigDefinition get rigDefinition =>
      rigMetadata.toRigDefinition(rigId: rigId, partAssetIds: partAssetIds);

  Map<String, SpriteRigPose> get canonicalPoses =>
      rigMetadata.canonicalPoses(rigId);

  SpriteRigValidation get packageValidation {
    return const SpriteLayerProcessor().validateRigPackage(
      source: masterBytes,
      rejoined: StoryAssetBinaryStore.read(rejoinedAssetId) ?? Uint8List(0),
      parts: partBytesById,
      partFrames: rigMetadata.partFrames,
      width: width ?? rigMetadata.canvasWidth,
      height: height ?? rigMetadata.canvasHeight,
    );
  }

  bool get hasReadyBytes =>
      packageVersion >= 2 &&
      packageValidated &&
      rigMetadata.isComplete &&
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
    Map<String, String>? partAssetIds,
    StoryHumanRigMetadata? rigMetadata,
    int? packageVersion,
    bool? packageValidated,
    String? generationProvider,
    String? generationModel,
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
      partAssetIds: partAssetIds ?? this.partAssetIds,
      rigMetadata: rigMetadata ?? this.rigMetadata,
      voiceId: voiceId ?? this.voiceId,
      status: status ?? this.status,
      width: width ?? this.width,
      height: height ?? this.height,
      generationPrompt: generationPrompt ?? this.generationPrompt,
      generatedAt: generatedAt ?? this.generatedAt,
      validationError: clearValidationError
          ? null
          : validationError ?? this.validationError,
      packageVersion: packageVersion ?? this.packageVersion,
      packageValidated: packageValidated ?? this.packageValidated,
      generationProvider: generationProvider ?? this.generationProvider,
      generationModel: generationModel ?? this.generationModel,
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
    'packageVersion': packageVersion,
    'packageValidated': packageValidated,
    if (generationProvider != null) 'generationProvider': generationProvider,
    if (generationModel != null) 'generationModel': generationModel,
  };

  factory StoryHumanAssetData.fromJson(Map<String, dynamic> json) {
    final storedPartAssetIds = Map<String, String>.from(
      json['partAssetIds'] as Map? ?? const {},
    );
    return StoryHumanAssetData(
      bookId: json['bookId'] as String,
      entityId: json['entityId'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      chapterIds: _strings(json['chapterIds']),
      actorProfileId: json['actorProfileId'] as String? ?? 'default',
      faceProfileId: json['faceProfileId'] as String? ?? 'default',
      rigId: json['rigId'] as String,
      partAssetIds: {
        for (final entry in storedPartAssetIds.entries)
          SpriteLayerProcessor.canonicalPartId(entry.key): entry.value,
      },
      rigMetadata: StoryHumanRigMetadata.fromJson(
        Map<String, dynamic>.from(json['rigMetadata'] as Map? ?? const {}),
      ),
      voiceId: json['voiceId'] as String?,
      status: _status(json['status']),
      width: json['width'] as int?,
      height: json['height'] as int?,
      generationPrompt: json['generationPrompt'] as String?,
      generatedAt: json['generatedAt'] as String?,
      validationError: json['validationError'] as String?,
      packageVersion: json['packageVersion'] as int? ?? 1,
      packageValidated: json['packageValidated'] as bool? ?? false,
      generationProvider: json['generationProvider'] as String?,
      generationModel: json['generationModel'] as String?,
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
      packageVersion: 2,
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

  static StoryHumanAssetStatus _status(dynamic value) {
    final name = value as String? ?? StoryHumanAssetStatus.required.name;
    for (final item in StoryHumanAssetStatus.values) {
      if (item.name == name) return item;
    }
    return StoryHumanAssetStatus.required;
  }
}

class StoryHumanRigMetadata {
  const StoryHumanRigMetadata({
    required this.version,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.partFrames,
    required this.parentByPart,
    required this.pivotByPart,
    required this.neutralOffsetByPart,
    required this.layerOrder,
    required this.poseIds,
    required this.faceSetIds,
  });

  final int version;
  final int canvasWidth;
  final int canvasHeight;
  final Map<String, SpriteRigPartFrame> partFrames;
  final Map<String, String> parentByPart;
  final Map<String, List<double>> pivotByPart;
  final Map<String, List<double>> neutralOffsetByPart;
  final List<String> layerOrder;
  final List<String> poseIds;
  final List<String> faceSetIds;

  bool get isComplete =>
      canvasWidth == SpriteLayerProcessor.canonicalCanvasWidth &&
      canvasHeight == SpriteLayerProcessor.canonicalCanvasHeight &&
      SpriteLayerProcessor.rigPartIds.every(
        (id) =>
            partFrames.containsKey(id) &&
            parentByPart.containsKey(id) &&
            pivotByPart.containsKey(id) &&
            neutralOffsetByPart.containsKey(id) &&
            layerOrder.contains(id),
      ) &&
      const {
        'neutral',
        'talking',
        'pointing',
        'walking',
      }.every(poseIds.contains);

  SpriteRigDefinition toRigDefinition({
    required String rigId,
    required Map<String, String> partAssetIds,
  }) {
    return SpriteRigDefinition(
      id: rigId,
      canvasSize: Size(canvasWidth.toDouble(), canvasHeight.toDouble()),
      parts: [
        for (final id in SpriteLayerProcessor.rigPartIds)
          partFrames[id]!.toRigPart(partAssetIds[id] ?? '$rigId.$id'),
      ],
    );
  }

  Map<String, SpriteRigPose> canonicalPoses(String rigId) =>
      SpriteLayerProcessor.canonicalPosesFor(rigId);

  factory StoryHumanRigMetadata.standard() {
    const parts = SpriteLayerProcessor.rigPartIds;
    return StoryHumanRigMetadata(
      version: 2,
      canvasWidth: SpriteLayerProcessor.canonicalCanvasWidth,
      canvasHeight: SpriteLayerProcessor.canonicalCanvasHeight,
      partFrames: SpriteLayerProcessor.canonicalPartFrames,
      parentByPart: const {
        'head': 'torso',
        'torso': '',
        'upper_arm_left': 'torso',
        'lower_arm_left': 'upper_arm_left',
        'upper_arm_right': 'torso',
        'lower_arm_right': 'upper_arm_right',
        'upper_leg_left': 'torso',
        'lower_leg_left': 'upper_leg_left',
        'upper_leg_right': 'torso',
        'lower_leg_right': 'upper_leg_right',
      },
      pivotByPart: const {
        'head': [552.88, 544.54],
        'torso': [558.45, 756.28],
        'upper_arm_left': [589.09, 578.78],
        'lower_arm_left': [619.6, 662.56],
        'upper_arm_right': [497, 588.29],
        'lower_arm_right': [473.71, 659],
        'upper_leg_left': [603.29, 760],
        'lower_leg_left': [599.29, 873],
        'upper_leg_right': [513.6, 752.56],
        'lower_leg_right': [509, 862.71],
      },
      neutralOffsetByPart: {
        for (final part in parts) part: const [0, 0],
      },
      layerOrder: const [
        'lower_leg_left',
        'upper_leg_left',
        'lower_arm_left',
        'upper_arm_left',
        'torso',
        'upper_leg_right',
        'lower_leg_right',
        'upper_arm_right',
        'lower_arm_right',
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

  factory StoryHumanRigMetadata.fromProcessedLayers(SpriteRigLayers layers) {
    final standard = StoryHumanRigMetadata.standard();
    return StoryHumanRigMetadata(
      version: 2,
      canvasWidth: layers.width,
      canvasHeight: layers.height,
      partFrames: Map.unmodifiable(layers.partFrames),
      parentByPart: standard.parentByPart,
      pivotByPart: {
        for (final entry in layers.partFrames.entries)
          entry.key: [entry.value.pivotX, entry.value.pivotY],
      },
      neutralOffsetByPart: standard.neutralOffsetByPart,
      layerOrder: standard.layerOrder,
      poseIds: standard.poseIds,
      faceSetIds: standard.faceSetIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'canvas': {'width': canvasWidth, 'height': canvasHeight},
    'partFrames': {
      for (final entry in partFrames.entries) entry.key: entry.value.toJson(),
    },
    'parentByPart': parentByPart,
    'pivotByPart': pivotByPart,
    'neutralOffsetByPart': neutralOffsetByPart,
    'layerOrder': layerOrder,
    'poseIds': poseIds,
    'faceSetIds': faceSetIds,
  };

  factory StoryHumanRigMetadata.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return StoryHumanRigMetadata.standard();
    final standard = StoryHumanRigMetadata.standard();
    final version = json['version'] as int? ?? 1;
    final canvas = Map<String, dynamic>.from(
      json['canvas'] as Map? ?? const {},
    );

    Map<String, String> stringsByPart(dynamic value) => {
      for (final entry in Map<String, dynamic>.from(
        value as Map? ?? const {},
      ).entries)
        SpriteLayerProcessor.canonicalPartId(entry.key):
            SpriteLayerProcessor.canonicalPartId(entry.value as String? ?? ''),
    };

    Map<String, List<double>> points(dynamic value) => {
      for (final entry in Map<String, dynamic>.from(
        value as Map? ?? const {},
      ).entries)
        SpriteLayerProcessor.canonicalPartId(
          entry.key,
        ): (entry.value as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((number) => number.toDouble())
            .toList(growable: false),
    };

    final storedFrames = Map<String, dynamic>.from(
      json['partFrames'] as Map? ?? const {},
    );
    final parsedFrames = <String, SpriteRigPartFrame>{
      for (final entry in storedFrames.entries)
        SpriteLayerProcessor.canonicalPartId(
          entry.key,
        ): SpriteRigPartFrame.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
    final frames = version >= 2 && parsedFrames.isNotEmpty
        ? {
            for (final id in SpriteLayerProcessor.rigPartIds)
              id:
                  parsedFrames[id] ??
                  SpriteLayerProcessor.canonicalPartFrames[id]!,
          }
        : standard.partFrames;

    final storedParents = stringsByPart(json['parentByPart']);
    final storedPivots = points(json['pivotByPart']);
    final storedOffsets = points(json['neutralOffsetByPart']);
    List<String> canonicalIds(dynamic value, List<String> fallback) {
      final result = <String>[];
      for (final id in StoryHumanAssetData._strings(value)) {
        final canonical = SpriteLayerProcessor.canonicalPartId(id);
        if (SpriteLayerProcessor.rigPartIds.contains(canonical) &&
            !result.contains(canonical)) {
          result.add(canonical);
        }
      }
      return result.isEmpty ? fallback : result;
    }

    return StoryHumanRigMetadata(
      version: version < 2 ? 2 : version,
      canvasWidth: (canvas['width'] as num?)?.toInt() ?? standard.canvasWidth,
      canvasHeight:
          (canvas['height'] as num?)?.toInt() ?? standard.canvasHeight,
      partFrames: Map.unmodifiable(frames),
      parentByPart: {
        for (final id in SpriteLayerProcessor.rigPartIds)
          id: storedParents[id] ?? standard.parentByPart[id]!,
      },
      pivotByPart: {
        for (final id in SpriteLayerProcessor.rigPartIds)
          id: version >= 2 && (storedPivots[id]?.length ?? 0) >= 2
              ? storedPivots[id]!
              : standard.pivotByPart[id]!,
      },
      neutralOffsetByPart: {
        for (final id in SpriteLayerProcessor.rigPartIds)
          id: (storedOffsets[id]?.length ?? 0) >= 2
              ? storedOffsets[id]!
              : standard.neutralOffsetByPart[id]!,
      },
      layerOrder: canonicalIds(json['layerOrder'], standard.layerOrder),
      poseIds: StoryHumanAssetData._strings(json['poseIds']).isEmpty
          ? standard.poseIds
          : StoryHumanAssetData._strings(json['poseIds']),
      faceSetIds: StoryHumanAssetData._strings(json['faceSetIds']).isEmpty
          ? standard.faceSetIds
          : StoryHumanAssetData._strings(json['faceSetIds']),
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
