import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What is typed into the journal is not for the keyboard's cloud either:
/// Android keyboards can learn from, and sync, what they see. Every text
/// field asks the keyboard not to personalise from it.
void main() {
  test('every text field switches off keyboard learning', () {
    final field = RegExp(r'(?<![A-Za-z_])TextField\(');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in field.allMatches(source)) {
        // The call's own arguments: up to the first line that closes it at
        // the same depth.
        var depth = 0;
        var end = match.end - 1;
        for (; end < source.length; end++) {
          if (source[end] == '(') depth++;
          if (source[end] == ')' && --depth == 0) break;
        }
        final call = source.substring(match.start, end);
        if (!call.contains('enableIMEPersonalizedLearning: false')) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
