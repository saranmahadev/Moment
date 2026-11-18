import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_coordinator.dart';
import 'package:moment/backup/backup_file_gateway.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/backup/last_backup_store.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/diagnostics/diagnostics_log.dart';
import 'package:path/path.dart' as p;

class _Gateway implements BackupFileGateway {
  File? last;
  @override
  Future<void> deliver(File backup) async => last = backup;
  @override
  Future<File?> pick() async => last;
}

class _Store implements LastBackupStore {
  @override
  Future<DateTime?> read() async => null;
  @override
  Future<void> write(DateTime at) async {}
}

void main() {
  test('backups and restores are noted in diagnostics, failures too', () async {
    final dir = Directory.systemTemp.createTempSync('backup_diag_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final log = DiagnosticsLog(MemoryDiagnosticsStore());
    BackupCoordinator coordinatorFor(AppDatabase db, String name) =>
        BackupCoordinator(
          service: BackupService(
            db: db,
            mediaRoot: Directory(p.join(dir.path, name))..createSync(),
            cipher: BackupCipher(kdfIterations: 10),
          ),
          gateway: gateway,
          lastBackupStore: _Store(),
          scratchDirectory: Directory(p.join(dir.path, 'scratch')),
          diagnostics: log,
        );
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);
    await LogRepository(source).createText(body: 'secret words');

    await coordinatorFor(source, 'a').backUp(passphrase: 'right');
    final restoring = coordinatorFor(target, 'b');
    await expectLater(
      restoring.restore(gateway.last!, passphrase: 'wrong'),
      throwsA(anything),
    );
    await restoring.restore(gateway.last!, passphrase: 'right');

    final entries = await log.entries();
    expect(entries.map((e) => (e.name, e.detail)), [
      ('backup.made', ''),
      ('restore.failed', 'WrongPassphraseException'),
      ('restore.done', '1 logs'),
    ]);
    expect(await log.report(), isNot(contains('secret')));
  });
}

final gateway = _Gateway();
