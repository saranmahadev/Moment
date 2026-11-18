import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_check.dart';

const _rules = '''
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="root" path="."/>
        <exclude domain="file" path="."/>
        <exclude domain="database" path="."/>
        <exclude domain="sharedpref" path="."/>
        <exclude domain="external" path="."/>
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" path="."/>
        <exclude domain="file" path="."/>
        <exclude domain="database" path="."/>
        <exclude domain="sharedpref" path="."/>
        <exclude domain="external" path="."/>
    </device-transfer>
</data-extraction-rules>''';

const _manifest =
    '<manifest><application android:allowBackup="false" '
    'android:dataExtractionRules="@xml/data_extraction_rules"></application>'
    '</manifest>';

void main() {
  group('permissions are exactly the expected list', () {
    test('the 0.6.0 release list passes', () {
      expect(permissionProblems(expectedPermissions.toList()), isEmpty);
    });

    test('an extra permission fails, by name', () {
      final problems = permissionProblems([
        ...expectedPermissions,
        'android.permission.CAMERA',
      ]);
      expect(problems.single, contains('android.permission.CAMERA'));
      expect(problems.single, contains('not expected'));
    });

    test('a missing one fails too: a feature lost its permission', () {
      final problems = permissionProblems(
        expectedPermissions.where((p) => !p.endsWith('RECORD_AUDIO')).toList(),
      );
      expect(problems.single, contains('RECORD_AUDIO'));
      expect(problems.single, contains('missing'));
    });
  });

  group('Android backup is off and nothing can be extracted', () {
    test('the app as it is passes', () {
      expect(
        backupProblems(manifestXml: _manifest, extractionRulesXml: _rules),
        isEmpty,
      );
    });

    test('allowBackup on fails', () {
      expect(
        backupProblems(
          manifestXml: _manifest.replaceFirst('"false"', '"true"'),
          extractionRulesXml: _rules,
        ),
        [contains('allowBackup')],
      );
    });

    test('a domain no longer excluded fails', () {
      final rules = _rules.replaceFirst(
        '<exclude domain="database" path="."/>',
        '',
      );
      expect(
        backupProblems(manifestXml: _manifest, extractionRulesXml: rules),
        [allOf(contains('cloud-backup'), contains('database'))],
      );
    });
  });

  group('the encrypted SQLite is in every APK', () {
    final cipher = utf8.encode('...sqlite3mc_version...');

    test('libsqlite3mc with its cipher passes', () {
      expect(
        cipherProblems('moment-1.0.0-arm64-v8a.apk', {
          'lib/arm64-v8a/libsqlite3mc.so': cipher,
          'lib/arm64-v8a/libflutter.so': [1, 2, 3],
        }),
        isEmpty,
      );
    });

    test('no SQLite library at all fails', () {
      expect(
        cipherProblems('a.apk', {
          'lib/arm64-v8a/libflutter.so': [1],
        }),
        [contains('libsqlite3mc.so')],
      );
    });

    test('a SQLite without the cipher fails', () {
      expect(
        cipherProblems('a.apk', {
          'lib/arm64-v8a/libsqlite3mc.so': utf8.encode('plain sqlite'),
        }),
        [contains('cipher')],
      );
    });

    test('a plain SQLite next to it fails', () {
      expect(
        cipherProblems('a.apk', {
          'lib/arm64-v8a/libsqlite3mc.so': cipher,
          'lib/arm64-v8a/libsqlite3.so': [0],
        }),
        [contains('libsqlite3.so')],
      );
    });
  });

  group('signing', () {
    const debug =
        'Signer #1 certificate DN: C=US, O=Android, '
        'CN=Android Debug\nSigner #1 certificate SHA-256 digest: ab';
    const release =
        'Signer #1 certificate DN: CN=Moment\n'
        'Signer #1 certificate SHA-256 digest: cd';

    test('a release key passes', () {
      final r = signingCheck(printCerts: release, version: '1.0.0');
      expect(r.problems, isEmpty);
      expect(r.warnings, isEmpty);
    });

    test('the debug key fails a final release', () {
      final r = signingCheck(printCerts: debug, version: '1.0.0');
      expect(r.problems.single, contains('debug key'));
    });

    test('the debug key only warns on a release candidate', () {
      final r = signingCheck(printCerts: debug, version: '1.0.0-rc.1');
      expect(r.problems, isEmpty);
      expect(r.warnings.single, contains('debug key'));
    });

    test('an unsigned APK fails', () {
      final r = signingCheck(printCerts: '', version: '1.0.0-rc.1');
      expect(r.problems.single, contains('signed'));
    });
  });

  group('the version agrees everywhere', () {
    const pubspec = 'name: moment\nversion: 1.0.0-rc.1+10\n';
    const appInfo = "const appVersion = '1.0.0-rc.1';\n";
    const changelog =
        '# Changelog\n\n## 1.0.0-rc.1 — Release candidate\n\n'
        'Text.\n\n## 0.6.0\n';

    test('when it does, nothing to say', () {
      expect(
        versionProblems(
          version: '1.0.0-rc.1',
          pubspec: pubspec,
          appInfo: appInfo,
          changelog: changelog,
        ),
        isEmpty,
      );
    });

    test('each place that disagrees is named', () {
      final problems = versionProblems(
        version: '1.0.0',
        pubspec: pubspec,
        appInfo: appInfo,
        changelog: changelog,
      );
      expect(problems, [
        contains('pubspec.yaml'),
        contains('app_info.dart'),
        contains('CHANGELOG.md'),
      ]);
    });

    test('a version that is not X.Y.Z or X.Y.Z-rc.N is refused', () {
      expect(
        versionProblems(
          version: '1.0',
          pubspec: pubspec,
          appInfo: appInfo,
          changelog: changelog,
        ).first,
        contains('not a version'),
      );
    });
  });

  group('APK sizes stay inside their budget', () {
    const mb = 1024 * 1024;
    test('0.6.0-sized APKs pass', () {
      expect(
        sizeProblems({
          'moment-1.0.0-arm64-v8a.apk': 32 * mb,
          'moment-1.0.0-armeabi-v7a.apk': 30 * mb,
          'moment-1.0.0-x86_64.apk': 34 * mb,
          'moment-1.0.0.apk': 79 * mb,
        }),
        isEmpty,
      );
    });

    test('one that grows past its budget fails, with both sizes', () {
      expect(sizeProblems({'moment-1.0.0-arm64-v8a.apk': 52 * mb}), [
        allOf(contains('arm64-v8a'), contains('52.0 MB'), contains('40')),
      ]);
    });
  });

  test('isPrerelease tells a candidate from a release', () {
    expect(isPrerelease('1.0.0-rc.1'), isTrue);
    expect(isPrerelease('1.0.0'), isFalse);
  });
}
