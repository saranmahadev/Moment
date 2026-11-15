import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'backup_file_gateway.dart';
import 'backup_service.dart';
import 'last_backup_store.dart';

final _fileDateFormat = DateFormat('yyyy-MM-dd');

/// The backup flows as the Privacy screen drives them: write a backup and
/// hand it over, remember when, and pick and restore one.
class BackupCoordinator {
  BackupCoordinator({
    required BackupService service,
    required BackupFileGateway gateway,
    required LastBackupStore lastBackupStore,
    required Directory scratchDirectory,
    DateTime Function() clock = DateTime.now,
  }) : _service = service,
       _gateway = gateway,
       _lastBackupStore = lastBackupStore,
       _scratch = scratchDirectory,
       _clock = clock;

  final BackupService _service;
  final BackupFileGateway _gateway;
  final LastBackupStore _lastBackupStore;
  final Directory _scratch;
  final DateTime Function() _clock;

  Future<DateTime?> lastBackup() => _lastBackupStore.read();

  /// Writes `Moment <date>.moment` under the scratch directory, offers it
  /// through the gateway and records the time.
  Future<void> backUp({required String passphrase}) async {
    final now = _clock();
    await _scratch.create(recursive: true);
    final file = File(
      p.join(_scratch.path, 'Moment ${_fileDateFormat.format(now)}.moment'),
    );
    await _service.exportTo(file, passphrase: passphrase);
    await _gateway.deliver(file);
    await _lastBackupStore.write(now);
  }

  Future<File?> pickBackup() => _gateway.pick();

  Future<RestoreSummary> restore(File backup, {required String passphrase}) =>
      _service.restoreFrom(backup, passphrase: passphrase);
}
