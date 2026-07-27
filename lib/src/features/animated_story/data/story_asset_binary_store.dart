import 'package:flutter/foundation.dart';

/// Keeps generated image bytes outside SharedPreferences and page state.
///
/// Phase 8 will replace this session store with durable file storage.
class StoryAssetBinaryStore {
  const StoryAssetBinaryStore._();

  static final Map<String, Uint8List> _bytes = {};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Uint8List? read(String assetId) => _bytes[assetId];

  static bool contains(String assetId) => _bytes.containsKey(assetId);

  static void write(String assetId, Uint8List bytes) {
    _bytes[assetId] = bytes;
    revision.value++;
  }

  static void move(String fromAssetId, String toAssetId) {
    final bytes = _bytes.remove(fromAssetId);
    if (bytes == null) return;
    _bytes[toAssetId] = bytes;
    revision.value++;
  }

  static void remove(String assetId) {
    if (_bytes.remove(assetId) != null) revision.value++;
  }
}
