import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/character_sheet_contract.dart';
import 'package:storytale/src/features/animated_story/data/story_artwork_service.dart';

import 'character_sheet_fixtures.dart';

/// Covers the request/response layer between Flutter and the Worker.
///
/// This layer had no test, and that is how a hardcoded `image/png` survived the
/// move to a JPEG contract: the check still demanded PNG while the error message
/// beside it had been updated to read from the contract, so a correct reply was
/// rejected with "returned image/jpeg; requires image/jpeg". The processor tests
/// could not catch it because they start after this point.
///
/// The Worker is faked. Nothing here reaches the network or a provider.
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

  StoryArtworkService serviceReturning({
    required List<int> bytes,
    required String contentType,
    String? fingerprint,
    void Function(http.BaseRequest request)? onRequest,
  }) {
    return StoryArtworkService(
      token: 'test-token',
      client: MockClient.streaming((request, _) async {
        onRequest?.call(request);
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          headers: {
            'content-type': contentType,
            'x-image-provider': 'google-gemini',
            'x-image-model': 'gemini-3.1-flash-image',
            'x-request-id': 'test-request',
            if (fingerprint != null) 'x-request-fingerprint': fingerprint,
          },
        );
      }),
    );
  }

  test('accepts the JPEG the provider actually returns', () async {
    final request = testRequest(backHairId: 'medium');
    final sheet = fixture.preservedSheet();
    fixture.paintAppearance(sheet, fixture.activeRegionIds(request));
    final bytes = image.encodeJpg(sheet, quality: 95);

    final result = await serviceReturning(
      bytes: bytes,
      contentType: 'image/jpeg',
      fingerprint: request.fingerprint(contract),
    ).generateCharacterSheet(request);

    expect(result.mimeType, contract.canvas.mimeType);
    expect(result.width, contract.canvas.width);
    expect(result.height, contract.canvas.height);
    expect(result.contractId, contract.contractId);
  });

  test('sends the guide variant that matches the requested length', () async {
    // V4 publishes one guide per rear-hair length, and the Worker checks the
    // upload against the hash the request declares. Sending the wrong one is a
    // 409 after the money is committed.
    for (final length in const ['short', 'medium', 'long']) {
      final request = testRequest(backHairId: length);
      final variant = contract.selection.guideFor(length);
      var seenFilenames = <String>[];
      var declaredHash = '';

      final sheet = fixture.preservedSheet();
      await serviceReturning(
        bytes: image.encodeJpg(sheet, quality: 95),
        contentType: 'image/jpeg',
        fingerprint: request.fingerprint(contract),
        onRequest: (raw) {
          final multipart = raw as http.MultipartRequest;
          seenFilenames = multipart.files
              .map((file) => file.filename ?? '')
              .toList();
          declaredHash = multipart.fields['guide_sha256'] ?? '';
        },
      ).generateCharacterSheet(request);

      expect(
        seenFilenames.first,
        variant.path.split('/').last,
        reason: '$length must upload its own guide',
      );
      expect(declaredHash, variant.sha256);
      expect(seenFilenames, hasLength(5));
    }
  });

  test('rejects a reply whose format is not the contract format', () async {
    final request = testRequest(backHairId: 'medium');
    final sheet = fixture.preservedSheet();

    await expectLater(
      serviceReturning(
        bytes: image.encodePng(sheet),
        contentType: 'image/png',
        fingerprint: request.fingerprint(contract),
      ).generateCharacterSheet(request),
      throwsA(
        isA<ArtworkGenerationException>().having(
          (error) => error.message,
          'message',
          contains(contract.canvas.mimeType),
        ),
      ),
    );
  });

  test('rejects a reply that belongs to a different request', () async {
    final request = testRequest(backHairId: 'medium');
    final sheet = fixture.preservedSheet();

    await expectLater(
      serviceReturning(
        bytes: image.encodeJpg(sheet, quality: 95),
        contentType: 'image/jpeg',
        fingerprint: 'a' * 64,
      ).generateCharacterSheet(request),
      throwsA(isA<ArtworkGenerationException>()),
    );
  });
}
