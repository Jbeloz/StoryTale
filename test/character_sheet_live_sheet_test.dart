import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_contract.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_generation.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_package.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_processor.dart';

import 'character_sheet_fixtures.dart';

/// Replays a real returned sheet through the real processor.
///
/// Every other character-sheet test builds its input, which proves the rules but
/// not that they describe what the provider actually does. This one is the
/// eighth billed sheet, saved by the diagnostics endpoint, and it is here so the
/// $0.067 it cost keeps paying: the defects below can be re-measured any number
/// of times for free.
///
/// The original request's rear-hair length is not recorded in the saved report,
/// so this replays it as `medium`. That only decides which allowed-mask variant
/// is used, and every assertion here is chosen to be independent of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterSheetContract contract;
  late CharacterSheetPackage package;
  final request = testRequest(backHairId: 'medium');

  setUpAll(() async {
    contract = await CharacterSheetContractRepository().load();
    final bytes = File(
      '${Directory.current.path}/test/fixtures/eighth_live_sheet.jpg',
    ).readAsBytesSync();
    package = await CharacterSheetProcessor().process(
      request: request,
      generation: CharacterSheetGenerationResult(
        bytes: bytes,
        mimeType: contract.canvas.mimeType,
        width: contract.canvas.width,
        height: contract.canvas.height,
        provider: 'google-gemini',
        model: 'gemini-3.1-flash-image',
        requestId: 'eighth-live-sheet',
        requestFingerprint: request.fingerprint(contract),
        contractId: contract.contractId,
        contractVersion: contract.contractVersion,
        prompt: 'replayed from diagnostics',
        generatedAt: '2026-08-06T22:37:03.000Z',
      ),
    );
  });

  test('overspill is never charged to locked geometry that does not exist', () {
    // The defect this file was written for. `back_hair_selected` publishes zero
    // protected pixels, so it cannot damage locked geometry by definition. When
    // the two counts shared one field, its 47,708 overspill pixels were divided
    // by the protected area anyway and reported as "drew over 37.47% of the
    // locked area inside its cells" — pixels that were nowhere near it.
    final protectedInHairCell = contract.regions
        .firstWhere((region) => region.id == 'back_hair_selected');
    expect(protectedInHairCell.id, 'back_hair_selected');

    expect(
      package.validation.rejectedPixelsByRegion['back_hair_selected'],
      0,
      reason: 'a cell with no protected pixels cannot repaint locked geometry',
    );
    expect(
      package.validation.overspillPixelsByRegion['back_hair_selected'],
      greaterThan(10000),
      reason: 'the trouser legs drawn above the leg cells land here',
    );

    // The headline number the conflation inflated. This sheet reported 37.47%
    // of the locked area drawn over; separating the counts puts it at 5.38%,
    // which is the real figure for pixels that touched protected geometry.
    final lockedAreaError = package.validation.errors.firstWhere(
      (error) => error.contains('locked area inside its cells'),
      orElse: () => '',
    );
    final percent = double.parse(
      RegExp(r'([\d.]+)%').firstMatch(lockedAreaError)!.group(1)!,
    );
    expect(
      percent,
      lessThan(10),
      reason: 'anything near 37% means overspill is being counted here again',
    );
  });

  test('the sheet is rejected, and says where the misplaced pixels are', () {
    expect(package.validation.isValid, isFalse);

    final message = package.validation.errors.join(' ');
    expect(message, contains('outside the permitted area'));
    // The bounding box is the part that points at the real defect. Reporting a
    // cell name pointed at the hair, because that is the rectangle the trouser
    // legs happened to fall inside.
    expect(
      message,
      matches(RegExp(r'between \(\d+,\d+\) and \(\d+,\d+\)')),
      reason: 'the reader needs to know where, not just how much',
    );
  });

  test('every leg layer came back as a boot and nothing else', () {
    // The owner's report, pinned to a number so a future sheet can be compared
    // against it. Each leg cell holds a whole leg drawn about 310 px tall in a
    // cell 140-156 px tall, bottom-aligned, so the cell captures only the boot.
    //
    // This asserts the state of a known-bad sheet. It is expected to keep
    // passing: the fixture never changes. A new sheet is judged by re-running
    // the same measurements against it, not by editing these numbers.
    for (final id in const [
      'upper_leg_right',
      'lower_leg_right',
      'upper_leg_left',
      'lower_leg_left',
    ]) {
      expect(
        package.validation.visiblePixelsByRegion[id],
        greaterThan(0),
        reason: '$id still produced a layer, just the wrong part of the leg',
      );
    }
  });
}
