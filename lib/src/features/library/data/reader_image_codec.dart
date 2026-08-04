import 'dart:typed_data';

import 'package:image/image.dart' as image;

/// Shrinks EPUB artwork once at import time.
///
/// EPUB covers and illustrations are print-resolution: the repository fixture
/// carries a 1.9 MB cover and 16 illustrations totalling 15.6 MB. Those sizes
/// are far larger than the reader ever draws, and the web preview keeps saved
/// books in browser local storage, which holds only a few megabytes in total.
///
/// Shrinking here means the in-memory bytes, the library grid, the reader, and
/// local storage all share one small copy.
class ReaderImageCodec {
  const ReaderImageCodec();

  /// Library and Book Details draw the cover as a thumbnail.
  static const coverMaxWidth = 600;
  static const coverQuality = 80;

  /// Illustrations are drawn at most one screen tall.
  static const illustrationMaxWidth = 800;
  static const illustrationQuality = 72;

  Uint8List? shrinkCover(List<int>? source) =>
      _shrink(source, maxWidth: coverMaxWidth, quality: coverQuality);

  Uint8List? shrinkIllustration(List<int>? source) => _shrink(
    source,
    maxWidth: illustrationMaxWidth,
    quality: illustrationQuality,
  );

  Uint8List? _shrink(
    List<int>? source, {
    required int maxWidth,
    required int quality,
  }) {
    if (source == null || source.isEmpty) return null;
    final original = source is Uint8List ? source : Uint8List.fromList(source);

    final image.Image? decoded;
    try {
      decoded = image.decodeImage(original);
    } catch (_) {
      // A damaged or unsupported image must not fail the whole import.
      return null;
    }
    if (decoded == null) return null;

    // Never upscale a small image.
    final resized = decoded.width > maxWidth
        ? image.copyResize(
            decoded,
            width: maxWidth,
            interpolation: image.Interpolation.average,
          )
        : decoded;

    // JPEG discards transparency, so keep PNG when the source has an alpha
    // channel. The resize alone still removes most of the weight.
    final keepAlpha =
        resized.channels == image.Channels.rgba && _hasAlpha(resized);
    final List<int> encoded;
    try {
      encoded = keepAlpha
          ? image.encodePng(resized)
          : image.encodeJpg(resized, quality: quality);
    } catch (_) {
      return null;
    }

    // Re-encoding a small image can be larger than the original.
    if (encoded.length >= original.length) return original;
    return Uint8List.fromList(encoded);
  }

  bool _hasAlpha(image.Image source) {
    for (final pixel in source.data) {
      if (((pixel >> 24) & 0xFF) < 0xFF) return true;
    }
    return false;
  }
}
