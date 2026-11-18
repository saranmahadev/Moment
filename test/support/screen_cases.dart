import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/audio/audio_detail_screen.dart';
import 'package:moment/audio/create_audio_screen.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_coordinator.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/calendar/calendar_screen.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/orb_field.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/design/tokens.dart';
import 'package:moment/detail/emoji_detail_screen.dart';
import 'package:moment/detail/text_detail_screen.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/emoji/create_emoji_screen.dart';
import 'package:moment/export/export_coordinator.dart';
import 'package:moment/export/export_service.dart';
import 'package:moment/home/add_sheet.dart';
import 'package:moment/library/log_filter.dart';
import 'package:moment/library/log_filter_sheet.dart';
import 'package:moment/home/home_screen.dart';
import 'package:moment/library/library_screen.dart';
import 'package:moment/location/create_location_screen.dart';
import 'package:moment/location/location_detail_screen.dart';
import 'package:moment/location/location_section_screen.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/biometric_authenticator.dart';
import 'package:moment/lock/lock_screen.dart';
import 'package:moment/photo/create_photo_screen.dart';
import 'package:moment/photo/photo_detail_screen.dart';
import 'package:moment/photo/photo_section_screen.dart';
import 'package:moment/privacy/privacy_screen.dart';
import 'package:moment/search/search_screen.dart';
import 'package:moment/section/section_screen.dart';
import 'package:moment/settings/about_screen.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/settings/quick_emoji_screen.dart';
import 'package:moment/settings/settings_screen.dart';
import 'package:moment/storage/storage_service.dart';
import 'package:moment/streaks/streak_settings_screen.dart';
import 'package:moment/streaks/streaks_screen.dart';
import 'package:moment/text/create_text_screen.dart';
import 'package:moment/trash/trash_screen.dart';
import 'package:moment/widgets/widget_settings_screen.dart';
import 'package:moment/video/create_video_screen.dart';
import 'package:moment/video/video_detail_screen.dart';
import 'package:moment/video/video_section_screen.dart';
import 'package:path/path.dart' as p;

import '../integration/shell_harness.dart';
import '../location/location_fakes.dart';
import 'fake_widget_bridge.dart';
import '../video/video_fakes.dart';

class _NoBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<bool> authenticate() async => false;
}

/// What a screen under test is built from: a library on an in-memory
/// database, with every device-facing seam faked.
class ScreenFixture {
  ScreenFixture()
    : tempDir = Directory.systemTemp.createTempSync('screen_cases_'),
      db = AppDatabase(NativeDatabase.memory()) {
    repo = LogRepository(db, clock: () => now);
    mediaStore = MediaStore(root: tempDir, clock: () => now);
  }

  /// Friday 6 November 2026, late evening: the day the mockups show.
  final now = DateTime.utc(2026, 11, 6, 22);
  final Directory tempDir;
  final AppDatabase db;
  late final LogRepository repo;
  late final MediaStore mediaStore;
  final settings = AppSettings.inMemory({
    'recentSearches': ['balcony', 'station'],
  });

  /// A file that exists but is not an image: the frame stays empty, which
  /// is the same on every machine.
  String blank(String name) =>
      (File(p.join(tempDir.path, name))..writeAsStringSync('fake')).path;

  /// One log of every type on the 6th, a few on earlier days, one in Trash.
  Future<void> seed() async {
    const peaks = [0.2, 0.5, 0.9, 0.4, 0.7, 0.3, 0.8, 0.5, 0.6, 0.2, 0.9, 0.4];
    await repo.createPhoto(
      path: blank('a.jpg'),
      thumbnailPath: blank('a-thumb.jpg'),
      caption: 'Morning light on the balcony.',
      createdAt: DateTime.utc(2026, 11, 6, 8, 40),
    );
    await repo.createVideo(
      path: p.join(tempDir.path, 'a.mp4'),
      posterPath: p.join(tempDir.path, 'a-missing.jpg'),
      duration: const Duration(seconds: 48),
      caption: 'Walk to the station',
      createdAt: DateTime.utc(2026, 11, 6, 12, 20),
    );
    await repo.createLocation(
      latitude: 12.9716,
      longitude: 77.5946,
      accuracyMeters: 12,
      name: 'Favourite bench',
      note: 'Shade until noon.',
      createdAt: DateTime.utc(2026, 11, 6, 17, 30),
    );
    await repo.createAudio(
      path: blank('a.m4a'),
      duration: const Duration(seconds: 42),
      peaks: peaks,
      title: 'Voice note',
      note: 'Remember to call back.',
      createdAt: DateTime.utc(2026, 11, 6, 18, 5),
    );
    await repo.createText(
      body: 'Quiet evening. Finished the book I started on the balcony.',
      createdAt: DateTime.utc(2026, 11, 6, 20, 12),
    );
    await repo.createEmoji(
      emoji: '😌',
      label: 'Calm',
      strength: 4,
      createdAt: DateTime.utc(2026, 11, 6, 21, 40),
    );
    await repo.createText(
      body: 'Wrote the whole page sitting on the balcony floor.',
      createdAt: DateTime.utc(2026, 11, 4, 17, 20),
    );
    await repo.createEmoji(
      emoji: '😊',
      label: 'Happy',
      strength: 3,
      createdAt: DateTime.utc(2026, 11, 3, 9),
    );
    await repo.createLocation(
      latitude: 12.9352,
      longitude: 77.6245,
      accuracyMeters: 8,
      name: 'Tea stall',
      createdAt: DateTime.utc(2026, 11, 5, 6, 40),
    );
    final gone = await repo.createText(
      body: 'A thought I let go of.',
      createdAt: DateTime.utc(2026, 11, 2, 9),
    );
    await repo.softDelete(gone);
  }

  Future<T> first<T extends Log>() async => (await repo.getAll())
      .whereType<T>()
      .firstWhere((log) => log.deletedAt == null);

  Future<void> dispose() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  }
}

/// One screen of the app, as a test can show it.
class ScreenCase {
  const ScreenCase(this.name, this.build, {this.withOrbs = false});

  /// Also the golden file's name.
  final String name;
  final Future<Widget> Function(ScreenFixture fixture) build;

  /// Tab screens are transparent and sit on the shell's orbs; give them
  /// the same backdrop.
  final bool withOrbs;
}

/// Every screen in the mockups (01 to 27), plus the screens Settings
/// opens and the two Streaks screens. Phase 4's checks run over all of them: light and dark goldens,
/// Reduce Transparency, tap targets, labels and large text.
final screenCases = <ScreenCase>[
  ScreenCase(
    '01_lock',
    (f) async => LockScreen(
      controller: AppLockController(MemoryPinStorage()),
      biometrics: _NoBiometrics(),
    ),
  ),
  ScreenCase(
    '02_home',
    (f) async =>
        HomeScreen(repository: f.repo, settings: f.settings, now: () => f.now),
    withOrbs: true,
  ),
  ScreenCase(
    '03_add',
    (f) async => AddSheet(onTypeSelected: (_) {}, onClose: () {}),
    withOrbs: true,
  ),
  ScreenCase(
    '04_library',
    (f) async => LibraryScreen(repository: f.repo, now: () => f.now),
    withOrbs: true,
  ),
  ScreenCase(
    '05_new_text',
    (f) async => CreateTextScreen(
      repository: f.repo,
      now: () => f.now,
      onSaved: (_) {},
      onClose: () {},
    ),
  ),
  ScreenCase(
    '06_new_emoji',
    (f) async => CreateEmojiScreen(
      repository: f.repo,
      now: () => f.now,
      onSaved: (_) {},
      onClose: () {},
    ),
  ),
  ScreenCase(
    '07_new_photo',
    (f) async => CreatePhotoScreen(
      repository: f.repo,
      mediaStore: f.mediaStore,
      picker: NoPhotoPicker(),
      now: () => f.now,
      onSaved: (_) {},
      onClose: () {},
    ),
  ),
  ScreenCase(
    '08_new_video',
    (f) async => CreateVideoScreen(
      repository: f.repo,
      mediaStore: f.mediaStore,
      picker: FakeVideoPicker(),
      probe: FakeVideoProbe(),
      now: () => f.now,
      onSaved: (_) {},
      onClose: () {},
    ),
  ),
  ScreenCase(
    '09_new_audio',
    (f) async => CreateAudioScreen(
      repository: f.repo,
      mediaStore: f.mediaStore,
      recorder: SilentAudioRecorder(),
      now: () => f.now,
      onSaved: (_) {},
      onClose: () {},
    ),
  ),
  ScreenCase(
    '10_new_location',
    (f) async => CreateLocationScreen(
      repository: f.repo,
      provider: FakeLocationProvider(),
      now: () => f.now,
      onSaved: (_) {},
      onClose: () {},
    ),
  ),
  ScreenCase(
    '11_text_section',
    (f) async => SectionScreen(type: LogType.text, repository: f.repo),
  ),
  ScreenCase(
    '12_emoji_section',
    (f) async => SectionScreen(type: LogType.emoji, repository: f.repo),
  ),
  ScreenCase(
    '13_photo_section',
    (f) async => PhotoSectionScreen(repository: f.repo),
  ),
  ScreenCase(
    '14_video_section',
    (f) async => VideoSectionScreen(repository: f.repo),
  ),
  ScreenCase(
    '15_audio_section',
    (f) async => SectionScreen(type: LogType.audio, repository: f.repo),
  ),
  ScreenCase(
    '16_location_section',
    (f) async => LocationSectionScreen(repository: f.repo),
  ),
  ScreenCase(
    '17_text_detail',
    (f) async =>
        TextDetailScreen(log: await f.first<TextLog>(), repository: f.repo),
  ),
  ScreenCase(
    '18_emoji_detail',
    (f) async =>
        EmojiDetailScreen(log: await f.first<EmojiLog>(), repository: f.repo),
  ),
  ScreenCase(
    '19_photo_detail',
    (f) async => PhotoDetailScreen(
      log: await f.first<PhotoLog>(),
      repository: f.repo,
      mediaStore: f.mediaStore,
      picker: NoPhotoPicker(),
      now: () => f.now,
    ),
  ),
  ScreenCase(
    '20_video_detail',
    (f) async => VideoDetailScreen(
      log: await f.first<VideoLog>(),
      repository: f.repo,
      mediaStore: f.mediaStore,
      picker: FakeVideoPicker(),
      probe: FakeVideoProbe(),
      playback: FakeVideoPlaybackController(),
      now: () => f.now,
    ),
  ),
  ScreenCase(
    '21_audio_detail',
    (f) async => AudioDetailScreen(
      log: await f.first<AudioLog>(),
      repository: f.repo,
      playback: SilentAudioPlayback(),
      now: () => f.now,
    ),
  ),
  ScreenCase(
    '22_location_detail',
    (f) async => LocationDetailScreen(
      log: await f.first<LocationLog>(),
      repository: f.repo,
      provider: FakeLocationProvider(),
      now: () => f.now,
    ),
  ),
  ScreenCase(
    '23_calendar',
    (f) async => CalendarScreen(repository: f.repo, now: () => f.now),
    withOrbs: true,
  ),
  ScreenCase(
    '24_search',
    (f) async => SearchScreen(
      repository: f.repo,
      settings: f.settings,
      onOpenLog: (_) {},
      onBack: () {},
    ),
  ),
  ScreenCase(
    '24_search_results',
    (f) async => SearchScreen(
      repository: f.repo,
      settings: f.settings,
      initialQuery: 'balcony',
      onOpenLog: (_) {},
      onBack: () {},
    ),
  ),
  ScreenCase(
    '25_settings',
    (f) async => SettingsScreen(
      repository: f.repo,
      settings: f.settings,
      reminders: NoReminders(),
      onOpenPrivacy: () {},
      onOpenTrash: () {},
    ),
    withOrbs: true,
  ),
  ScreenCase('26_privacy', (f) async {
    final gateway = CollectingFileGateway();
    return PrivacyScreen(
      controller: AppLockController(MemoryPinStorage()),
      backups: BackupCoordinator(
        service: BackupService(
          db: f.db,
          mediaRoot: f.tempDir,
          cipher: BackupCipher(kdfIterations: 10),
          clock: () => f.now,
        ),
        gateway: gateway,
        lastBackupStore: MemoryLastBackupStore(),
        scratchDirectory: Directory(p.join(f.tempDir.path, 'scratch')),
        clock: () => f.now,
      ),
      exports: ExportCoordinator(
        service: ExportService(repository: f.repo, clock: () => f.now),
        gateway: gateway,
        scratchDirectory: Directory(p.join(f.tempDir.path, 'exports')),
      ),
      storage: StorageService(repository: f.repo),
      settings: f.settings,
      now: () => f.now,
    );
  }),
  ScreenCase(
    '27_trash',
    (f) async => TrashScreen(repository: f.repo, now: () => f.now),
  ),
  ScreenCase('settings_about', (f) async => AboutScreen(onBack: () {})),
  // The Streaks page and its settings (0.5.0), with a few more days logged
  // before 6 November so the heatmap and the milestones have something to
  // show: a run from 27 October, one forgiven day on the 2nd.
  ScreenCase('streaks', (f) async {
    for (final (month, day) in const [
      (10, 12),
      (10, 13),
      (10, 14),
      (10, 16),
      (10, 17),
      (10, 20),
      (10, 21),
      (10, 22),
      (10, 23),
      (10, 24),
      (10, 27),
      (10, 28),
      (10, 29),
      (10, 30),
      (10, 31),
      (11, 1),
    ]) {
      await f.repo.createText(
        body: 'Day $month-$day',
        createdAt: DateTime.utc(2026, month, day, 12),
      );
    }
    return StreaksScreen(
      repository: f.repo,
      settings: f.settings,
      now: () => f.now,
      onBack: () {},
      onOpenSettings: () {},
    );
  }),
  ScreenCase(
    'streak_settings',
    (f) async => StreakSettingsScreen(settings: f.settings, onBack: () {}),
  ),
  ScreenCase(
    'widget_settings',
    (f) async => WidgetSettingsScreen(
      settings: f.settings,
      bridge: FakeWidgetBridge(),
      onBack: () {},
    ),
  ),
  ScreenCase(
    'settings_quick_emoji',
    (f) async => QuickEmojiScreen(settings: f.settings, onBack: () {}),
  ),
  // The popup a Library card opens: Emoji has the most to choose from.
  ScreenCase(
    'library_filter_emoji',
    (f) async => Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: LogFilterSheet(
          type: LogType.emoji,
          initial: const LogFilter(
            window: FilterWindow.last7,
            strengths: {4, 5},
          ),
          onApply: (_) {},
        ),
      ),
    ),
  ),
];

/// Wraps the screen [pumpScreenCase] shows; goldens are taken of it.
const screenBoundaryKey = ValueKey('screen-under-test');

/// Shows [screen] on a phone-sized surface in the given theme, the way
/// the app would: with real theme tokens, and the orbs behind a tab
/// screen. Returns the fixture, already registered for clean-up.
Future<ScreenFixture> pumpScreenCase(
  WidgetTester tester,
  ScreenCase screen, {
  Brightness brightness = Brightness.light,
  bool reduceTransparency = false,
  double textScale = 1,
  Size size = const Size(390, 844),
  List<String>? fontFamilyFallback,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fixture = ScreenFixture();
  // Seeding and building touch a real (in-memory) database and real files.
  late Widget widget;
  await tester.runAsync(() async {
    await fixture.seed();
    widget = await screen.build(fixture);
  });
  final base = momentTheme(
    brightness: brightness,
    reduceTransparency: reduceTransparency,
  );
  final theme = fontFamilyFallback == null
      ? base
      : base.copyWith(
          textTheme: base.textTheme.apply(
            fontFamilyFallback: fontFamilyFallback,
          ),
        );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      // The boundary a golden is taken of: the screen at one pixel per
      // logical pixel, like the other baselines.
      home: RepaintBoundary(
        key: screenBoundaryKey,
        child: screen.withOrbs
            ? Scaffold(
                backgroundColor: theme.extension<MomentTokens>()!.ground,
                body: Stack(
                  children: [
                    const Positioned.fill(child: OrbField()),
                    widget,
                  ],
                ),
              )
            : widget,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
  return fixture;
}

/// Takes the screen down and frees what [pumpScreenCase] made.
Future<void> closeScreenCase(WidgetTester tester, ScreenFixture fixture) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.runAsync(fixture.dispose);
}

/// Loads the app's own typefaces (and the icon font), so text is measured
/// and drawn as on a phone rather than in the test font's solid blocks.
/// Call from `setUpAll`.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(
        File(file).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter/Inter-Regular.ttf',
    'assets/fonts/Inter/Inter-Medium.ttf',
    'assets/fonts/Inter/Inter-SemiBold.ttf',
  ]);
  await load('Newsreader', [
    'assets/fonts/Newsreader/Newsreader-Regular.ttf',
    'assets/fonts/Newsreader/Newsreader-Medium.ttf',
    'assets/fonts/Newsreader/Newsreader-Italic.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (flutterRoot != null && icons.existsSync()) {
    await load('MaterialIcons', [icons.path]);
  }
}
