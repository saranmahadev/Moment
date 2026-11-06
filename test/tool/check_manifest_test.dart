import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/check_manifest.dart';

void main() {
  group('findForbiddenPermissions', () {
    test('finds android.permission.INTERNET', () {
      const manifest = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="app.moment.moment">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:label="moment" />
</manifest>
''';
      expect(findForbiddenPermissions(manifest), [
        'android.permission.INTERNET',
      ]);
    });

    test('returns nothing for a manifest without forbidden permissions', () {
      const manifest = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="app.moment.moment">
    <uses-permission android:name="android.permission.CAMERA"/>
    <application android:label="moment" />
</manifest>
''';
      expect(findForbiddenPermissions(manifest), isEmpty);
    });

    test('returns nothing for a manifest with no permissions at all', () {
      const manifest = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="app.moment.moment">
    <application android:label="moment"/>
</manifest>
''';
      expect(findForbiddenPermissions(manifest), isEmpty);
    });

    test('is tolerant of attributes split across lines', () {
      const manifest = '''
<manifest>
  <uses-permission
      android:name="android.permission.INTERNET" />
</manifest>
''';
      expect(findForbiddenPermissions(manifest), [
        'android.permission.INTERNET',
      ]);
    });

    test('reports every forbidden permission it finds, in order', () {
      const manifest = '''
<manifest>
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.INTERNET"/>
</manifest>
''';
      expect(findForbiddenPermissions(manifest), [
        'android.permission.INTERNET',
      ]);
    });
  });

  group('findAndroidManifests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('manifest-check-test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('finds a single manifest file passed directly', () {
      final file = File(p.join(tempDir.path, 'AndroidManifest.xml'))
        ..writeAsStringSync('<manifest/>');

      final found = findAndroidManifests(file.path);
      expect(found.map((f) => f.path), [file.path]);
    });

    test('recursively finds manifests nested in a directory tree', () {
      final nested = Directory(p.join(tempDir.path, 'a', 'b'))
        ..createSync(recursive: true);
      final manifest1 = File(p.join(tempDir.path, 'AndroidManifest.xml'))
        ..writeAsStringSync('<manifest/>');
      final manifest2 = File(p.join(nested.path, 'AndroidManifest.xml'))
        ..writeAsStringSync('<manifest/>');
      File(p.join(tempDir.path, 'other.xml')).writeAsStringSync('<x/>');

      final found = findAndroidManifests(
        tempDir.path,
      ).map((f) => f.path).toSet();
      expect(found, {manifest1.path, manifest2.path});
    });

    test('returns nothing for a directory with no manifests', () {
      expect(findAndroidManifests(tempDir.path), isEmpty);
    });

    test('raises for a path that does not exist', () {
      expect(
        () => findAndroidManifests(p.join(tempDir.path, 'missing')),
        throwsArgumentError,
      );
    });
  });

  group('checkManifests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('manifest-check-test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reports no violations when every manifest is clean', () {
      File(p.join(tempDir.path, 'AndroidManifest.xml')).writeAsStringSync('''
<manifest><uses-permission android:name="android.permission.CAMERA"/></manifest>
''');

      expect(checkManifests(tempDir.path), isEmpty);
    });

    test('reports a violation with the offending file path', () {
      final manifest = File(p.join(tempDir.path, 'AndroidManifest.xml'))
        ..writeAsStringSync('''
<manifest><uses-permission android:name="android.permission.INTERNET"/></manifest>
''');

      final violations = checkManifests(tempDir.path);
      expect(violations, hasLength(1));
      expect(violations.single.file, manifest.path);
      expect(violations.single.permissions, ['android.permission.INTERNET']);
    });
  });

  group('run', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('manifest-check-test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns 0 for a clean tree', () {
      File(p.join(tempDir.path, 'AndroidManifest.xml')).writeAsStringSync('''
<manifest><uses-permission android:name="android.permission.CAMERA"/></manifest>
''');

      expect(run([tempDir.path]), 0);
    });

    test('returns 1 when a manifest declares a forbidden permission', () {
      File(p.join(tempDir.path, 'AndroidManifest.xml')).writeAsStringSync('''
<manifest><uses-permission android:name="android.permission.INTERNET"/></manifest>
''');

      expect(run([tempDir.path]), 1);
    });

    test('returns 2 when no path is given', () {
      expect(run(const []), 2);
    });
  });
}
