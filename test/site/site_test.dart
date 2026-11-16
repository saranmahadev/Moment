import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The project's site (site/, published to GitHub Pages) keeps the app's
/// own promise: it loads nothing from anyone else's server. Fonts, images
/// and the film are all in the repository; the only outside addresses are
/// links a person chooses to follow.
void main() {
  final page = File('site/index.html');
  final html = page.existsSync() ? page.readAsStringSync() : '';

  /// Every address the page would fetch by itself: src, srcset, poster,
  /// stylesheet and icon links, and url(...) in its styles.
  Iterable<String> loaded() sync* {
    for (final match in RegExp(
      r'''(?:src|poster)\s*=\s*"([^"]+)"''',
    ).allMatches(html)) {
      yield match.group(1)!;
    }
    for (final match in RegExp(r'srcset\s*=\s*"([^"]+)"').allMatches(html)) {
      for (final candidate in match.group(1)!.split(',')) {
        yield candidate.trim().split(RegExp(r'\s+')).first;
      }
    }
    for (final match in RegExp(
      r'''<link[^>]+href\s*=\s*"([^"]+)"''',
    ).allMatches(html)) {
      yield match.group(1)!;
    }
    for (final match in RegExp(
      r'''url\(\s*["']?([^"')]+)["']?\s*\)''',
    ).allMatches(html)) {
      yield match.group(1)!;
    }
  }

  test('the site exists, with a title and a description', () {
    expect(page.existsSync(), isTrue);
    expect(html, contains('<title>'));
    expect(html, contains('name="description"'));
    expect(html, contains('name="viewport"'));
  });

  test('it loads nothing from another server', () {
    final outside = loaded().where((url) => url.contains('//')).toList();

    expect(outside, isEmpty);
    expect(html, isNot(contains('<script src="http')));
  });

  test('every file it loads is in the repository', () {
    final missing = [
      for (final url in loaded().toSet())
        if (!url.startsWith('data:') &&
            !url.startsWith('#') &&
            !File('site/${url.split('#').first.split('?').first}').existsSync())
          url,
    ];

    expect(loaded(), isNotEmpty);
    expect(missing, isEmpty);
  });

  test('it links to the source, the releases and the licence', () {
    expect(html, contains('https://github.com/saranmahadev/Moment'));
    expect(html, contains('/releases/latest'));
    expect(html, contains('GPL-3.0'));
  });

  test('it is honest about the one thing that uses the internet', () {
    expect(html, contains('Look up place names'));
    expect(html, isNot(contains('no internet permission')));
  });

  test('a workflow publishes the site to GitHub Pages', () {
    final workflow = File('.github/workflows/pages.yml').readAsStringSync();

    expect(workflow, contains('actions/deploy-pages'));
    expect(workflow, contains('path: site'));
  });
}
