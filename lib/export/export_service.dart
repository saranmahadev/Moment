import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../data/log_repository.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';

final _fileDate = DateFormat('yyyy-MM-dd');
final _heading = DateFormat('EEE d MMM yyyy · HH:mm');

/// Writes a readable copy of the chosen types: for each, `<type>.json`,
/// `<type>.md`, and for photo and audio the original files, in one zip.
/// Unlike a backup it is not encrypted and is not meant to be restored.
/// Logs in Trash are left out.
class ExportService {
  ExportService({
    required LogRepository repository,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _clock = clock;

  final LogRepository _repository;
  final DateTime Function() _clock;

  Future<File> exportTo(
    Directory directory, {
    required Set<LogType> types,
  }) async {
    if (types.isEmpty) {
      throw ArgumentError.value(types, 'types', 'must not be empty');
    }
    final unbuilt = types.where((t) => !builtLogTypes.contains(t));
    if (unbuilt.isNotEmpty) {
      throw ArgumentError.value(
        types,
        'types',
        '${unbuilt.first} is not built',
      );
    }

    await directory.create(recursive: true);
    final file = File(
      p.join(directory.path, 'Moment export ${_fileDate.format(_clock())}.zip'),
    );
    final zip = ZipFileEncoder()..create(file.path);
    try {
      for (final type in builtLogTypes.where(types.contains)) {
        final logs = await _repository.watchFeed(types: {type}).first;
        final name = type.name;
        _addText(zip, '$name/$name.json', _json(logs));
        _addText(zip, '$name/$name.md', _markdown(type, logs));
        for (final log in logs) {
          final path = _originalFile(log);
          if (path != null && await File(path).exists()) {
            await zip.addFile(File(path), '$name/files/${p.basename(path)}');
          }
        }
      }
    } finally {
      zip.closeSync();
    }
    return file;
  }

  void _addText(ZipFileEncoder zip, String name, String text) {
    final bytes = utf8.encode(text);
    zip.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
  }

  String? _originalFile(Log log) => switch (log) {
    PhotoLog() => log.path,
    AudioLog() => log.path,
    _ => null,
  };

  String _json(List<Log> logs) {
    final rows = [
      for (final log in logs)
        {
          'id': log.id,
          'createdAt': log.createdAt.toUtc().toIso8601String(),
          'tzOffsetMinutes': log.tzOffsetMinutes,
          'editedAt': log.editedAt?.toUtc().toIso8601String(),
          ...switch (log) {
            TextLog() => {'body': log.body},
            EmojiLog() => {
              'emoji': log.emoji,
              'label': log.label,
              'strength': log.strength,
            },
            PhotoLog() => {
              'caption': log.caption,
              'file': 'files/${p.basename(log.path)}',
            },
            AudioLog() => {
              'title': log.title,
              'note': log.note,
              'durationMs': log.duration.inMilliseconds,
              'file': 'files/${p.basename(log.path)}',
            },
            VideoLog() || LocationLog() => throw UnimplementedError(
              'Export for ${log.type.name} is not built yet',
            ),
          },
        },
    ];
    return const JsonEncoder.withIndent('  ').convert(rows);
  }

  String _markdown(LogType type, List<Log> logs) {
    final out = StringBuffer('# ${_title(type)}\n');
    for (final log in logs) {
      out.write('\n## ${_heading.format(log.localMoment)}\n\n');
      out.writeln(switch (log) {
        TextLog() => log.body,
        EmojiLog() =>
          '${'${log.emoji} ${log.label ?? ''}'.trim()}\n\n'
              'Intensity ${log.strength} of 5',
        PhotoLog() =>
          '![${log.caption ?? 'Photo'}](files/${p.basename(log.path)})'
              '${log.caption == null ? '' : '\n\n${log.caption}'}',
        AudioLog() =>
          '**${log.title ?? 'Audio'}** '
              '(${_duration(log.duration)})\n\n'
              '[Listen](files/${p.basename(log.path)})'
              '${log.note == null ? '' : '\n\n${log.note}'}',
        VideoLog() || LocationLog() => throw UnimplementedError(
          'Export for ${log.type.name} is not built yet',
        ),
      });
    }
    return out.toString();
  }

  String _duration(Duration d) =>
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  String _title(LogType type) =>
      type.name[0].toUpperCase() + type.name.substring(1);
}
