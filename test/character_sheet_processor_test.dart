import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/character_sheet_contract.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_processor.dart';

import 'character_sheet_fixtures.dart';

/// Local packaging checks for whichever contract is registered.
///
/// Nothing here contacts a provider. Sheets are built from the contract's own
/// guide and masks, which is enough to exercise every check a live sheet hits.
///
/// The head is the reason this file exists. Every other locked part is stored
/// trimmed to its rig box, but the head is a `1254 x 1254` canvas the rig fits
/// into a `357 x 367` box, so packaging used to reject its own head before any
/// generated pixel was examined.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterSheetContract contract;
  late CharacterSheetFixture fixture;

  setUpAll(() async {
    contract = await CharacterSheetContractRepository().load();
    fixture = await CharacterSheetFixture.load(
      contract: contract,
      backHairId: 'medium',
    );
  });

  test('packages a preserved sheet without rejecting the locked head', () async {
    // The provider returned the reference untouched, which is the minimum a
    // compliant reply can be. The run must get all the way to the proofs
    // instead of failing on the locked head, which is what an unfitted
    // 1254 x 1254 head base did before it was fitted to its 357 x 367 cell.
    final request = testRequest(backHairId: 'medium');
    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, fixture.preservedSheet()),
    );

    expect(
      package.validation.errors,
      isEmpty,
      reason: 'an untouched reference breaks no rule',
    );
    expect(package.validation.geometryValid, isTrue);
    expect(package.previewBytesByPose, hasLength(4));
    expect(package.facePreviewBytesByExpression, hasLength(6));
  });

  test('keeps face detail drawn inside the head allowed window', () async {
    // The allowed window is where a character's own skin detail may go, and it
    // has to survive the locked-head alpha check rather than be rejected as
    // pixels outside the head.
    final request = testRequest(backHairId: 'medium');
    final sheet = fixture.preservedSheet();
    final painted = fixture.paintAppearance(sheet, const ['head']);
    expect(painted, greaterThan(0), reason: 'the head has an allowed window');

    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, sheet),
    );

    expect(
      package.validation.errors.where((error) => error.contains('head')),
      isEmpty,
      reason: 'contract-respecting face detail must not be rejected',
    );
    expect(package.validation.geometryValid, isTrue);
    expect(
      package.validation.visiblePixelsByRegion['head'],
      closeTo(painted, painted * 0.02),
      reason: 'JPEG moves the window edge slightly; the layer is still the same',
    );
    expect(package.layerBytes.containsKey('head'), isTrue);
  });

  test('extracts the rear-hair layer the selected length activates', () async {
    // V4 collapses V1's three rear-hair cells into one, so the region a length
    // activates has to come from the contract. Hardcoding V1's IDs would leave
    // this layer silently unextracted on a paid sheet.
    final request = testRequest(backHairId: 'medium');
    final regionId = request.selectedBackHairRegion(contract);
    expect(regionId, 'back_hair_selected');

    final sheet = fixture.preservedSheet();
    final painted = fixture.paintAppearance(sheet, [regionId]);
    expect(painted, greaterThan(0));

    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, sheet),
    );

    expect(
      package.validation.visiblePixelsByRegion[regionId],
      closeTo(painted, painted * 0.02),
    );
    expect(package.layerBytes.containsKey(regionId), isTrue);
    expect(
      package.validation.errors.where((error) => error.contains(regionId)),
      isEmpty,
      reason: 'the selected rear-hair cell must not read as empty or stray',
    );
  });

  test('skipping the proof pass cannot pass as an accepted package', () async {
    // The testing switch trades the six face and four pose compositions for
    // speed while we iterate on what the provider draws. It must be impossible
    // for that to read as a good result: no proofs, not valid, and an error
    // that says why rather than leaving someone to infer it.
    final request = testRequest(backHairId: 'medium');
    final sheet = fixture.preservedSheet();
    fixture.paintAppearance(sheet, fixture.activeRegionIds(request));
    final generation = fixture.resultFor(request, sheet);

    final skipped = await CharacterSheetProcessor().process(
      request: request,
      generation: generation,
      composeProofs: false,
    );

    expect(skipped.validation.proofsByFace, isEmpty);
    expect(skipped.validation.proofsByPose, isEmpty);
    expect(skipped.validation.faceProofValid, isFalse);
    expect(skipped.validation.poseProofValid, isFalse);
    expect(skipped.validation.isValid, isFalse);
    expect(skipped.validation.errors.join(' '), contains('skipped for testing'));
    // The sheet itself still comes back, which is the whole point of skipping.
    expect(skipped.sourceBytes, generation.bytes);
    expect(skipped.layerBytes, isNotEmpty);
    expect(
      skipped.neutralProofBytes,
      isNotEmpty,
      reason: 'the safe preview must not throw when no proof was composed',
    );

    // Same sheet with the switch off still reaches a full, valid package, so
    // the option changes only how much work runs.
    final full = await CharacterSheetProcessor().process(
      request: request,
      generation: generation,
    );
    expect(full.validation.isValid, isTrue);
    expect(full.validation.proofsByPose, hasLength(4));
  });

  test('rejects a sheet that wiped the locked geometry', () async {
    // A blank green sheet is not a neutral input. It is a provider that erased
    // everything it was told to preserve, and it must be caught rather than
    // packaged as an empty character.
    final request = testRequest(backHairId: 'medium');
    final blank = image.Image(contract.canvas.width, contract.canvas.height)
      ..channels = image.Channels.rgb;
    image.fill(blank, image.getColor(0, 255, 0));

    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, blank),
    );

    expect(package.validation.geometryValid, isFalse);
    expect(
      package.validation.errors.join(' '),
      contains('locked geometry'),
    );
  });
}
