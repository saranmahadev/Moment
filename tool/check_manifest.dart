import 'dart:io';

/// Permissions Moment must never ask for, whichever plugin tries to add
/// them: a private journal has no business with any of these.
///
/// The internet permission is not here: the opt-in "Look up place names"
/// needs it. What keeps the app to that one use is
/// `test/location/network_boundary_test.dart`.
const forbiddenPermissions = <String>{
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  'com.google.android.gms.permission.AD_ID',
  'android.permission.READ_CONTACTS',
  'android.permission.READ_SMS',
  'android.permission.READ_CALL_LOG',
};

final _usesPermissionName = RegExp(
  r'<uses-permission\s+android:name="([^"]+)"\s*/?>',
  dotAll: true,
);

/// Returns the forbidden permissions declared in [manifestXml], in the
/// order they appear. Empty when the manifest is clean.
List<String> findForbiddenPermissions(String manifestXml) {
  return _usesPermissionName
      .allMatches(manifestXml)
      .map((match) => match.group(1)!)
      .where(forbiddenPermissions.contains)
      .toList();
}

/// Whether the app in [manifestXml] lets Android copy its files to the
/// cloud or another phone. Android does, unless `android:allowBackup` is
/// `"false"`. A manifest with no `<application>` (a library's) says nothing.
bool allowsCloudBackup(String manifestXml) {
  final application = RegExp(
    r'<application\b[^>]*>?',
    dotAll: true,
  ).firstMatch(manifestXml);
  if (application == null) return false;
  return !RegExp(
    r'android:allowBackup\s*=\s*"false"',
  ).hasMatch(application.group(0)!);
}

/// Every permission [manifestXml] asks for, once each, in order of first
/// appearance.
List<String> listPermissions(String manifestXml) {
  return _usesPermissionName
      .allMatches(manifestXml)
      .map((match) => match.group(1)!)
      .toSet()
      .toList();
}

/// Recursively finds every `AndroidManifest.xml` under [path], or returns
/// [path] itself if it already names a manifest file.
List<File> findAndroidManifests(String path) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.notFound) {
    throw ArgumentError('No such file or directory: $path');
  }
  if (type == FileSystemEntityType.file) {
    return [File(path)];
  }
  return Directory(path)
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.uri.pathSegments.last == 'AndroidManifest.xml')
      .toList();
}

/// One manifest found to declare a forbidden permission.
class ManifestViolation {
  final String file;
  final List<String> permissions;

  ManifestViolation(this.file, this.permissions);
}

/// Checks every `AndroidManifest.xml` under [path] and returns the
/// violations found, if any.
List<ManifestViolation> checkManifests(String path) {
  final violations = <ManifestViolation>[];
  for (final manifest in findAndroidManifests(path)) {
    final xml = manifest.readAsStringSync();
    final forbidden = [
      ...findForbiddenPermissions(xml),
      if (allowsCloudBackup(xml)) 'android:allowBackup is not "false"',
    ];
    if (forbidden.isNotEmpty) {
      violations.add(ManifestViolation(manifest.path, forbidden));
    }
  }
  return violations;
}

/// Runs the check against the path in [args] and returns the process exit
/// code: 0 if clean, 1 if a manifest declares a forbidden permission, 2 if
/// no path was given.
int run(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/check_manifest.dart <file-or-directory>',
    );
    return 2;
  }

  // Print what the build asks for, so every CI run records it.
  for (final manifest in findAndroidManifests(args.first)) {
    stdout.writeln('${manifest.path} asks for:');
    for (final permission in listPermissions(manifest.readAsStringSync())) {
      stdout.writeln('  $permission');
    }
  }

  final violations = checkManifests(args.first);
  if (violations.isEmpty) {
    stdout.writeln('check_manifest: no forbidden permissions found.');
    return 0;
  }

  for (final violation in violations) {
    stderr.writeln(
      '${violation.file}: forbidden permission(s) '
      '${violation.permissions.join(', ')}',
    );
  }
  return 1;
}

void main(List<String> args) {
  exitCode = run(args);
}
