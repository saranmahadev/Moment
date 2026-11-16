import 'package:flutter_test/flutter_test.dart';
import 'package:moment/search/highlight.dart';

void main() {
  List<String> marked(String text, String query) => [
    for (final (part, hit) in highlightParts(text, query))
      hit ? '[$part]' : part,
  ];

  test('marks the word that was searched for, keeping its own case', () {
    expect(marked('Morning light on the Balcony.', 'balcony'), [
      'Morning light on the ',
      '[Balcony]',
      '.',
    ]);
  });

  test('marks only the typed start of a longer word', () {
    expect(marked('On the balcony', 'balc'), ['On the ', '[balc]', 'ony']);
  });

  test('does not mark the middle of a word', () {
    expect(marked('The falcony thing', 'cony'), ['The falcony thing']);
  });

  test('marks every word of the search, wherever each appears', () {
    expect(marked('light on the balcony, more light', 'balcony light'), [
      '[light]',
      ' on the ',
      '[balcony]',
      ', more ',
      '[light]',
    ]);
  });

  test('sees through accents, as the search does', () {
    expect(marked('Café by the río', 'cafe rio'), [
      '[Café]',
      ' by the ',
      '[río]',
    ]);
  });

  test('nothing to mark gives the text back whole', () {
    expect(marked('Just words', ''), ['Just words']);
    expect(marked('Just words', '***'), ['Just words']);
    expect(marked('Just words', 'zebra'), ['Just words']);
    expect(marked('', 'zebra'), isEmpty);
  });

  test('the parts always add up to the text', () {
    const text = 'Balcony, balcony; BALCONY! and the bal';
    final parts = highlightParts(text, 'bal');

    expect(parts.map((p) => p.$1).join(), text);
    expect(parts.where((p) => p.$2), hasLength(4));
  });
}
