import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:storytale/src/features/animated_story/data/story_artwork_service.dart';
import 'package:storytale/src/features/animated_story/data/visual_novel_background_brief.dart';

void main() {
  test('requests a Cloudflare background', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['kind'], 'background');
      expect(request.headers['authorization'], 'Bearer test-token');
      final body = String.fromCharCodes(request.bodyBytes);
      expect(body, contains('moonlit rose garden'));
      expect(body, contains('left, center, and right'));
      expect(body, contains('floating islands'));
      return http.Response.bytes(
        image.encodePng(image.Image(1024, 576)),
        200,
        headers: {'content-type': 'image/png'},
      );
    });
    final service = StoryArtworkService(
      client: client,
      endpoint: 'https://example.com',
      token: 'test-token',
    );

    final result = await service.generateBackground(
      _brief('a moonlit rose garden'),
    );

    expect(result.width, 1024);
    expect(result.height, 576);
    expect(result.mimeType, 'image/png');
    client.close();
  });

  test('rejects a background with the wrong dimensions', () async {
    final client = MockClient((_) async {
      return http.Response.bytes(
        image.encodePng(image.Image(512, 512)),
        200,
        headers: {'content-type': 'image/png'},
      );
    });
    final service = StoryArtworkService(
      client: client,
      endpoint: 'https://example.com',
      token: 'test-token',
    );

    expect(
      () => service.generateBackground(_brief('a forest')),
      throwsA(
        isA<ArtworkGenerationException>().having(
          (error) => error.message,
          'message',
          contains('requires exactly 1024x576'),
        ),
      ),
    );
    client.close();
  });

  test('requests a Gemini sprite with bundled references', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['kind'], 'sprite');
      expect(request.url.queryParameters.containsKey('part'), isFalse);
      final body = String.fromCharCodes(request.bodyBytes);
      expect(body, contains('young prince with golden hair'));
      expect(body, contains('full-proportion.png'));
      expect(body, contains('head-shape.png'));
      expect(body, contains('body-shape.png'));
      expect(body, contains('torso.png'));
      return http.Response.bytes(
        [4, 5, 6],
        200,
        headers: {'content-type': 'image/jpeg'},
      );
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
      () => service.generateBackground(_brief('a forest')),
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

VisualNovelBackgroundBrief _brief(String sourceBrief) {
  return VisualNovelBackgroundBrief.fromApprovedLocation(
    locationId: 'garden',
    stateId: 'night',
    place: 'Rose garden',
    sourceBrief: sourceBrief,
  );
}

class _FakeBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
  }
}
