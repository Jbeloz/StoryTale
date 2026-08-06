import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/character_design_brief.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_contract.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_generation.dart';

/// Guards the prompt the provider is actually paid to answer.
///
/// A prompt contract that omits a substitution token does not fail: it ships a
/// request describing no particular character and bills for the result. V3 and
/// V4 were both authored with no tokens at all, so this is a real failure mode
/// rather than a hypothetical one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterSheetContract contract;
  late String template;

  setUpAll(() async {
    contract = await CharacterSheetContractRepository().load();
    template = await rootBundle.loadString(contract.assets.promptContract);
  });

  test('the active prompt contract carries every substitution token', () {
    final fields = _request.promptFields(contract);
    final missing = fields.keys
        .where((token) => !template.contains(token))
        // V1 and V4 name the rear-hair token differently and only one is ever
        // the active contract, so requiring both would be wrong.
        .where((token) => !token.contains('back_hair'))
        .toList();
    expect(
      missing,
      isEmpty,
      reason: '${contract.assets.promptContract} would send these unfilled',
    );
    expect(
      fields.keys.where(template.contains).any(
        (token) => token.contains('back_hair'),
      ),
      isTrue,
      reason: 'the rear-hair selection must reach the provider',
    );
  });

  test('a built prompt leaves no token unresolved and carries the brief', () {
    final prompt = _request.buildPrompt(template, contract);

    expect(
      RegExp(r'\{\{[^}]*\}\}').firstMatch(prompt)?.group(0),
      isNull,
      reason: 'an unresolved token would reach the provider verbatim',
    );
    for (final value in _request.promptFields(contract).values) {
      if (value.isEmpty) continue;
      expect(
        prompt,
        contains(value),
        reason: 'the request must actually describe this character',
      );
    }
    expect(prompt, contains('Kestrel Vane'));
    expect(prompt, contains('#F2C9A0'));
    expect(prompt, contains(_request.selectedBackHairRegion(contract)));
  });

  test('a built prompt fits inside the Worker character-sheet limit', () {
    final prompt = _request.buildPrompt(template, contract);

    expect(
      prompt.length,
      lessThan(_workerMaxPromptLength),
      reason:
          'the Worker rejects a longer character-sheet prompt with a 400, so '
          'growing the contract has to be paid for by trimming it',
    );
  });
}

/// `maxPromptLength` for `mode=character-sheet` in
/// `cloudflare/image-worker/src/index.ts`.
///
/// The contract is a file that only grows, and nothing on this side of the
/// request enforced the cap, so an edit could have shipped a prompt the Worker
/// refuses. That failure is free rather than billed, but it still blocks a
/// request the owner has already approved.
///
/// The margin left over is not spare room: every `{{token}}` is replaced by a
/// value, and `{{character_design_brief}}` is unbounded book text.
const _workerMaxPromptLength = 12000;

const _request = CharacterSheetGenerationRequest(
  brief: CharacterDesignBrief(
    bookId: 'book-test',
    characterId: 'character-test',
    canonicalName: 'Kestrel Vane',
    actorProfileId: 'default',
    sourceDescription: 'A plainly described test character.',
  ),
  skinTone: '#F2C9A0',
  frontHairId: 'front_default',
  backHairId: 'medium',
  outfitRequirements: 'One plain coat, trousers, and boots.',
);
