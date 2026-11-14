import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_coordinator.dart';
import 'package:moment/backup/backup_file_gateway.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/backup/last_backup_store.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/orb_field.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/pin_storage.dart';
import 'package:moment/privacy/privacy_screen.dart';
import 'package:path/path.dart' as p;

class _FakePinStorage implements PinStorage {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async => stored = value;

  @override
  Future<void> clear() async => stored = null;
}

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
  late BackupCoordinator backups;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('privacy_screen_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
    gateway = _FakeGateway();
    store = _MemoryStore();
    backups = BackupCoordinator(
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

  Future<void> pump(
    WidgetTester tester,
    AppLockController controller, {
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: PrivacyScreen(
          controller: controller,
          backups: backups,
          now: () => now,
          onBack: onBack,
        ),
      ),
    );
    await tester.pump();
  }

  /// A .moment file holding one text log, made on "another phone".
  Future<File> backupFromElsewhere(String passphrase) async {
    final otherDb = AppDatabase(NativeDatabase.memory());
    addTearDown(otherDb.close);
    await LogRepository(
      otherDb,
      clock: () => now,
    ).createText(body: 'Restored me');
    final file = File(p.join(tempDir.path, 'elsewhere.moment'));
    await BackupService(
      db: otherDb,
      mediaRoot: Directory(p.join(tempDir.path, 'other'))..createSync(),
      cipher: BackupCipher(kdfIterations: 10),
      clock: () => now,
    ).exportTo(file, passphrase: passphrase);
    return file;
  }

  Future<void> enterPassphrases(
    WidgetTester tester,
    String first, [
    String? confirm,
  ]) async {
    await tester.enterText(find.byKey(const ValueKey('passphrase')), first);
    if (confirm != null) {
      await tester.enterText(
        find.byKey(const ValueKey('passphrase-confirm')),
        confirm,
      );
    }
    await tester.runAsync(() async {
      await tester.tap(find.text('Continue'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title and the local-only banner', (tester) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    expect(find.text('Privacy and backup'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
    expect(
      find.text('No account, no servers, no internet permission.'),
      findsOneWidget,
    );
    expect(find.byType(OrbField), findsOneWidget);
  });

  testWidgets('shows the Security section with App lock and Lock after', (
    tester,
  ) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('App lock'), findsOneWidget);
    expect(find.text('PIN with Face ID'), findsOneWidget);
    expect(find.text('Lock after'), findsOneWidget);
    expect(find.text('Immediately'), findsOneWidget);
  });

  testWidgets('App lock is off when no PIN is set', (tester) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isFalse);
  });

  testWidgets('App lock is on when a PIN is already set', (tester) async {
    final storage = _FakePinStorage();
    final controller = AppLockController(storage);
    await controller.setPin('1234');

    await pump(tester, controller);

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);
  });

  testWidgets('turning App lock on opens CreatePinScreen', (tester) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Choose a PIN'), findsOneWidget);
  });

  testWidgets('finishing CreatePinScreen returns to Privacy with App lock on', (
    tester,
  ) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    for (final digit in '1234'.split('')) {
      await tester.tap(find.byKey(ValueKey('digit-$digit')));
      await tester.pump();
    }
    for (final digit in '1234'.split('')) {
      await tester.tap(find.byKey(ValueKey('digit-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Privacy and backup'), findsOneWidget);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);
    expect(await controller.hasPin(), isTrue);
  });

  testWidgets('turning App lock off clears the PIN', (tester) async {
    final storage = _FakePinStorage();
    final controller = AppLockController(storage);
    await controller.setPin('1234');

    await pump(tester, controller);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isFalse);
    expect(await controller.hasPin(), isFalse);
  });

  testWidgets('the back button calls onBack', (tester) async {
    final controller = AppLockController(_FakePinStorage());
    var backed = false;
    await pump(tester, controller, onBack: () => backed = true);

    await tester.tap(find.bySemanticsLabel('Back'));

    expect(backed, isTrue);
  });

  group('Backup section', () {
    testWidgets('shows backup and restore rows, with no backup made yet', (
      tester,
    ) async {
      await pump(tester, AppLockController(_FakePinStorage()));

      expect(find.text('BACKUP'), findsOneWidget);
      expect(find.text('Encrypted backup'), findsOneWidget);
      expect(find.text('Last backup: never'), findsOneWidget);
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Restore from backup'), findsOneWidget);
      expect(find.text('Choose a backup file'), findsOneWidget);
    });

    testWidgets('shows when the last backup was made', (tester) async {
      store.value = DateTime.utc(2026, 11, 6, 18, 5);
      await pump(tester, AppLockController(_FakePinStorage()));
      await tester.pump();

      expect(find.text('Last backup: 6 Nov 2026, 18:05'), findsOneWidget);
    });

    testWidgets('Back up now refuses a passphrase that is too short', (
      tester,
    ) async {
      await pump(tester, AppLockController(_FakePinStorage()));

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a passphrase'), findsOneWidget);
      await enterPassphrases(tester, 'short', 'short');

      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(gateway.delivered, isEmpty);
    });

    testWidgets('Back up now refuses passphrases that do not match', (
      tester,
    ) async {
      await pump(tester, AppLockController(_FakePinStorage()));

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();
      await enterPassphrases(tester, 'correct horse', 'correct house');

      expect(find.text('Passphrases do not match.'), findsOneWidget);
      expect(gateway.delivered, isEmpty);
    });

    testWidgets('Back up now hands over a backup and shows when it was made', (
      tester,
    ) async {
      await repo.createText(body: 'Keep me');
      await pump(tester, AppLockController(_FakePinStorage()));

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();
      await enterPassphrases(tester, 'correct horse', 'correct horse');

      expect(gateway.delivered, hasLength(1));
      expect(find.text('Choose a passphrase'), findsNothing);
      expect(find.text('Last backup: 7 Nov 2026, 10:30'), findsOneWidget);
      expect(find.text('Backup ready to save'), findsOneWidget);
    });

    testWidgets('cancelling the passphrase sheet makes no backup', (
      tester,
    ) async {
      await pump(tester, AppLockController(_FakePinStorage()));

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(gateway.delivered, isEmpty);
      expect(find.text('Last backup: never'), findsOneWidget);
    });

    testWidgets('Restore picks a file, asks for its passphrase and restores', (
      tester,
    ) async {
      gateway.toPick = await backupFromElsewhere('pw-from-elsewhere');
      await pump(tester, AppLockController(_FakePinStorage()));

      await tester.runAsync(() async {
        await tester.tap(find.text('Restore from backup'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('Enter the backup passphrase'), findsOneWidget);
      expect(find.byKey(const ValueKey('passphrase-confirm')), findsNothing);
      await enterPassphrases(tester, 'pw-from-elsewhere');

      expect(find.text('Restored 1 log'), findsOneWidget);
      expect(await db.select(db.logsTable).get(), hasLength(1));
    });

    testWidgets('a wrong restore passphrase says so and restores nothing', (
      tester,
    ) async {
      gateway.toPick = await backupFromElsewhere('right');
      await pump(tester, AppLockController(_FakePinStorage()));

      await tester.runAsync(() async {
        await tester.tap(find.text('Restore from backup'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      await enterPassphrases(tester, 'wrong');

      expect(
        find.text('The passphrase does not match this backup.'),
        findsOneWidget,
      );
      expect(await db.select(db.logsTable).get(), isEmpty);
    });

    testWidgets('cancelling the file picker asks nothing more', (tester) async {
      await pump(tester, AppLockController(_FakePinStorage()));

      await tester.runAsync(() async {
        await tester.tap(find.text('Restore from backup'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Enter the backup passphrase'), findsNothing);
    });
  });
}
