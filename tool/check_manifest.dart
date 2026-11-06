import 'dart:io';

/// Permissions Moment must never declare: it makes no network calls.
const forbiddenPermissions = <String>{'android.permission.INTERNET'};

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
    final forbidden = findForbiddenPermissions(manifest.readAsStringSync());
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
