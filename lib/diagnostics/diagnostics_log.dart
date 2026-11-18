import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app/app_info.dart' as info;

enum DiagnosticKind { event, error }

/// One line of the diagnostics log.
class DiagnosticEntry {
  const DiagnosticEntry({
    required this.at,
    required this.kind,
    required this.name,
    this.detail = '',
  });

  final DateTime at;
  final DiagnosticKind kind;

  /// An event's fixed name, or an error's type.
  final String name;

  /// For an event, a version or a number; for an error, where in Moment's
  /// code it happened. Never anything a person wrote.
  final String detail;

  Map<String, Object> toJson() => {
    'at': at.toUtc().millisecondsSinceEpoch,
    'kind': kind.name,
    'name': name,
    'detail': detail,
  };

  static DiagnosticEntry fromJson(Map<String, Object?> json) => DiagnosticEntry(
    at: DateTime.fromMillisecondsSinceEpoch(json['at']! as int, isUtc: true),
    kind: DiagnosticKind.values.byName(json['kind']! as String),
    name: json['name']! as String,
    detail: json['detail']! as String,
  );
}

/// Where the log's lines are kept.
abstract interface class DiagnosticsStore {
  Future<List<String>> read();
  Future<void> write(List<String> lines);
}

/// One JSON object per line, in a file in the app's private folder.
class FileDiagnosticsStore implements DiagnosticsStore {
  FileDiagnosticsStore(this._file);
  final File _file;

  @override
  Future<List<String>> read() async {
    if (!await _file.exists()) return const [];
    return (await _file.readAsString())
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<void> write(List<String> lines) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(lines.isEmpty ? '' : '${lines.join('\n')}\n');
  }
}

class MemoryDiagnosticsStore implements DiagnosticsStore {
  List<String> _lines = const [];

  @override
  Future<List<String>> read() async => [..._lines];

  @override
  Future<void> write(List<String> lines) async => _lines = [...lines];
}

/// A small log of what went wrong, kept on the phone so there is
/// something to look at when the app misbehaves. Nothing is sent
/// anywhere: the person can read it, copy it or share it themselves
/// (Settings → Diagnostics).
///
/// It holds no journal content by construction. Events are fixed names
/// with a version or a number. Errors keep only their type and the places
/// in Moment's own code they passed through: never their message, which
/// can quote what was being saved.
class DiagnosticsLog {
  DiagnosticsLog(
    this._store, {
    DateTime Function() clock = DateTime.now,
    this.capacity = 300,
  }) : _clock = clock;

  /// The app's log. In-memory until `main` gives it a file.
  static DiagnosticsLog shared = DiagnosticsLog(MemoryDiagnosticsStore());

  final DiagnosticsStore _store;
  final DateTime Function() _clock;

  /// The most entries kept; the oldest go first.
  final int capacity;

  List<DiagnosticEntry>? _entries;

  /// The last operation still running, if any. Operations run one after
  /// another, in the order they were asked for. Null when idle, so no
  /// future outlives the work it stands for.
  Future<void>? _tail;

  Future<T> _serial<T>(Future<T> Function() task) {
    final previous = _tail;
    final result = previous == null
        ? Future.sync(task)
        : previous.then((_) => task());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_tail, tail)) _tail = null;
    });
    _tail = tail;
    return result;
  }

  Future<List<DiagnosticEntry>> _load() async {
    final loaded = _entries;
    if (loaded != null) return loaded;
    final entries = <DiagnosticEntry>[];
    for (final line in await _store.read()) {
      try {
        entries.add(
          DiagnosticEntry.fromJson(jsonDecode(line) as Map<String, Object?>),
        );
      } on Object {
        // A damaged line is dropped; the rest still count.
      }
    }
    return _entries = entries;
  }

  Future<void> _add(DiagnosticEntry entry) => _serial(() async {
    final entries = await _load();
    entries.add(entry);
    if (entries.length > capacity) {
      entries.removeRange(0, entries.length - capacity);
    }
    await _store.write([for (final e in entries) jsonEncode(e.toJson())]);
  });

  /// Something that happened: a fixed [name], and a version or a number.
  Future<void> event(String name, [String detail = '']) => _add(
    DiagnosticEntry(
      at: _clock().toUtc(),
      kind: DiagnosticKind.event,
      name: name,
      detail: detail,
    ),
  );

  /// Something that went wrong: its type and where, never its message.
  Future<void> error(Object error, StackTrace? stack) => _add(
    DiagnosticEntry(
      at: _clock().toUtc(),
      kind: DiagnosticKind.error,
      name: error.runtimeType.toString(),
      detail: whereInMoment(stack),
    ),
  );

  static final _momentFrame = RegExp(r'package:moment/([^\s:)]+):(\d+)');

  /// The first six places in Moment's own code a stack passed through,
  /// innermost first: `lib/data/log_repository.dart:44 < ...`.
  static String whereInMoment(StackTrace? stack) {
    if (stack == null) return 'no stack';
    final frames = _momentFrame
        .allMatches(stack.toString())
        .map((m) => 'lib/${m[1]}:${m[2]}')
        .take(6)
        .toList();
    return frames.isEmpty ? 'outside Moment' : frames.join(' < ');
  }

  /// The entries, if they have already been read; null until then.
  List<DiagnosticEntry>? get loaded =>
      _entries == null ? null : List.unmodifiable(_entries!);

  Future<List<DiagnosticEntry>> entries() =>
      _serial(() async => List.unmodifiable(await _load()));

  Future<void> clear() => _serial(() async {
    _entries = [];
    await _store.write(const []);
  });

  /// The whole log as text, for copying or sharing.
  Future<String> report({String? appVersion}) async {
    final lines = [
      'Moment ${appVersion ?? info.appVersion} diagnostics',
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      '',
      for (final e in await entries())
        [
          _time(e.at),
          e.kind.name,
          e.name,
          if (e.detail.isNotEmpty) e.detail,
        ].join('  '),
    ];
    return lines.join('\n');
  }

  static String _time(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final u = t.toUtc();
    return '${u.year}-${two(u.month)}-${two(u.day)} '
        '${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }
}
