import 'dart:io';

import 'package:archive/archive.dart';
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
import 'package:moment/export/export_coordinator.dart';
import 'package:moment/export/export_service.dart';
import 'package:moment/storage/storage_service.dart';
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
  late ExportCoordinator exports;
  late StorageService storage;

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
    exports = ExportCoordinator(
      service: ExportService(repository: repo, clock: () => now),
      gateway: gateway,
      scratchDirectory: Directory(p.join(tempDir.path, 'export-scratch')),
    );
    storage = StorageService(repository: repo);
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
          exports: exports,
          storage: storage,
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

  /// Backup and restore do real file and database work, so the tap that
  /// starts them (and every tap on the way) has to run in the real zone:
  /// a flow begun under flutter_test's fake clock never sees real I/O
  /// complete. The delay lets that work finish before settling.
  Future<void> tapForReal(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  /// The Privacy list builds lazily, so lower sections only exist once
  /// scrolled to.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
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
    await tapForReal(tester, find.text('Continue'));
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

      await tapForReal(tester, find.text('Back up now'));
      expect(find.text('Choose a passphrase'), findsOneWidget);
      await enterPassphrases(tester, 'short', 'short');

      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(gateway.delivered, isEmpty);
    });

    testWidgets('Back up now refuses passphrases that do not match', (
      tester,
    ) async {
      await pump(tester, AppLockController(_FakePinStorage()));

      await tapForReal(tester, find.text('Back up now'));
      await enterPassphrases(tester, 'correct horse', 'correct house');

      expect(find.text('Passphrases do not match.'), findsOneWidget);
      expect(gateway.delivered, isEmpty);
    });

    testWidgets('Back up now hands over a backup and shows when it was made', (
      tester,
    ) async {
      await repo.createText(body: 'Keep me');
      await pump(tester, AppLockController(_FakePinStorage()));

      await tapForReal(tester, find.text('Back up now'));
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

      await tapForReal(tester, find.text('Back up now'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(gateway.delivered, isEmpty);
      expect(find.text('Last backup: never'), findsOneWidget);
    });

    testWidgets('Restore picks a file, asks for its passphrase and restores', (
      tester,
    ) async {
      // Real file I/O: it must run outside the fake-clock zone.
      gateway.toPick = await tester.runAsync(
        () => backupFromElsewhere('pw-from-elsewhere'),
      );
      await pump(tester, AppLockController(_FakePinStorage()));

      await tapForReal(tester, find.text('Restore from backup'));
      expect(find.text('Enter the backup passphrase'), findsOneWidget);
      expect(find.byKey(const ValueKey('passphrase-confirm')), findsNothing);
      await enterPassphrases(tester, 'pw-from-elsewhere');

      expect(find.text('Restored 1 log'), findsOneWidget);
      expect(await db.select(db.logsTable).get(), hasLength(1));
    });

    testWidgets('a wrong restore passphrase says so and restores nothing', (
      tester,
    ) async {
      gateway.toPick = await tester.runAsync(
        () => backupFromElsewhere('right'),
      );
      await pump(tester, AppLockController(_FakePinStorage()));

      await tapForReal(tester, find.text('Restore from backup'));
      await enterPassphrases(tester, 'wrong');

      expect(
        find.text('The passphrase does not match this backup.'),
        findsOneWidget,
      );
      expect(await db.select(db.logsTable).get(), isEmpty);
    });

    testWidgets('cancelling the file picker asks nothing more', (tester) async {
      await pump(tester, AppLockController(_FakePinStorage()));

      await tapForReal(tester, find.text('Restore from backup'));

      expect(find.text('Enter the backup passphrase'), findsNothing);
    });
  });

  group('Export section', () {
    testWidgets('lists every built type, all selected, and the button', (
      tester,
    ) async {
      await pump(tester, AppLockController(_FakePinStorage()));
      await scrollTo(tester, find.text('Export selected types'));

      expect(find.text('EXPORT'), findsOneWidget);
      expect(
        find.text('Markdown, JSON and original files. Choose types.'),
        findsOneWidget,
      );
      for (final key in [
        'text',
        'emoji',
        'photo',
        'audio',
        'video',
        'location',
      ]) {
        expect(find.byKey(ValueKey('export-chip-$key')), findsOneWidget);
        expect(
          tester
              .widget<Semantics>(find.byKey(ValueKey('export-chip-$key')))
              .properties
              .selected,
          isTrue,
          reason: key,
        );
      }
      expect(find.text('Export selected types'), findsOneWidget);
    });

    testWidgets('exporting hands over a zip of just the selected types', (
      tester,
    ) async {
      await repo.createText(body: 'In the export');
      await repo.createEmoji(emoji: '😌', strength: 3);
      await pump(tester, AppLockController(_FakePinStorage()));

      await scrollTo(tester, find.byKey(const ValueKey('export-chip-emoji')));
      await tester.tap(find.byKey(const ValueKey('export-chip-emoji')));
      await tester.pump();
      await scrollTo(tester, find.text('Export selected types'));
      await tapForReal(tester, find.text('Export selected types'));

      expect(gateway.delivered, hasLength(1));
      final zip = ZipDecoder().decodeBytes(
        gateway.delivered.single.readAsBytesSync(),
      );
      expect(zip.findFile('text/text.json'), isNotNull);
      expect(zip.findFile('emoji/emoji.json'), isNull);
      expect(find.text('Export ready to save'), findsOneWidget);
    });

    testWidgets('with nothing selected the export does nothing', (
      tester,
    ) async {
      await pump(tester, AppLockController(_FakePinStorage()));
      await scrollTo(tester, find.text('Export selected types'));

      for (final key in [
        'text',
        'emoji',
        'photo',
        'audio',
        'video',
        'location',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey('export-chip-$key')));
        await tester.tap(find.byKey(ValueKey('export-chip-$key')));
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Export selected types'));
      await tapForReal(tester, find.text('Export selected types'));

      expect(gateway.delivered, isEmpty);
    });
  });

  group('Storage section', () {
    testWidgets('shows each built type with what it takes up', (tester) async {
      await repo.createText(body: 'hello');
      final audio = File(p.join(tempDir.path, 'a.m4a'))
        ..writeAsBytesSync(List.filled(3 * 1024 * 1024, 1));
      await repo.createAudio(
        path: audio.path,
        duration: const Duration(seconds: 3),
        peaks: [0.1],
      );
      await tester.runAsync(() async {
        await pump(tester, AppLockController(_FakePinStorage()));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Storage by type'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('STORAGE'), findsOneWidget);
      expect(find.text('Storage by type'), findsOneWidget);
      expect(find.byKey(const ValueKey('storage-row-audio')), findsOneWidget);
      expect(find.text('3 MB'), findsOneWidget);
      expect(find.text('<1 MB'), findsNWidgets(5));
    });
  });
}
