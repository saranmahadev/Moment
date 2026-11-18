// The release check: run by the Release workflow on the built APKs, before
// anything is tagged. A red check stops the release.
//
//   dart run tool/release_check.dart --version 1.0.0 \
//     --apks <dir with moment-*.apk> \
//     --manifest <merged release AndroidManifest.xml>
//
// It needs `apksigner` (from the Android build tools) on PATH or in
// $APKSIGNER. Every check is a pure function below, tested with planted
// bad input in test/tool/release_check_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'check_manifest.dart';

/// Every permission the release build asks for, and why. A new one is a
/// decision, not an accident: add it here, with its reason, on purpose.
const expectedPermissions = <String>{
  // Pin where you are (Location logs). Never in the background.
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
  // "Look up place names", off unless turned on (see CLAUDE.md).
  'android.permission.INTERNET',
  // The evening reminder: shown, and kept across restarts.
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.RECEIVE_BOOT_COMPLETED',
  'android.permission.VIBRATE',
  // The app lock's fingerprint or face.
  'android.permission.USE_BIOMETRIC',
  'android.permission.USE_FINGERPRINT',
  // Audio logs.
  'android.permission.RECORD_AUDIO',
  // Added by plugins (connectivity of the share sheet, the video player's
  // screen staying on); no data leaves through them.
  'android.permission.ACCESS_NETWORK_STATE',
  'android.permission.WAKE_LOCK',
  // Android's own guard for receivers registered at run time.
  'app.moment.moment.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
};

/// What is wrong with the permissions [found] in the release manifest.
List<String> permissionProblems(List<String> found) {
  final have = found.toSet();
  return [
    for (final p in have.difference(expectedPermissions))
      'permission $p is not expected (add it to expectedPermissions, with '
          'a reason, only if it is meant)',
    for (final p in expectedPermissions.difference(have))
      'permission $p is missing: a feature has lost what it needs',
  ];
}

const _backupDomains = ['root', 'file', 'database', 'sharedpref', 'external'];

/// Android's cloud backup and phone-to-phone copy must be off: the
/// manifest says allowBackup="false", and the extraction rules exclude
/// every domain in both sections.
List<String> backupProblems({
  required String manifestXml,
  required String extractionRulesXml,
}) {
  final problems = <String>[
    if (allowsCloudBackup(manifestXml))
      'android:allowBackup is not "false": Android could copy the journal',
  ];
  for (final section in ['cloud-backup', 'device-transfer']) {
    final body = RegExp(
      '<$section>(.*?)</$section>',
      dotAll: true,
    ).firstMatch(extractionRulesXml)?.group(1);
    if (body == null) {
      problems.add('data extraction rules have no <$section> section');
      continue;
    }
    for (final domain in _backupDomains) {
      final excluded = RegExp(
        '<exclude\\s+domain="$domain"\\s+path="\\."\\s*/>',
      ).hasMatch(body);
      if (!excluded) {
        problems.add('$section does not exclude the "$domain" domain');
      }
    }
  }
  return problems;
}

/// The encrypted SQLite (SQLite3 Multiple Ciphers) must be the one inside
/// [apk], whose native libraries are [libs] (entry name to bytes).
List<String> cipherProblems(String apk, Map<String, List<int>> libs) {
  final problems = <String>[];
  final cipherLibs = libs.keys.where((n) => n.endsWith('/libsqlite3mc.so'));
  if (cipherLibs.isEmpty) {
    problems.add('$apk has no libsqlite3mc.so: the journal would not open');
  }
  final marker = utf8.encode('sqlite3mc_version');
  for (final name in cipherLibs) {
    if (!_contains(libs[name]!, marker)) {
      problems.add('$apk: $name has no cipher in it');
    }
  }
  for (final name in libs.keys) {
    final base = name.split('/').last;
    if (base == 'libsqlite3.so' || base == 'libsqlcipher.so') {
      problems.add('$apk also has $base: only libsqlite3mc.so may be there');
    }
  }
  return problems;
}

bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// 1.0.0-rc.1 and the like.
bool isPrerelease(String version) => version.contains('-');

/// Reads `apksigner verify --print-certs`. The debug key is a problem for
/// a release, and only a warning for a release candidate, which may be
/// built before the owner has made the release key.
({List<String> problems, List<String> warnings}) signingCheck({
  required String printCerts,
  required String version,
}) {
  if (!printCerts.contains('certificate DN:')) {
    return (problems: ['the APK is not signed'], warnings: const <String>[]);
  }
  if (printCerts.contains('CN=Android Debug')) {
    const message =
        'signed with the debug key: it will not install over another '
        'release (see docs/WORKFLOW.md, "Signing the APK")';
    return isPrerelease(version)
        ? (problems: const <String>[], warnings: [message])
        : (problems: [message], warnings: const <String>[]);
  }
  return (problems: const <String>[], warnings: const <String>[]);
}

final _versionShape = RegExp(r'^\d+\.\d+\.\d+(-rc\.\d+)?$');

/// The version asked for must be the one in pubspec.yaml, in
/// lib/app/app_info.dart, and have an entry in CHANGELOG.md.
List<String> versionProblems({
  required String version,
  required String pubspec,
  required String appInfo,
  required String changelog,
}) {
  if (!_versionShape.hasMatch(version)) {
    return ['"$version" is not a version like 1.0.0 or 1.0.0-rc.1'];
  }
  final declared = RegExp(
    r'^version:\s*([^\s+]+)',
    multiLine: true,
  ).firstMatch(pubspec)?.group(1);
  final inApp = RegExp(
    r"appVersion\s*=\s*'([^']+)'",
  ).firstMatch(appInfo)?.group(1);
  final logged = RegExp(
    '^## ${RegExp.escape(version)}( |\$)',
    multiLine: true,
  ).hasMatch(changelog);
  return [
    if (declared != version) 'pubspec.yaml says $declared, not $version',
    if (inApp != version) 'lib/app/app_info.dart says $inApp, not $version',
    if (!logged) 'CHANGELOG.md has no "## $version" entry',
  ];
}

const _mb = 1024 * 1024;

/// Most an APK may weigh, by its name's ending. About a quarter above
/// 0.6.0's sizes: room to grow, not to double.
const sizeBudgetMb = {
  '-arm64-v8a.apk': 40,
  '-armeabi-v7a.apk': 40,
  '-x86_64.apk': 44,
  '.apk': 100,
};

List<String> sizeProblems(Map<String, int> bytesByApk) => [
  for (final MapEntry(key: apk, value: bytes) in bytesByApk.entries)
    if (_budgetFor(apk) case final budget when bytes > budget * _mb)
      '$apk is ${(bytes / _mb).toStringAsFixed(1)} MB, over its $budget MB '
          'budget',
];

int _budgetFor(String apk) =>
    sizeBudgetMb.entries.firstWhere((e) => apk.endsWith(e.key)).value;

Future<void> main(List<String> args) async {
  String option(String name) {
    final i = args.indexOf('--$name');
    if (i < 0 || i + 1 >= args.length) {
      stderr.writeln('release_check: --$name is required');
      exit(2);
    }
    return args[i + 1];
  }

  final version = option('version');
  final apkDir = Directory(option('apks'));
  final manifest = File(option('manifest')).readAsStringSync();
  final problems = <String>[];
  final warnings = <String>[];

  problems
    ..addAll(
      versionProblems(
        version: version,
        pubspec: File('pubspec.yaml').readAsStringSync(),
        appInfo: File('lib/app/app_info.dart').readAsStringSync(),
        changelog: File('CHANGELOG.md').readAsStringSync(),
      ),
    )
    ..addAll(permissionProblems(listPermissions(manifest)))
    ..addAll(
      backupProblems(
        manifestXml: manifest,
        extractionRulesXml: File(
          'android/app/src/main/res/xml/data_extraction_rules.xml',
        ).readAsStringSync(),
      ),
    );

  final apks =
      apkDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.apk'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (apks.isEmpty) problems.add('no APKs in ${apkDir.path}');
  final apksigner = Platform.environment['APKSIGNER'] ?? 'apksigner';
  for (final apk in apks) {
    final name = apk.uri.pathSegments.last;
    final archive = ZipDecoder().decodeBytes(apk.readAsBytesSync());
    problems.addAll(
      cipherProblems(name, {
        for (final file in archive.files)
          if (file.isFile && file.name.endsWith('.so')) file.name: file.content,
      }),
    );
    final certs = await Process.run(apksigner, [
      'verify',
      '--print-certs',
      apk.path,
    ]);
    final signing = signingCheck(
      printCerts: '${certs.stdout}',
      version: version,
    );
    problems.addAll(signing.problems.map((p) => '$name: $p'));
    warnings.addAll(signing.warnings.map((w) => '$name: $w'));
  }
  problems.addAll(
    sizeProblems({
      for (final apk in apks) apk.uri.pathSegments.last: apk.lengthSync(),
    }),
  );

  stdout.writeln('Release check for $version: ${apks.length} APKs.');
  for (final w in warnings) {
    stdout.writeln('::warning::$w');
  }
  if (problems.isEmpty) {
    stdout.writeln('Every release check passed.');
    return;
  }
  for (final p in problems) {
    stdout.writeln('::error::$p');
  }
  exit(1);
}
