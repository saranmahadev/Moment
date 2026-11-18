import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/diagnostics/diagnostics_log.dart';
import 'package:path/path.dart' as p;

/// Something a person wrote, which must never reach the log.
const _secret = 'Dear diary, the code is 4711';

void main() {
  late DateTime now;
  late DiagnosticsLog log;

  setUp(() {
    now = DateTime.utc(2026, 11, 18, 9);
    log = DiagnosticsLog(MemoryDiagnosticsStore(), clock: () => now);
  });

  test('records events oldest first, with the time', () async {
    await log.event('launch', '1.0.0');
    now = now.add(const Duration(minutes: 1));
    await log.event('backup.made');
    final entries = await log.entries();
    expect(entries.map((e) => e.name), ['launch', 'backup.made']);
    expect(entries.first.at, DateTime.utc(2026, 11, 18, 9));
    expect(entries.first.detail, '1.0.0');
    expect(entries.first.kind, DiagnosticKind.event);
  });

  test('keeps only the newest entries', () async {
    final small = DiagnosticsLog(MemoryDiagnosticsStore(), capacity: 3);
    for (var i = 0; i < 5; i++) {
      await small.event('e$i');
    }
    expect((await small.entries()).map((e) => e.name), ['e2', 'e3', 'e4']);
  });

  group('errors keep their type and where they happened, never a message', () {
    StackTrace momentStack() => StackTrace.fromString('''
#0      LogRepository.createText (package:moment/data/log_repository.dart:44:7)
#1      _CreateTextScreenState._save (package:moment/text/create_text_screen.dart:120:5)
#2      _rootRun (dart:async/zone_root.dart:35:13)
#3      Something.else (package:drift/src/runtime/api/db_base.dart:73:12)
''');

    for (final error in <Object>[
      ArgumentError.value(_secret, 'body', 'must not be blank'),
      FormatException(_secret),
      StateError(_secret),
      Exception(_secret),
      _secret,
    ]) {
      test('${error.runtimeType}', () async {
        await log.error(error, momentStack());
        final entry = (await log.entries()).single;
        expect(entry.kind, DiagnosticKind.error);
        expect(entry.name, error.runtimeType.toString());
        expect(
          entry.detail,
          'lib/data/log_repository.dart:44 < '
          'lib/text/create_text_screen.dart:120',
        );
        expect(await log.report(), isNot(contains('4711')));
        expect(await log.report(), isNot(contains('diary')));
      });
    }

    test('a stack with nothing of Moment in it says so', () async {
      await log.error(
        StateError('x'),
        StackTrace.fromString('#0 f (package:drift/x.dart:1:1)'),
      );
      expect((await log.entries()).single.detail, 'outside Moment');
    });

    test('a long stack keeps its first six Moment frames', () async {
      final frames = [
        for (var i = 0; i < 9; i++) '#$i f (package:moment/a$i.dart:$i:1)',
      ].join('\n');
      await log.error(StateError('x'), StackTrace.fromString(frames));
      expect((await log.entries()).single.detail.split(' < '), hasLength(6));
    });
  });

  test('the report: a header, then one line per entry', () async {
    await log.event('launch', '1.0.0');
    await log.error(
      StateError('x'),
      StackTrace.fromString('#0 f (package:moment/main.dart:9:1)'),
    );
    final report = await log.report(appVersion: '1.0.0');
    final lines = report.split('\n');
    expect(lines.first, 'Moment 1.0.0 diagnostics');
    expect(
      lines,
      containsAll([
        '2026-11-18 09:00:00Z  event  launch  1.0.0',
        '2026-11-18 09:00:00Z  error  StateError  lib/main.dart:9',
      ]),
    );
  });

  test('clear empties it', () async {
    await log.event('launch');
    await log.clear();
    expect(await log.entries(), isEmpty);
  });

  group('on disk', () {
    late Directory dir;
    late File file;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('diagnostics_');
      file = File(p.join(dir.path, 'diagnostics.jsonl'));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('survives a restart', () async {
      final first = DiagnosticsLog(
        FileDiagnosticsStore(file),
        clock: () => now,
      );
      await first.event('launch', '1.0.0');
      final second = DiagnosticsLog(FileDiagnosticsStore(file));
      expect((await second.entries()).single.name, 'launch');
    });

    test('a damaged file reads as empty, and is replaced', () async {
      file.writeAsStringSync('not json\n{"broken":');
      final reopened = DiagnosticsLog(FileDiagnosticsStore(file));
      expect(await reopened.entries(), isEmpty);
      await reopened.event('launch');
      expect((await reopened.entries()).single.name, 'launch');
    });

    test('clearing removes the text from disk', () async {
      final l = DiagnosticsLog(FileDiagnosticsStore(file));
      await l.event('launch');
      await l.clear();
      expect(file.existsSync() ? file.readAsStringSync().trim() : '', '');
    });
  });
}
