import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/character_sheet_contract.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_processor.dart';

import 'character_sheet_fixtures.dart';

/// Runs the real processor over a sheet shaped like a compliant provider reply,
/// so the pipeline is proven before a paid request rather than after one.
///
/// This exists because two live requests were spent discovering problems that
/// were all reproducible offline. Building the sheet locally costs nothing and
/// exercises every check a real one hits: geometry, masks, sides, seams,
/// cutting, and the four-pose and six-face proofs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterSheetContract contract;
  late CharacterSheetFixture fixture;
  final request = testRequest(backHairId: 'medium');

  setUpAll(() async {
    contract = await CharacterSheetContractRepository().load();
    fixture = await CharacterSheetFixture.load(
      contract: contract,
      backHairId: request.backHairId,
    );
  });

  Future<image.Image> compliantSheet() async {
    final sheet = fixture.preservedSheet();
    fixture.paintAppearance(sheet, fixture.activeRegionIds(request));
    return sheet;
  }

  test('accepts a compliant sheet and reaches the full proof gate', () async {
    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, await compliantSheet()),
    );

    expect(
      package.validation.errors,
      isEmpty,
      reason: 'a sheet that obeyed the contract must not be rejected',
    );
    expect(package.validation.geometryValid, isTrue);
    expect(package.validation.slotValid, isTrue);
    expect(package.validation.sideValid, isTrue);
    expect(package.validation.seamValid, isTrue);
    expect(package.validation.identityValid, isTrue);
    expect(package.validation.faceProofValid, isTrue);
    expect(package.validation.poseProofValid, isTrue);
    expect(package.validation.isValid, isTrue);
    expect(package.facePreviewBytesByExpression, hasLength(6));
    expect(package.previewBytesByPose, hasLength(4));
  });

  test('rejects a sheet that redrew the locked geometry', () async {
    // Phase 7G failed because the provider redrew the skull and body instead of
    // dressing them. Repainting the head and torso is about 6% of the protected
    // area, well clear of the 1% budget that keeps JPEG's 0.06% of ringing from
    // failing an honest sheet.
    final protected = fixture.protectedMask;
    final sheet = await compliantSheet();
    var vandalised = 0;
    for (final id in const ['head', 'torso']) {
      final region = contract.regionsById[id]!;
      for (var y = 0; y < region.crop.height; y++) {
        for (var x = 0; x < region.crop.width; x++) {
          final sheetX = region.crop.x + x;
          final sheetY = region.crop.y + y;
          if (image.getRed(protected.getPixel(sheetX, sheetY)) < 250) continue;
          if (CharacterSheetFixture.isGreen(sheet.getPixel(sheetX, sheetY))) {
            continue;
          }
          sheet.setPixelRgba(sheetX, sheetY, 200, 30, 30, 255);
          vandalised++;
        }
      }
    }
    expect(vandalised, greaterThan(0));

    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, sheet),
    );

    expect(package.validation.isValid, isFalse);
    expect(package.validation.geometryValid, isFalse);
    expect(package.validation.errors.join(' '), contains('locked geometry'));
  });

  test('rejects content in the padding between cells', () async {
    // The gap exists so generated content cannot bleed from one part into its
    // neighbour. Nothing legitimate is ever drawn there, so unlike the locked
    // area this stays zero-tolerance.
    final sheet = await compliantSheet();
    final torso = contract.regionsById['torso']!;
    for (var y = torso.crop.y; y < torso.crop.y + 10; y++) {
      for (var x = torso.crop.x - 12; x < torso.crop.x - 2; x++) {
        sheet.setPixelRgba(x, y, 200, 30, 30, 255);
      }
    }

    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, sheet),
    );

    expect(package.validation.seamValid, isFalse);
    expect(
      package.validation.errors.join(' '),
      contains('padding between cells'),
    );
  });

  test('drops and counts a garment left in a hair cell\'s empty space', () async {
    // Three consecutive live sheets drew something into the empty lower half of
    // the rear-hair cell: a hood, then a pair of free-standing garment objects.
    // None of them produced a single measurement, because that cell's allowed
    // window was the whole cell, so they were kept and cut straight into the
    // rear-hair layer. Narrowing the window to the hair silhouette is what makes
    // this detectable at all; without it every expectation below fails.
    final clean = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, await compliantSheet()),
    );

    final sheet = await compliantSheet();
    final cell = contract.regionsById['back_hair_selected']!.crop;
    // Well below the medium silhouette, which ends 215 px above the cell floor.
    var painted = 0;
    for (var y = cell.y + cell.height - 140; y < cell.y + cell.height - 20; y++) {
      for (var x = cell.x + 40; x < cell.x + 200; x++) {
        sheet.setPixelRgba(x, y, 40, 60, 200, 255);
        painted++;
      }
    }
    expect(painted, greaterThan(0));

    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, sheet),
    );

    expect(
      package.validation.errors.join(' '),
      contains('outside the permitted area'),
      reason: 'the sheet drew a garment where only hair may go',
    );
    expect(
      package.validation.errors.join(' '),
      isNot(contains('padding between cells')),
      reason: 'it stayed inside the cell, so it is not a padding failure',
    );
    expect(
      package.validation.visiblePixelsByRegion['back_hair_selected'],
      clean.validation.visiblePixelsByRegion['back_hair_selected'],
      reason: 'the garment must not reach the rear-hair layer',
    );
  });

  test('keeps a compliant sheet clear of the overspill rule', () async {
    // The counterpart to the case above: narrowing the hair windows must not
    // start rejecting hair that follows the template. JPEG at quality 95, the
    // only format this provider emits, puts zero pixels outside the windows on
    // the untouched guide, so a compliant sheet has the entire budget spare.
    final package = await CharacterSheetProcessor().process(
      request: request,
      generation: fixture.resultFor(request, await compliantSheet()),
    );

    expect(
      package.validation.errors.join(' '),
      isNot(contains('outside the permitted area')),
    );
    expect(package.validation.seamValid, isTrue);
  });

  test('rejects a rear-hair cell that should have stayed green', () async {
    // `none` means the runtime hides rear hair. Artwork in that cell would be
    // cut and stored as a layer nobody asked for.
    final noneRequest = testRequest(
      backHairId: 'none',
      characterId: 'character-test-none',
    );
    final sheet = fixture.preservedSheet();
    fixture.paintAppearance(sheet, fixture.activeRegionIds(noneRequest));
    fixture.paintAppearance(sheet, const ['back_hair_selected']);

    final package = await CharacterSheetProcessor().process(
      request: noneRequest,
      generation: fixture.resultFor(noneRequest, sheet),
    );

    expect(package.validation.slotValid, isFalse);
    expect(package.validation.errors.join(' '), contains('must stay green'));
  });
}
