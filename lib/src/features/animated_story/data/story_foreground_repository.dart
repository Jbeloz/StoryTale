import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'story_bible_models.dart';

enum StoryForegroundAssetStatus { required, generated, approved, rejected }

class StoryForegroundAssetData {
  const StoryForegroundAssetData({
    required this.assetId,
    required this.bookId,
    required this.entityId,
    required this.entityKind,
    required this.entityName,
    required this.variantId,
    required this.description,
    required this.chapterIds,
    required this.reasons,
    this.status = StoryForegroundAssetStatus.required,
    this.imageBase64,
    this.mimeType = 'image/png',
    this.width,
    this.height,
    this.generationPrompt,
    this.generatedAt,
  });

  final String assetId;
  final String bookId;
  final String entityId;
  final StoryEntityKind entityKind;
  final String entityName;
  final String variantId;
  final String description;
  final List<String> chapterIds;
  final List<String> reasons;
  final StoryForegroundAssetStatus status;
  final String? imageBase64;
  final String mimeType;
  final int? width;
  final int? height;
  final String? generationPrompt;
  final String? generatedAt;

  String get key => '$entityId::$variantId';

  StoryForegroundAssetData copyWith({
    String? entityName,
    String? description,
    List<String>? chapterIds,
    List<String>? reasons,
    StoryForegroundAssetStatus? status,
    String? imageBase64,
    String? mimeType,
    int? width,
    int? height,
    String? generationPrompt,
    String? generatedAt,
  }) {
    return StoryForegroundAssetData(
      assetId: assetId,
      bookId: bookId,
      entityId: entityId,
      entityKind: entityKind,
      entityName: entityName ?? this.entityName,
      variantId: variantId,
      description: description ?? this.description,
      chapterIds: chapterIds ?? this.chapterIds,
      reasons: reasons ?? this.reasons,
      status: status ?? this.status,
      imageBase64: imageBase64 ?? this.imageBase64,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      generationPrompt: generationPrompt ?? this.generationPrompt,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'assetId': assetId,
    'bookId': bookId,
    'entityId': entityId,
    'entityKind': entityKind.name,
    'entityName': entityName,
    'variantId': variantId,
    'description': description,
    'chapterIds': chapterIds,
    'reasons': reasons,
    'status': status.name,
    if (imageBase64 != null) 'imageBase64': imageBase64,
    'mimeType': mimeType,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (generationPrompt != null) 'generationPrompt': generationPrompt,
    if (generatedAt != null) 'generatedAt': generatedAt,
  };

  factory StoryForegroundAssetData.fromJson(Map<String, dynamic> json) {
    return StoryForegroundAssetData(
      assetId: json['assetId'] as String,
      bookId: json['bookId'] as String,
      entityId: json['entityId'] as String,
      entityKind: StoryEntityKind.values.byName(json['entityKind'] as String),
      entityName: json['entityName'] as String,
      variantId: json['variantId'] as String,
      description: json['description'] as String? ?? '',
      chapterIds: _strings(json['chapterIds']),
      reasons: _strings(json['reasons']),
      status: StoryForegroundAssetStatus.values.byName(
        json['status'] as String? ?? 'required',
      ),
      imageBase64: json['imageBase64'] as String?,
      mimeType: json['mimeType'] as String? ?? 'image/png',
      width: json['width'] as int?,
      height: json['height'] as int?,
      generationPrompt: json['generationPrompt'] as String?,
      generatedAt: json['generatedAt'] as String?,
    );
  }

  static String stableId({
    required String bookId,
    required String entityId,
    required String variantId,
  }) {
    return 'foreground.${_segment(bookId)}.'
        '${_segment(entityId)}.${_segment(variantId)}';
  }

  static List<String> _strings(dynamic value) {
    return (value as List<dynamic>? ?? const []).whereType<String>().toList(
      growable: false,
    );
  }

  static String _segment(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

class StoryForegroundRepository {
  static const _keyPrefix = 'storytale.foreground_catalog.v1.';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<List<StoryForegroundAssetData>> load(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString('$_keyPrefix$bookId');
    if (source == null) return const [];
    try {
      return (jsonDecode(source) as List<dynamic>)
          .map(
            (value) => StoryForegroundAssetData.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .where((asset) => asset.bookId == bookId)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<StoryForegroundAssetData>> sync(BookStoryBibleData bible) async {
    final existing = {
      for (final asset in await load(bible.bookId)) asset.key: asset,
    };
    final required = _requirements(bible);
    final assets = [
      for (final requirement in required)
        if (existing[requirement.key] case final saved?)
          saved.copyWith(
            entityName: requirement.entityName,
            description: requirement.description,
            chapterIds: requirement.chapterIds,
            reasons: requirement.reasons,
          )
        else
          requirement,
    ];
    return _persist(bible.bookId, assets);
  }

  Future<List<StoryForegroundAssetData>> save(
    StoryForegroundAssetData asset,
  ) async {
    final assets = [...await load(asset.bookId)];
    final index = assets.indexWhere((item) => item.key == asset.key);
    if (index < 0) {
      assets.add(asset);
    } else {
      assets[index] = asset;
    }
    return _persist(asset.bookId, assets);
  }

  List<StoryForegroundAssetData> _requirements(BookStoryBibleData bible) {
    final assets = <StoryForegroundAssetData>[];
    for (final entity in bible.entities) {
      if (!entity.approved || !_isForegroundKind(entity.kind)) continue;
      final reasons = _reasons(entity);
      if (reasons.isEmpty) continue;
      for (final variant in _variants(entity)) {
        assets.add(
          StoryForegroundAssetData(
            assetId: StoryForegroundAssetData.stableId(
              bookId: bible.bookId,
              entityId: entity.entityId,
              variantId: variant,
            ),
            bookId: bible.bookId,
            entityId: entity.entityId,
            entityKind: entity.kind,
            entityName: entity.canonicalName,
            variantId: variant,
            description: entity.description,
            chapterIds: entity.chapterAppearanceIds,
            reasons: reasons,
          ),
        );
      }
    }
    return assets;
  }

  bool _isForegroundKind(StoryEntityKind kind) {
    return switch (kind) {
      StoryEntityKind.animal ||
      StoryEntityKind.creature ||
      StoryEntityKind.plant ||
      StoryEntityKind.prop => true,
      StoryEntityKind.human || StoryEntityKind.location => false,
    };
  }

  List<String> _reasons(StoryEntityData entity) {
    return [
      if (entity.speaker) 'speaking',
      if (entity.recurring || entity.chapterAppearanceIds.length > 1)
        'recurring',
      if (entity.visualStates.isNotEmpty) 'changes state',
      if (entity.importance != StoryEntityImportance.background) 'visual focus',
    ];
  }

  List<String> _variants(StoryEntityData entity) {
    if (entity.kind == StoryEntityKind.animal ||
        entity.kind == StoryEntityKind.creature) {
      return entity.speaker ? const ['neutral', 'talking'] : const ['neutral'];
    }
    final states = <String>{
      'normal',
      ...entity.visualStates.map(_stateId).where((state) => state.isNotEmpty),
    };
    return states.toList(growable: false);
  }

  String _stateId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<List<StoryForegroundAssetData>> _persist(
    String bookId,
    List<StoryForegroundAssetData> assets,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      '$_keyPrefix$bookId',
      jsonEncode(assets.map((asset) => asset.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('The foreground inventory could not be saved.');
    }
    revision.value++;
    return List.unmodifiable(assets);
  }
}
