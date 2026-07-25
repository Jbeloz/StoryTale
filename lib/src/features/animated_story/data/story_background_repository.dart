import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class StoryBackgroundAssetData {
  const StoryBackgroundAssetData({
    required this.assetId,
    required this.bookId,
    required this.locationId,
    required this.stateId,
    required this.prompt,
    required this.imageBase64,
    required this.createdAt,
    this.approved = false,
  });

  final String assetId;
  final String bookId;
  final String locationId;
  final String stateId;
  final String prompt;
  final String imageBase64;
  final String createdAt;
  final bool approved;

  String get key => '$locationId::$stateId';

  Uint8List get bytes => base64Decode(imageBase64);

  StoryBackgroundAssetData copyWith({bool? approved}) {
    return StoryBackgroundAssetData(
      assetId: assetId,
      bookId: bookId,
      locationId: locationId,
      stateId: stateId,
      prompt: prompt,
      imageBase64: imageBase64,
      createdAt: createdAt,
      approved: approved ?? this.approved,
    );
  }

  Map<String, dynamic> toJson() => {
    'assetId': assetId,
    'bookId': bookId,
    'locationId': locationId,
    'stateId': stateId,
    'prompt': prompt,
    'imageBase64': imageBase64,
    'createdAt': createdAt,
    'approved': approved,
  };

  factory StoryBackgroundAssetData.fromJson(Map<String, dynamic> json) {
    return StoryBackgroundAssetData(
      assetId: json['assetId'] as String,
      bookId: json['bookId'] as String,
      locationId: json['locationId'] as String,
      stateId: json['stateId'] as String,
      prompt: json['prompt'] as String? ?? '',
      imageBase64: json['imageBase64'] as String,
      createdAt: json['createdAt'] as String? ?? '',
      approved: json['approved'] as bool? ?? false,
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

  Future<List<StoryBackgroundAssetData>> load(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString('$_keyPrefix$bookId');
    if (source == null) return const [];
    try {
      return (jsonDecode(source) as List<dynamic>)
          .map(
            (item) => StoryBackgroundAssetData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((item) => item.bookId == bookId)
          .toList(growable: false);
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix${asset.bookId}',
      jsonEncode(assets.map((item) => item.toJson()).toList()),
    );
    return List.unmodifiable(assets);
  }
}
