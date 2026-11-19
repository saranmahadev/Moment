import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/licences.dart';

/// What Moment ships that others made, credited in the app's licence page
/// as their licences ask.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every bundled work is credited, with its licence', () async {
    registerAppLicences();
    final entries = await LicenseRegistry.licenses.toList();
    String textOf(String package) => entries
        .where((e) => e.packages.contains(package))
        .expand((e) => e.paragraphs)
        .map((p) => p.text)
        .join('\n');

    for (final font in ['Inter', 'Newsreader']) {
      final text = textOf(font);
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'), reason: font);
      expect(text, contains('Copyright'), reason: font);
    }
    expect(textOf('Natural Earth'), contains('public domain'));
    expect(textOf('OpenStreetMap'), contains('Open Database License'));
  });
}
