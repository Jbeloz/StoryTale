import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as image;

/// Builds the local fixture garment used to prove the V5 clothing layer without
/// a provider. Deliberately simple and obviously not generated art: a coloured
/// tunic shape with a darker outline, transparent everywhere else.
void main() {
  const width = 256;
  const height = 256;
  final canvas = image.Image(width, height)
    ..channels = image.Channels.rgba;
  image.fill(canvas, image.getColor(0, 0, 0, 0));

  final body = image.getColor(58, 92, 168, 255);
  final trim = image.getColor(232, 196, 92, 255);
  final outline = image.getColor(18, 28, 56, 255);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final t = y / (height - 1);
      // A tunic: narrow at the shoulders, flaring toward the hem.
      final halfWidth = (width * (0.30 + 0.16 * t)).round();
      final centre = width ~/ 2;
      final left = centre - halfWidth;
      final right = centre + halfWidth;
      if (x < left || x > right) continue;
      if (y < height * 0.06) continue;
      final edge = x <= left + 5 || x >= right - 5 ||
          y <= height * 0.06 + 5 || y >= height - 6;
      final band = (t - 0.72).abs() < 0.045;
      canvas.setPixel(x, y, edge ? outline : band ? trim : body);
    }
  }
  // A collar opening so the neck seam stays visible when it sits on a torso.
  final neckRadius = (width * 0.13).round();
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final dx = x - width / 2;
      final dy = y - height * 0.09;
      if (math.sqrt(dx * dx + dy * dy) <= neckRadius) {
        canvas.setPixel(x, y, image.getColor(0, 0, 0, 0));
      }
    }
  }
  File('assets/images/characters/garment_fixtures/tunic_fixture.png')
      .writeAsBytesSync(image.encodePng(canvas));
  stdout.writeln('wrote tunic_fixture.png');
}
