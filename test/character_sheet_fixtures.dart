import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/character_design_brief.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_contract.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_generation.dart';

/// Builds sheets shaped like a real provider reply, so tests exercise the
/// pipeline the way a paid request would.
///
/// The important property is that a returned sheet is **the guide with
/// appearance added**, not appearance alone on green. The prompt tells the
/// provider to preserve the protected pixels, so they come back unchanged, and
/// validation is written around that. A blank green fixture reads as a provider
/// that erased the locked geometry, which is a different test entirely.
class CharacterSheetFixture {
  CharacterSheetFixture._(this.contract, this.guide, this._masks);

  static Future<CharacterSheetFixture> load({
    required CharacterSheetContract contract,
    required String backHairId,
  }) async {
    Future<image.Image> decode(String path) async {
      final data = await rootBundle.load(path);
      return image.decodeImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      )!;
    }

    return CharacterSheetFixture._(
      contract,
      await decode(contract.selection.guideFor(backHairId).path),
      {
        'allowed': await decode(contract.assets.allowedRegions),
        'protected': await decode(contract.assets.protectedRegions),
      },
    );
  }

  final CharacterSheetContract contract;
  final image.Image guide;
  final Map<String, image.Image> _masks;

  image.Image get protectedMask => _masks['protected']!;
  image.Image get allowedMask => _masks['allowed']!;

  /// The untouched guide: a provider that returned the reference unchanged.
  image.Image preservedSheet() =>
      image.Image.from(guide)..channels = image.Channels.rgb;

  /// Recolours the template artwork wherever drawing is allowed, leaving the
  /// green alone, and returns how many pixels changed.
  ///
  /// Recolouring rather than filling matters: both hair cells are 100% allowed
  /// and the rear-hair cell is sized for the longest style, so painting a whole
  /// cell returns a solid rectangle of "hair" that covers the face. That is
  /// exactly what the prompt contract's "a cell is a container, not a target"
  /// rule exists to prevent.
  int paintAppearance(
    image.Image sheet,
    Iterable<String> regionIds, {
    int red = 120,
    int green = 90,
    int blue = 170,
  }) {
    final allowed = _masks['allowed']!;
    final protected = _masks['protected']!;
    var painted = 0;
    for (final id in regionIds) {
      final region = contract.regionsById[id]!;
      for (var y = 0; y < region.crop.height; y++) {
        for (var x = 0; x < region.crop.width; x++) {
          final sheetX = region.crop.x + x;
          final sheetY = region.crop.y + y;
          if (image.getRed(allowed.getPixel(sheetX, sheetY)) < 250) continue;
          if (image.getRed(protected.getPixel(sheetX, sheetY)) >= 250) continue;
          if (isGreen(guide.getPixel(sheetX, sheetY))) continue;
          sheet.setPixelRgba(sheetX, sheetY, red, green, blue, 255);
          painted++;
        }
      }
    }
    return painted;
  }

  /// Every region the given request would activate.
  Iterable<String> activeRegionIds(CharacterSheetGenerationRequest request) {
    final selected = request.selectedBackHairRegion(contract);
    return contract.regions
        .where((region) => region.kind != 'backHair' || region.id == selected)
        .map((region) => region.id);
  }

  CharacterSheetGenerationResult resultFor(
    CharacterSheetGenerationRequest request,
    image.Image sheet,
  ) {
    // Encoded the way the provider actually answers. The Interactions API only
    // emits JPEG, so a PNG fixture would exercise a path production never sees.
    return CharacterSheetGenerationResult(
      bytes: Uint8List.fromList(image.encodeJpg(sheet, quality: 95)),
      mimeType: contract.canvas.mimeType,
      width: sheet.width,
      height: sheet.height,
      provider: 'test',
      model: 'test',
      requestId: 'test-request',
      requestFingerprint: request.fingerprint(contract),
      contractId: contract.contractId,
      contractVersion: contract.contractVersion,
      prompt: 'test',
      generatedAt: '2026-08-06T00:00:00.000Z',
    );
  }

  /// The processor's own background test, so fixtures and pipeline agree on
  /// what counts as untouched green.
  static bool isGreen(int pixel) {
    final red = image.getRed(pixel);
    final green = image.getGreen(pixel);
    final blue = image.getBlue(pixel);
    return green >= 160 && green >= red + 40 && green >= blue + 40;
  }
}

CharacterSheetGenerationRequest testRequest({
  required String backHairId,
  String characterId = 'character-test',
}) {
  return CharacterSheetGenerationRequest(
    brief: CharacterDesignBrief(
      bookId: 'book-test',
      characterId: characterId,
      canonicalName: 'Kestrel Vane',
      actorProfileId: 'default',
      sourceDescription: 'A plainly described test character.',
    ),
    skinTone: '#F2C9A0',
    frontHairId: 'front_default',
    backHairId: backHairId,
    outfitRequirements: 'One plain coat, trousers, and boots.',
  );
}
