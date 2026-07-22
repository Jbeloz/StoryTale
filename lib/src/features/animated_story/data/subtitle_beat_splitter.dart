List<String> splitSubtitleBeats(String source, {int maxWords = 8}) {
  final words = source.trim().split(RegExp(r'\s+'));
  if (words.length == 1 && words.first.isEmpty) return const [];

  final beats = <String>[];
  var current = <String>[];
  for (final word in words) {
    current.add(word);
    final naturalEnd = RegExp(r'[.!?]["”’]?$').hasMatch(word);
    if (naturalEnd || current.length >= maxWords) {
      beats.add(current.join(' '));
      current = <String>[];
    }
  }
  if (current.isNotEmpty) beats.add(current.join(' '));
  return beats;
}
