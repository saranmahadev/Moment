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
import 'package:path/path.dart' as p;

class _FakeGateway implements BackupFileGateway {
  final delivered = <File>[];
  File? toPick;

  @override
  Future<void> deliver(File backup) async => delivered.add(backup);

  @override
  Future<File?> pick() async => toPick;
}

class _MemoryStore implements LastBackupStore {
  DateTime? value;

  @override
  Future<DateTime?> read() async => value;

  @override
  Future<void> write(DateTime at) async => value = at;
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 10, 30);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late _FakeGateway gateway;
  late _MemoryStore store;
  late BackupCoordinator coordinator;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('backup_coordinator_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
    gateway = _FakeGateway();
    store = _MemoryStore();
    coordinator = BackupCoordinator(
      service: BackupService(
        db: db,
        mediaRoot: Directory(p.join(tempDir.path, 'support'))..createSync(),
        cipher: BackupCipher(kdfIterations: 10),
        clock: () => now,
      ),
      gateway: gateway,
      lastBackupStore: store,
      scratchDirectory: Directory(p.join(tempDir.path, 'scratch')),
      clock: () => now,
    );
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  test(
    'backUp writes a dated .moment file, hands it over and records when',
    () async {
      await repo.createText(body: 'Keep me');

      await coordinator.backUp(passphrase: 'correct horse');

      expect(gateway.delivered, hasLength(1));
      final file = gateway.delivered.single;
      expect(p.basename(file.path), 'Moment 2026-11-07.moment');
      expect(file.readAsBytesSync().sublist(0, 8), BackupCipher.magic);
      expect(store.value, now);
      expect(await coordinator.lastBackup(), now);
    },
  );

  test('lastBackup is null until a backup has been made', () async {
    expect(await coordinator.lastBackup(), isNull);
  });

  test('restore picks a file through the gateway and restores it', () async {
    await repo.createText(body: 'Keep me');
    await coordinator.backUp(passphrase: 'pw');
    await db.delete(db.logsTable).go();
    gateway.toPick = gateway.delivered.single;

    final picked = await coordinator.pickBackup();
    final summary = await coordinator.restore(picked!, passphrase: 'pw');

    expect(summary.logsRestored, 1);
    expect(await db.select(db.logsTable).get(), hasLength(1));
  });

  test('pickBackup is null when the user cancels', () async {
    expect(await coordinator.pickBackup(), isNull);
  });

  test('a fresh backUp replaces an earlier file of the same name', () async {
    await coordinator.backUp(passphrase: 'pw');
    final first = gateway.delivered.single.readAsBytesSync();
    await coordinator.backUp(passphrase: 'pw');

    expect(gateway.delivered, hasLength(2));
    expect(gateway.delivered[1].path, gateway.delivered[0].path);
    expect(gateway.delivered[1].readAsBytesSync(), isNot(first));
  });
}
