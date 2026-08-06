import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/character_design_brief.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_contract.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_generation.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_processor.dart';

/// Local packaging checks for whichever contract is registered.
///
/// Nothing here contacts a provider. Each "generated" sheet is built in the
/// test from the contract's own canvas and masks, which is enough to exercise
/// the parts of the pipeline that read the locked runtime assets.
///
/// The head is the reason this file exists. Every other locked part is stored
/// trimmed to its rig box, but the head is a `1254 x 1254` canvas the rig fits
/// into a `357 x 367` box, so packaging used to reject its own head before any
/// generated pixel was examined.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterSheetContract contract;

  setUpAll(() async {
    contract = await CharacterSheetContractRepository().load();
  });

  CharacterSheetGenerationResult resultFor(
    CharacterSheetGenerationRequest request,
    image.Image sheet,
  ) {
    return CharacterSheetGenerationResult(
      bytes: Uint8List.fromList(image.encodePng(sheet)),
      mimeType: 'image/png',
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

  image.Image greenSheet() {
    final sheet = image.Image(contract.canvas.width, contract.canvas.height)
      ..channels = image.Channels.rgb;
    image.fill(sheet, image.getColor(0, 255, 0));
    return sheet;
  }

  test('packages a sheet without rejecting the locked head geometry', () async {
    final package = await CharacterSheetProcessor().process(
      request: _request,
      generation: resultFor(_request, greenSheet()),
    );

    // An all-green sheet legitimately reports one empty layer per region. What
    // it must not do is fail on the locked head before reading a single
    // generated pixel, which is what an unfitted `1254 x 1254` head base did.
    expect(
      package.validation.errors,
      everyElement(contains('appearance layer is empty')),
    );
    expect(package.validation.geometryValid, isTrue);
    expect(package.previewBytesByPose, hasLength(4));
    expect(package.facePreviewBytesByExpression, hasLength(6));
  });

  test('keeps face detail drawn inside the head allowed window', () async {
    // The allowed window is where a character's own skin detail may go. Filling
    // it stands in for a provider that respected the contract, and the result
    // has to survive the locked-head alpha check rather than be rejected as
    // pixels outside the head.
    final sheet = greenSheet();
    final painted = await _paintAllowedWindow(contract, sheet, 'head');
    expect(painted, greaterThan(0), reason: 'the head has an allowed window');

    final package = await CharacterSheetProcessor().process(
      request: _request,
      generation: resultFor(_request, sheet),
    );

    expect(
      package.validation.errors.where((error) => error.contains('head')),
      isEmpty,
      reason: 'contract-respecting face detail must not be rejected',
    );
    expect(package.validation.geometryValid, isTrue);
    expect(package.validation.visiblePixelsByRegion['head'], painted);
    expect(package.validation.rejectedPixelsByRegion['head'], 0);
  });

  test('extracts the rear-hair layer the selected length activates', () async {
    // V4 collapses V1's three rear-hair cells into one, so the region a length
    // activates has to come from the contract. Hardcoding V1's IDs would leave
    // this layer silently unextracted on a paid sheet.
    const request = _rearHairRequest;
    final regionId = request.selectedBackHairRegion(contract);
    expect(regionId, isNot('none'));
    expect(contract.regionsById.containsKey(regionId), isTrue);

    final sheet = greenSheet();
    final painted = await _paintAllowedWindow(contract, sheet, regionId);
    expect(painted, greaterThan(0));

    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: resultFor(request, sheet),
    );

    expect(package.validation.visiblePixelsByRegion[regionId], painted);
    expect(package.layerBytes.containsKey(regionId), isTrue);
    expect(
      package.validation.errors.where((error) => error.contains(regionId)),
      isEmpty,
      reason: 'the selected rear-hair cell must not read as empty or stray',
    );
  });
}

const _request = CharacterSheetGenerationRequest(
  brief: CharacterDesignBrief(
    bookId: 'book-test',
    characterId: 'character-test',
    canonicalName: 'Test Character',
    actorProfileId: 'default',
    sourceDescription: 'A plainly described test character.',
  ),
  skinTone: '#F2C9A0',
  frontHairId: 'front_default',
  backHairId: 'none',
  outfitRequirements: 'One plain coat, trousers, and boots.',
);

/// A rear-hair length, so the selected cell is active rather than left green.
const _rearHairRequest = CharacterSheetGenerationRequest(
  brief: CharacterDesignBrief(
    bookId: 'book-test',
    characterId: 'character-test-hair',
    canonicalName: 'Test Character',
    actorProfileId: 'default',
    sourceDescription: 'A plainly described test character.',
  ),
  skinTone: '#F2C9A0',
  frontHairId: 'front_default',
  backHairId: 'medium',
  outfitRequirements: 'One plain coat, trousers, and boots.',
);

/// Fills a region's writable window, standing in for a provider that respected
/// the masks. Returns how many pixels were painted.
Future<int> _paintAllowedWindow(
  CharacterSheetContract contract,
  image.Image sheet,
  String regionId,
) async {
  final region = contract.regionsById[regionId]!;
  final allowed = await _loadMask(contract.assets.allowedRegions);
  final protected = await _loadMask(contract.assets.protectedRegions);
  var painted = 0;
  for (var y = 0; y < region.crop.height; y++) {
    for (var x = 0; x < region.crop.width; x++) {
      final sheetX = region.crop.x + x;
      final sheetY = region.crop.y + y;
      if (image.getRed(allowed.getPixel(sheetX, sheetY)) < 250) continue;
      if (image.getRed(protected.getPixel(sheetX, sheetY)) >= 250) continue;
      sheet.setPixelRgba(sheetX, sheetY, 180, 90, 90, 255);
      painted++;
    }
  }
  return painted;
}

Future<image.Image> _loadMask(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  return image.decodeImage(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  )!;
}
