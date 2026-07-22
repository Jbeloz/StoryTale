import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/subtitle_beat_splitter.dart';

void main() {
  test('subtitle beats stay short without losing source words', () {
    const source =
        'Once upon a time, there was a little prince who lived on a small '
        'planet. He loved watching the sunset.';

    final beats = splitSubtitleBeats(source);

    expect(beats.every((beat) => beat.split(' ').length <= 8), isTrue);
    expect(beats.join(' '), source);
  });
}
