import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'story_asset_binary_store.dart';

class StoryBackgroundAssetData {
  const StoryBackgroundAssetData({
    required this.assetId,
    required this.bookId,
    required this.locationId,
    required this.stateId,
    required this.prompt,
    required this.createdAt,
    this.imageBase64,
    this.approved = false,
    this.mimeType = 'image/jpeg',
    this.width = 1024,
    this.height = 576,
    this.brief = const {},
    this.chapterIds = const [],
    this.validationError,
  });

  final String assetId;
  final String bookId;
  final String locationId;
  final String stateId;
  final String prompt;
  final String? imageBase64;
  final String createdAt;
  final bool approved;
  final String mimeType;
  final int width;
  final int height;
  final Map<String, dynamic> brief;
  final List<String> chapterIds;
  final String? validationError;

  String get key => '$locationId::$stateId';

  Uint8List get bytes {
    final stored = StoryAssetBinaryStore.read(assetId);
    if (stored != null) return stored;
    final encoded = imageBase64;
    return encoded == null ? Uint8List(0) : base64Decode(encoded);
  }

  bool get hasBytes => bytes.isNotEmpty;

  bool get isVisualNovelSize => width == 1024 && height == 576;

  StoryBackgroundAssetData copyWith({
    String? assetId,
    bool? approved,
    String? imageBase64,
    bool clearImage = false,
    List<String>? chapterIds,
    String? validationError,
    bool clearValidationError = false,
  }) {
    return StoryBackgroundAssetData(
      assetId: assetId ?? this.assetId,
      bookId: bookId,
      locationId: locationId,
      stateId: stateId,
      prompt: prompt,
      imageBase64: clearImage ? null : imageBase64 ?? this.imageBase64,
      createdAt: createdAt,
      approved: approved ?? this.approved,
      mimeType: mimeType,
      width: width,
      height: height,
      brief: brief,
      chapterIds: chapterIds ?? this.chapterIds,
      validationError: clearValidationError
          ? null
          : validationError ?? this.validationError,
    );
  }

  Map<String, dynamic> toJson() => {
    'assetId': assetId,
    'bookId': bookId,
    'locationId': locationId,
    'stateId': stateId,
    'prompt': prompt,
    if (imageBase64 != null) 'imageBase64': imageBase64,
    'createdAt': createdAt,
    'approved': approved,
    'mimeType': mimeType,
    'width': width,
    'height': height,
    'brief': brief,
    'chapterIds': chapterIds,
    if (validationError != null) 'validationError': validationError,
  };

  factory StoryBackgroundAssetData.fromJson(Map<String, dynamic> json) {
    return StoryBackgroundAssetData(
      assetId: json['assetId'] as String,
      bookId: json['bookId'] as String,
      locationId: json['locationId'] as String,
      stateId: json['stateId'] as String,
      prompt: json['prompt'] as String? ?? '',
      imageBase64: json['imageBase64'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      approved: json['approved'] as bool? ?? false,
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      brief: Map<String, dynamic>.from(json['brief'] as Map? ?? const {}),
      chapterIds: (json['chapterIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      validationError: json['validationError'] as String?,
    );
  }

  static String stableId({
    required String bookId,
    required String locationId,
    required String stateId,
  }) {
    return 'background.${_segment(bookId)}.'
        '${_segment(locationId)}.${_segment(stateId)}';
  }

  static String candidateId({
    required String bookId,
    required String locationId,
    required String stateId,
    required DateTime createdAt,
  }) {
    return '${stableId(bookId: bookId, locationId: locationId, stateId: stateId)}.candidate.${createdAt.millisecondsSinceEpoch}';
  }

  static String _segment(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

class StoryBackgroundRepository {
  static const _keyPrefix = 'storytale.background_catalog.v1.';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<List<StoryBackgroundAssetData>> load(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString('$_keyPrefix$bookId');
    if (source == null) return const [];
    try {
      final assets = (jsonDecode(source) as List<dynamic>)
          .map(
            (item) => StoryBackgroundAssetData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((item) => item.bookId == bookId)
          .toList(growable: false);
      final compact = [for (final asset in assets) _compact(asset)];
      if (assets.any((asset) => asset.imageBase64 != null)) {
        await preferences.setString(
          '$_keyPrefix$bookId',
          jsonEncode(compact.map((asset) => asset.toJson()).toList()),
        );
      }
      return compact;
    } catch (_) {
      return const [];
    }
  }

  Future<List<StoryBackgroundAssetData>> save(
    StoryBackgroundAssetData asset,
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

  Future<List<StoryBackgroundAssetData>> saveCandidate(
    StoryBackgroundAssetData candidate,
  ) async {
    final assets = [
      for (final asset in await load(candidate.bookId))
        if (asset.key != candidate.key || asset.approved) asset,
      candidate.copyWith(approved: false),
    ];
    return _persist(candidate.bookId, assets);
  }

  Future<List<StoryBackgroundAssetData>> approveCandidate(
    StoryBackgroundAssetData candidate,
  ) async {
    final approvedId = StoryBackgroundAssetData.stableId(
      bookId: candidate.bookId,
      locationId: candidate.locationId,
      stateId: candidate.stateId,
    );
    StoryAssetBinaryStore.move(candidate.assetId, approvedId);
    final approved = candidate.copyWith(assetId: approvedId, approved: true);
    final assets = [
      for (final asset in await load(candidate.bookId))
        if (asset.key != candidate.key) asset,
      approved,
    ];
    return _persist(candidate.bookId, assets);
  }

  Future<List<StoryBackgroundAssetData>> rejectCandidate(
    StoryBackgroundAssetData candidate,
  ) async {
    StoryAssetBinaryStore.remove(candidate.assetId);
    final assets = [
      for (final asset in await load(candidate.bookId))
        if (asset.assetId != candidate.assetId) asset,
    ];
    return _persist(candidate.bookId, assets);
  }

  Future<StoryBackgroundAssetData?> loadApproved({
    required String bookId,
    required String locationId,
    required String stateId,
  }) async {
    for (final asset in await load(bookId)) {
      if (asset.locationId == locationId &&
          asset.stateId == stateId &&
          asset.approved &&
          asset.isVisualNovelSize &&
          asset.hasBytes) {
        return asset;
      }
    }
    return null;
  }

  Future<List<StoryBackgroundAssetData>> _persist(
    String bookId,
    List<StoryBackgroundAssetData> assets,
  ) async {
    final compact = [for (final asset in assets) _compact(asset)];
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      '$_keyPrefix$bookId',
      jsonEncode(compact.map((item) => item.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('The background catalog could not be saved.');
    }
    revision.value++;
    return List.unmodifiable(compact);
  }

  StoryBackgroundAssetData _compact(StoryBackgroundAssetData asset) {
    final encoded = asset.imageBase64;
    if (encoded != null && encoded.isNotEmpty) {
      StoryAssetBinaryStore.write(asset.assetId, base64Decode(encoded));
    }
    return asset.copyWith(clearImage: true);
  }
}
