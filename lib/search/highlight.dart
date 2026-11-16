/// Letters with a mark, and the plain letter the search index files them
/// under. Each maps one character to one character, so positions in the
/// folded text are positions in the original.
const _plain = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ę': 'e',
  'ě': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ō': 'o',
  'ø': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ś': 's',
  'š': 's',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
  'ł': 'l',
  'ď': 'd',
  'ť': 't',
  'ř': 'r',
};

final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// [text] in lower case with marks removed, the same length as [text].
String _fold(String text) {
  final folded = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final lower = text[i].toLowerCase();
    // A few characters grow when lowered; keep those as they are so the
    // positions still line up.
    final one = lower.length == 1 ? lower : text[i];
    folded.write(_plain[one] ?? one);
  }
  return folded.toString();
}

/// Splits [text] into parts, each marked true where it matches a word of
/// [query]. A match is the typed word at the start of a word in the text,
/// whatever its case or accents: the same rule the search itself uses, so
/// what is highlighted is what was found. The parts add up to [text].
List<(String, bool)> highlightParts(String text, String query) {
  if (text.isEmpty) return const [];
  final words = {
    for (final match in _word.allMatches(query)) _fold(match.group(0)!),
  };
  if (words.isEmpty) return [(text, false)];

  final folded = _fold(text);
  final hit = List<bool>.filled(text.length, false);
  for (var i = 0; i < folded.length; i++) {
    final startsWord = i == 0 || !_wordCharacter.hasMatch(text[i - 1]);
    if (!startsWord || !_wordCharacter.hasMatch(text[i])) continue;
    for (final word in words) {
      if (folded.startsWith(word, i)) {
        hit.fillRange(i, i + word.length, true);
      }
    }
  }

  final parts = <(String, bool)>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i == text.length || hit[i] != hit[start]) {
      parts.add((text.substring(start, i), hit[start]));
      start = i;
    }
  }
  return parts;
}
