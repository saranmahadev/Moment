import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The files an open-source project is expected to have, and that the
/// README points to them.
void main() {
  String read(String path) => File(path).readAsStringSync();

  for (final path in [
    'LICENSE',
    'README.md',
    'CHANGELOG.md',
    'CONTRIBUTING.md',
    'CODE_OF_CONDUCT.md',
    'SECURITY.md',
    'SUPPORT.md',
    'docs/ARCHITECTURE.md',
    'assets/fonts/OFL.txt',
    '.github/CODEOWNERS',
    '.github/dependabot.yml',
    '.github/pull_request_template.md',
    '.github/ISSUE_TEMPLATE/bug_report.yml',
    '.github/ISSUE_TEMPLATE/feature_request.yml',
    '.github/ISSUE_TEMPLATE/config.yml',
  ]) {
    test('$path exists and says something', () {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(read(path).trim().length, greaterThan(80), reason: path);
    });
  }

  test('the README links to each of them', () {
    final readme = read('README.md');
    for (final link in [
      'CONTRIBUTING.md',
      'CODE_OF_CONDUCT.md',
      'SECURITY.md',
      'SUPPORT.md',
      'CHANGELOG.md',
      'docs/ARCHITECTURE.md',
      'LICENSE',
    ]) {
      expect(readme, contains('($link)'), reason: link);
    }
  });

  test('the licence is the GPL, version 3', () {
    expect(read('LICENSE'), contains('GNU GENERAL PUBLIC LICENSE'));
    expect(read('LICENSE'), contains('Version 3, 29 June 2007'));
  });

  test(
    'a bug report asks what is needed to act on it, and nothing private',
    () {
      final form = read('.github/ISSUE_TEMPLATE/bug_report.yml');
      for (final field in ['version', 'phone', 'steps', 'expected']) {
        expect(form.toLowerCase(), contains(field), reason: field);
      }
      expect(form.toLowerCase(), contains('do not paste'));
    },
  );

  test('security reports go privately, not to issues', () {
    final config = read('.github/ISSUE_TEMPLATE/config.yml');
    expect(config, contains('blank_issues_enabled: false'));
    expect(config, contains('security/advisories/new'));
  });

  test('the pull request template asks for the test-first gate', () {
    final template = read('.github/pull_request_template.md');
    expect(template, contains('flutter test'));
    expect(template, contains('failing test'));
  });

  test('every bundled font licence ships with the fonts', () {
    expect(read('assets/fonts/OFL.txt'), contains('SIL OPEN FONT LICENSE'));
    expect(read('pubspec.yaml'), contains('assets/fonts/OFL.txt'));
  });
}
