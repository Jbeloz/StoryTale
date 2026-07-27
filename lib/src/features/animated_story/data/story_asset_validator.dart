import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'story_foreground_repository.dart';

class StoryAssetValidator {
  const StoryAssetValidator();

  String? validateBackground({
    required Uint8List bytes,
    required String mimeType,
    required int width,
    required int height,
    required List<String> chapterIds,
  }) {
    if (!const {'image/png', 'image/jpeg', 'image/webp'}.contains(mimeType)) {
      return 'Unsupported background file type.';
    }
    if (width != 1024 || height != 576) {
      return 'Background must be exactly 1024x576.';
    }
    if (chapterIds.isEmpty) {
      return 'Background has no chapter ownership.';
    }
    if (image.decodeImage(bytes) == null) {
      return 'Background image is corrupt.';
    }
    return null;
  }

  String? validateForeground(StoryForegroundAssetData asset, Uint8List bytes) {
    if (asset.mimeType != 'image/png') {
      return 'Foreground must be a transparent PNG.';
    }
    if (asset.chapterIds.isEmpty) {
      return 'Foreground has no chapter ownership.';
    }
    final decoded = image.decodeImage(bytes);
    if (decoded == null || decoded.width < 2 || decoded.height < 2) {
      return 'Foreground image is corrupt.';
    }
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        if (image.getAlpha(decoded.getPixel(x, y)) < 255) return null;
      }
    }
    return 'Foreground PNG does not contain transparency.';
  }
}
