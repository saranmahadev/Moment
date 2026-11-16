import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A control written as `Semantics(button: true, label: …,
/// excludeSemantics: true, child: GestureDetector(onTap: …))` looks right
/// but is not: excluding the child's semantics also hides its tap, so a
/// screen reader announces a button it cannot press. Such a `Semantics`
/// must carry the tap itself.
void main() {
  test('a labelled button that hides its child still exposes its tap', () {
    final offenders = <String>[];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].trimRight().endsWith('Semantics(')) continue;
        // The widget's own arguments: the lines one level in, up to child.
        final indent = RegExp(r'^\s*').stringMatch(lines[i + 1])!;
        final arguments = <String>[];
        for (var j = i + 1; j < lines.length; j++) {
          if (!lines[j].startsWith(indent)) break;
          if (lines[j].startsWith('${indent}child:')) break;
          if (!lines[j].startsWith('$indent ')) arguments.add(lines[j].trim());
        }
        final hides = arguments.any(
          (a) => a.startsWith('excludeSemantics: true'),
        );
        final isButton = arguments.any((a) => a.startsWith('button: true'));
        final hasTap = arguments.any((a) => a.startsWith('onTap:'));
        if (hides && isButton && !hasTap) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
