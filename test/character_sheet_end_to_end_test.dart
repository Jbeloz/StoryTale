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
