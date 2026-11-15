import 'dart:convert';
import 'dart:io';

import '../data/log_repository.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';

/// How much space each built type takes up. Text and emoji count the bytes
/// of what was written; photo and audio count their files on disk. Logs in
/// Trash are included, because their files stay until they are purged.
class StorageService {
  StorageService({required LogRepository repository})
    : _repository = repository;

  final LogRepository _repository;

  Future<Map<LogType, int>> measure() async {
    final usage = {for (final type in builtLogTypes) type: 0};
    for (final log in await _repository.getAll()) {
      final bytes = switch (log) {
        TextLog() => utf8.encode(log.body).length,
        EmojiLog() =>
          utf8.encode(log.emoji).length + utf8.encode(log.label ?? '').length,
        PhotoLog() =>
          await _fileSize(log.path) + await _fileSize(log.thumbnailPath),
        AudioLog() => await _fileSize(log.path),
      };
      usage[log.type] = (usage[log.type] ?? 0) + bytes;
    }
    return usage;
  }

  Future<int> _fileSize(String path) async {
    final file = File(path);
    return await file.exists() ? await file.length() : 0;
  }
}

/// A short size for the Storage by type rows: "<1 MB", "180 MB", "2.4 GB".
String formatBytes(int bytes) {
  const mb = 1024 * 1024;
  const gb = 1024 * mb;
  if (bytes < mb) return '<1 MB';
  if (bytes < gb) return '${(bytes / mb).round()} MB';
  final gigabytes = bytes / gb;
  final text = gigabytes.toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} GB';
}
