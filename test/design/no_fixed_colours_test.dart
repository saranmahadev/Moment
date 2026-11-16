import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A colour written straight into a screen cannot follow the theme: white
/// text on an ink button turns invisible when ink becomes light. Colours
/// come from `MomentTokens`; the few fixed ones are listed here with why.
void main() {
  const allowed = {
    // The palettes themselves.
    'lib/design/tokens.dart',
    // Glass is a white film over the blur in both palettes.
    'lib/design/glass_surface.dart',
    // A video plays on black, and its scrubber thumb is white, whatever
    // the theme.
    'lib/video/video_detail_screen.dart',
  };

  test('screens take their colours from the tokens', () {
    final fixed = RegExp(
      r'Colors\.(white|black)\b|Color\(0x|Color\.fromRGBO\(|Color\.fromARGB\(',
    );
    final offenders = <String>[];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final file in sources) {
      if (allowed.contains(file.path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (fixed.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
      }
    }

    expect(offenders, isEmpty);
  });

  test('the app is themed from the settings, not a fixed theme', () {
    final app = File('lib/app/moment_app.dart').readAsStringSync();

    expect(app, contains('ThemedApp('));
    expect(app, isNot(contains('MaterialApp(')));
  });
}
