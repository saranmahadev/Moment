import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_coordinator.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/export/export_coordinator.dart';
import 'package:moment/export/export_service.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/photo/photo_section_screen.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/shell/app_shell.dart';
import 'package:moment/storage/storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/integration/shell_harness.dart';
import '../test/location/location_fakes.dart';
import '../test/video/video_fakes.dart';

/// The frame budget: the real shell on a phone (an emulator in CI), with
/// 20,000 logs, scrolled while the timeline records every frame. The
/// driver (test_driver/frame_budget_driver.dart) compares the frame times
/// with test_driver/frame_budget.json and fails the run past them.
/// Lets [time] pass, a frame at a time. On a device something always
/// animates, so pumpAndSettle would never return.
Future<void> settle(
  WidgetTester tester, [
  Duration time = const Duration(milliseconds: 1200),
]) async {
  final end = DateTime.now().add(time);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrolling stays inside the frame budget at 20,000 logs', (
    tester,
  ) async {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'frame_budget'),
    );
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime(2026, 11, 18, 10);
    final repo = LogRepository(db, clock: () => now);
    debugPrint('frame budget: seeding');
    await _seed(db, repo, dir, now);
    debugPrint('frame budget: seeded');

    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: AppShell(
          repository: repo,
          lockController: AppLockController(MemoryPinStorage()),
          mediaStore: MediaStore(root: dir, clock: () => now),
          picker: NoPhotoPicker(),
          createAudioRecorder: SilentAudioRecorder.new,
          createAudioPlayback: SilentAudioPlayback.new,
          videoPicker: FakeVideoPicker(),
          videoProbe: FakeVideoProbe(),
          createVideoPlayback: FakeVideoPlaybackController.new,
          locationProvider: FakeLocationProvider(),
          placeNames: FakePlaceNameLookup(),
          settings: AppSettings.inMemory(),
          reminders: NoReminders(),
          backups: BackupCoordinator(
            service: BackupService(
              db: db,
              mediaRoot: dir,
              cipher: BackupCipher(kdfIterations: 10),
            ),
            gateway: CollectingFileGateway(),
            lastBackupStore: MemoryLastBackupStore(),
            scratchDirectory: Directory(p.join(dir.path, 'scratch')),
          ),
          exports: ExportCoordinator(
            service: ExportService(repository: repo),
            gateway: CollectingFileGateway(),
            scratchDirectory: Directory(p.join(dir.path, 'exports')),
          ),
          storage: StorageService(repository: repo),
          now: () => now,
        ),
      ),
    );
    await settle(tester, const Duration(seconds: 3));
    debugPrint('frame budget: shell shown');

    Future<void> flingDown(int times) async {
      for (var i = 0; i < times; i++) {
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -700),
          2400,
          warnIfMissed: false,
        );
        await settle(tester);
      }
    }

    debugPrint('frame budget: home');
    // Home: the feed, a page at a time.
    await binding.traceAction(() => flingDown(12), reportKey: 'home_feed');

    debugPrint('frame budget: photos');
    // Library, then the photo grid (3,000 photos).
    await tester.tap(find.bySemanticsLabel('Library'));
    await settle(tester);
    await tester.ensureVisible(find.text('Photos').last);
    await settle(tester);
    await tester.tap(find.text('Photos').last);
    await settle(tester);
    await binding.traceAction(() => flingDown(12), reportKey: 'photo_grid');
    // Its Back button has scrolled away with the grid.
    Navigator.of(tester.element(find.byType(PhotoSectionScreen))).pop();
    await settle(tester);

    debugPrint('frame budget: calendar');
    // Calendar: month after month, then the day's list.
    await tester.tap(find.bySemanticsLabel('Calendar'));
    await settle(tester);
    await binding.traceAction(() async {
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.bySemanticsLabel('Previous month'));
        await settle(tester);
      }
      await flingDown(4);
    }, reportKey: 'calendar');

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await db.close();
  });
}

/// 20,000 logs over about five years: mostly text and emoji, 3,000 photos
/// and 600 videos sharing a few real image files, and places.
Future<void> _seed(
  AppDatabase db,
  LogRepository repo,
  Directory dir,
  DateTime now,
) async {
  final images = <(String, String)>[];
  for (var i = 0; i < 12; i++) {
    final picture = img.Image(width: 640, height: 480);
    img.fill(picture, color: img.ColorRgb8(40 + i * 15, 120, 200 - i * 10));
    final full = File(p.join(dir.path, 'photo$i.jpg'))
      ..writeAsBytesSync(img.encodeJpg(picture, quality: 80));
    final thumb = File(p.join(dir.path, 'photo$i-t.jpg'))
      ..writeAsBytesSync(
        img.encodeJpg(
          img.copyResize(picture, width: MediaStore.thumbnailWidth),
        ),
      );
    images.add((full.path, thumb.path));
  }
  await db.transaction(() async {
    for (var i = 0; i < 20000; i++) {
      final at = now.subtract(Duration(minutes: 131 * i));
      final (full, thumb) = images[i % images.length];
      switch (i % 100) {
        case < 15:
          await repo.createPhoto(
            path: full,
            thumbnailPath: thumb,
            caption: i.isEven ? 'Evening light $i' : null,
            createdAt: at,
          );
        case < 18:
          await repo.createVideo(
            path: full,
            posterPath: full,
            duration: Duration(seconds: 5 + i % 90),
            caption: 'Clip $i',
            createdAt: at,
          );
        case < 25:
          await repo.createLocation(
            latitude: 12.9 + (i % 50) / 100,
            longitude: 77.6 + (i % 30) / 100,
            name: 'Place $i',
            createdAt: at,
          );
        case < 55:
          await repo.createEmoji(
            emoji: '😌',
            label: 'Calm',
            strength: 1 + i % 5,
            createdAt: at,
          );
        default:
          await repo.createText(
            body:
                'Day $i. A longer entry about the walk home, the rain on '
                'the window and what was for dinner, long enough to wrap.',
            createdAt: at,
          );
      }
    }
  });
}
