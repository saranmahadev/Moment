import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The privacy policy a store listing links to (site/privacy.html), in the
/// words of the app's own Privacy and About screens.
void main() {
  final page = File('site/privacy.html');
  final html = page.existsSync() ? page.readAsStringSync() : '';
  final text = html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  test('exists, and the site links to it', () {
    expect(page.existsSync(), isTrue);
    expect(html, contains('<title>'));
    expect(
      File('site/index.html').readAsStringSync(),
      contains('privacy.html'),
    );
  });

  test('loads nothing from another server', () {
    final fetched = RegExp(
      r'''(?:src|href)\s*=\s*"(//|https?:)[^"]*"''',
    ).allMatches(html).map((m) => m.group(0)!);
    // Links a person may follow are fine; nothing is fetched by itself.
    expect(fetched.where((attr) => attr.startsWith('src')), isEmpty);
    expect(html, isNot(contains('<link rel="stylesheet" href="http')));
  });

  test('says what leaves the phone, to whom, and when', () {
    expect(text, contains('Look up place names'));
    expect(text, contains('OpenStreetMap'));
    expect(text, contains('off'));
    expect(text, contains('coordinates'));
  });

  test('says what is never collected', () {
    for (final phrase in ['no account', 'no analytics', 'no advertising']) {
      expect(text.toLowerCase(), contains(phrase), reason: phrase);
    }
  });

  test('covers diagnostics, backups and the widget', () {
    expect(text, contains('Diagnostics'));
    expect(text, contains('passphrase'));
    expect(text, contains('widget'));
  });
}
