import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/audio/audio_playback_controller.dart';
import 'package:moment/audio/audio_recorder_controller.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_coordinator.dart';
import 'package:moment/backup/backup_file_gateway.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/backup/last_backup_store.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/export/export_coordinator.dart';
import 'package:moment/export/export_service.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/pin_storage.dart';
import 'package:moment/photo/photo_picker.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/settings/reminder_scheduler.dart';
import 'package:moment/shell/app_shell.dart';
import 'package:moment/storage/storage_service.dart';
import 'package:moment/widgets/deep_links.dart';
import 'package:path/path.dart' as p;

import '../location/location_fakes.dart';
import '../video/video_fakes.dart';

class MemoryPinStorage implements PinStorage {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async => stored = value;

  @override
  Future<void> clear() async => stored = null;
}

class NoPhotoPicker implements PhotoPicker {
  @override
  Future<File?> pickFromCamera() async => null;

  @override
  Future<File?> pickFromGallery() async => null;
}

class SilentAudioRecorder implements AudioRecorderController {
  @override
  Stream<double> get amplitudeStream => const Stream.empty();

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

class SilentAudioPlayback implements AudioPlaybackController {
  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<bool> get playingStream => const Stream.empty();

  @override
  Future<void> load(String path) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setLoop(bool on) async {}

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

/// A reminder scheduler that schedules nothing and always succeeds.
class NoReminders implements ReminderScheduler {
  @override
  Future<bool> enable(TimeOfDay time) async => true;

  @override
  Future<void> disable() async {}
}

class CollectingFileGateway implements BackupFileGateway {
  final delivered = <File>[];
  File? toPick;

  @override
  Future<void> deliver(File backup) async => delivered.add(backup);

  @override
  Future<File?> pick() async => toPick;
}

class MemoryLastBackupStore implements LastBackupStore {
  DateTime? value;

  @override
  Future<DateTime?> read() async => value;

  @override
  Future<void> write(DateTime at) async => value = at;
}

/// The real app shell on an in-memory database, with every device-facing
/// seam faked: what an integration test drives end to end.
class ShellHarness {
  ShellHarness._(this.db, this.repo, this.tempDir, this.gateway);

  final AppDatabase db;
  final LogRepository repo;
  final Directory tempDir;
  final CollectingFileGateway gateway;

  static Future<ShellHarness> pump(
    WidgetTester tester, {
    FakeVideoPicker? videoPicker,
    FakeLocationProvider? locationProvider,
    FakePlaceNameLookup? placeNames,
    AppSettings? settings,
    DateTime Function()? now,
    DeepLinkInbox? deepLinks,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tempDir = Directory.systemTemp.createTempSync('shell_harness_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    // A fixed day, not the real one: the tests run with Flutter's Ahem test
    // font, where a long weekday name ("Wednesday") is wider than the Home
    // header, so a flow test that read the real clock failed every Wednesday.
    final clock = now ?? () => DateTime(2026, 11, 7, 10);
    final repo = LogRepository(db, clock: clock);
    final support = Directory(p.join(tempDir.path, 'app_support'))
      ..createSync();
    final gateway = CollectingFileGateway();

    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: AppShell(
          repository: repo,
          lockController: AppLockController(MemoryPinStorage()),
          mediaStore: MediaStore(root: support, clock: clock),
          picker: NoPhotoPicker(),
          createAudioRecorder: SilentAudioRecorder.new,
          createAudioPlayback: SilentAudioPlayback.new,
          videoPicker: videoPicker ?? FakeVideoPicker(),
          videoProbe: FakeVideoProbe(),
          createVideoPlayback: FakeVideoPlaybackController.new,
          locationProvider: locationProvider ?? FakeLocationProvider(),
          placeNames: placeNames ?? FakePlaceNameLookup(),
          settings: settings ?? AppSettings.inMemory(),
          reminders: NoReminders(),
          backups: BackupCoordinator(
            service: BackupService(
              db: db,
              mediaRoot: support,
              cipher: BackupCipher(kdfIterations: 10),
              clock: clock,
            ),
            gateway: gateway,
            lastBackupStore: MemoryLastBackupStore(),
            scratchDirectory: Directory(p.join(tempDir.path, 'scratch')),
            clock: clock,
          ),
          exports: ExportCoordinator(
            service: ExportService(repository: repo, clock: clock),
            gateway: gateway,
            scratchDirectory: Directory(p.join(tempDir.path, 'exports')),
          ),
          storage: StorageService(repository: repo),
          now: clock,
          deepLinks: deepLinks,
        ),
      ),
    );
    await tester.pump();
    return ShellHarness._(db, repo, tempDir, gateway);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  /// Opens the Add sheet and picks [type] (a `LogType` name).
  Future<void> addLogOfType(WidgetTester tester, String type) async {
    await tester.tap(find.bySemanticsLabel('Add a log'));
    await tester.pumpAndSettle();
    final card = find.byKey(ValueKey('add-sheet-type-LogType.$type'));
    await tester.scrollUntilVisible(
      card,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  /// From Home: Library, then Trash at the end of the list.
  Future<void> openTrash(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pump();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
  }

  /// From Trash back to the Home tab.
  Future<void> backToHome(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();
  }
}
