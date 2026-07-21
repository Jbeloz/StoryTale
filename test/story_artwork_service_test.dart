import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storytale/src/features/animated_story/data/story_artwork_service.dart';

void main() {
  test('requests a Cloudflare background', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['kind'], 'background');
      expect(request.headers['authorization'], 'Bearer test-token');
      final body = String.fromCharCodes(request.bodyBytes);
      expect(body, contains('moonlit rose garden'));
      expect(body, contains('No people, characters'));
      return http.Response.bytes([1, 2, 3], 200);
    });
    final service = StoryArtworkService(
      client: client,
      endpoint: 'https://example.com',
      token: 'test-token',
    );

    final result = await service.generateBackground('a moonlit rose garden');

    expect(result, Uint8List.fromList([1, 2, 3]));
    client.close();
  });

  test('requests a Gemini sprite with bundled references', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['kind'], 'sprite');
      expect(request.url.queryParameters.containsKey('part'), isFalse);
      final body = String.fromCharCodes(request.bodyBytes);
      expect(body, contains('young prince with golden hair'));
      expect(body, contains('full-proportion.png'));
      expect(body, contains('approved-head.png'));
      expect(body, contains('approved-body.png'));
      return http.Response.bytes([4, 5, 6], 200);
    });
    final service = StoryArtworkService(
      client: client,
      bundle: _FakeBundle(),
      endpoint: 'https://example.com',
      token: 'test-token',
    );

    final result = await service.generateSpriteMaster(
      'young prince with golden hair',
    );

    expect(result, Uint8List.fromList([4, 5, 6]));
    client.close();
  });

  test('explains when the local token is missing', () async {
    final service = StoryArtworkService(
      client: MockClient((_) async => http.Response('', 500)),
      token: '',
    );

    expect(
      () => service.generateBackground('a forest'),
      throwsA(
        isA<ArtworkGenerationException>().having(
          (error) => error.message,
          'message',
          contains('CLOUDFLARE_IMAGE_TOKEN'),
        ),
      ),
    );
  });
}

class _FakeBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
  }
}
