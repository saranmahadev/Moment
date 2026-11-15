import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/audio/audio_detail_screen.dart';
import 'package:moment/audio/create_audio_screen.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/location/create_location_screen.dart';
import 'package:moment/location/location_detail_screen.dart';
import 'package:moment/location/location_provider.dart';
import 'package:moment/location/location_section_screen.dart';
import 'package:moment/photo/create_photo_screen.dart';
import 'package:moment/photo/photo_detail_screen.dart';
import 'package:moment/photo/photo_section_screen.dart';
import 'package:moment/section/section_screen.dart';
import 'package:moment/video/create_video_screen.dart';
import 'package:moment/video/video_detail_screen.dart';
import 'package:moment/video/video_section_screen.dart';
import 'package:path/path.dart' as p;

import '../integration/shell_harness.dart';
import '../location/location_fakes.dart';
import '../video/video_fakes.dart';

/// Approved baselines for the Phase 2 and Phase 3 screens (Photo, Audio,
/// Video, Location: create, section and detail each). Rendered with the
/// test font, so they pin layout and colour rather than letterforms;
/// matching the mockups pixel for pixel is the Phase 5 fidelity pass.
/// Regenerate with `flutter test --update-goldens test/goldens`.
void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late MediaStore mediaStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('screens_golden_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
    mediaStore = MediaStore(root: tempDir, clock: () => now);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// A file that exists but is not an image: the frame stays empty, which
  /// is the same on every machine.
  String blank(String name) =>
      (File(p.join(tempDir.path, name))..writeAsStringSync('fake')).path;

  Future<void> expectBaseline(
    WidgetTester tester,
    Widget screen,
    String name,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: momentTheme(), home: screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await expectLater(
      find.byType(screen.runtimeType),
      matchesGoldenFile('goldens/$name.png'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  group('Photo', () {
    testWidgets('New photo', (tester) async {
      await expectBaseline(
        tester,
        CreatePhotoScreen(
          repository: repo,
          mediaStore: mediaStore,
          picker: NoPhotoPicker(),
          now: () => now,
          onSaved: (_) {},
          onClose: () {},
        ),
        'create_photo_screen',
      );
    });

    testWidgets('Photo section', (tester) async {
      for (var i = 0; i < 5; i++) {
        await repo.createPhoto(
          path: blank('$i.jpg'),
          thumbnailPath: blank('$i-thumb.jpg'),
          createdAt: now.subtract(Duration(days: i)),
        );
      }
      await expectBaseline(
        tester,
        PhotoSectionScreen(repository: repo),
        'photo_section_screen',
      );
    });

    testWidgets('Photo detail', (tester) async {
      final id = await repo.createPhoto(
        path: blank('a.jpg'),
        thumbnailPath: blank('a-thumb.jpg'),
        caption: 'Morning light on the balcony.',
        createdAt: DateTime.utc(2026, 11, 6, 8, 5),
      );
      await expectBaseline(
        tester,
        PhotoDetailScreen(
          log: await repo.getById(id) as PhotoLog,
          repository: repo,
          mediaStore: mediaStore,
          picker: NoPhotoPicker(),
          now: () => now,
        ),
        'photo_detail_screen',
      );
    });
  });

  group('Audio', () {
    const peaks = [0.2, 0.5, 0.9, 0.4, 0.7, 0.3, 0.8, 0.5, 0.6, 0.2, 0.9, 0.4];

    testWidgets('New audio', (tester) async {
      await expectBaseline(
        tester,
        CreateAudioScreen(
          repository: repo,
          mediaStore: mediaStore,
          recorder: SilentAudioRecorder(),
          now: () => now,
          onSaved: (_) {},
          onClose: () {},
        ),
        'create_audio_screen',
      );
    });

    testWidgets('Audio section', (tester) async {
      await repo.createAudio(
        path: blank('a.m4a'),
        duration: const Duration(seconds: 42),
        peaks: peaks,
        title: 'Voice note',
        createdAt: DateTime.utc(2026, 11, 6, 18, 5),
      );
      await repo.createAudio(
        path: blank('b.m4a'),
        duration: const Duration(minutes: 1, seconds: 12),
        peaks: peaks.reversed.toList(),
        title: 'Morning thoughts',
        createdAt: DateTime.utc(2026, 11, 5, 7, 15),
      );
      await expectBaseline(
        tester,
        SectionScreen(type: LogType.audio, repository: repo),
        'audio_section_screen',
      );
    });

    testWidgets('Audio detail', (tester) async {
      final id = await repo.createAudio(
        path: blank('a.m4a'),
        duration: const Duration(seconds: 42),
        peaks: peaks,
        title: 'Voice note',
        note: 'Remember to call back.',
        createdAt: DateTime.utc(2026, 11, 6, 18, 5),
      );
      await expectBaseline(
        tester,
        AudioDetailScreen(
          log: await repo.getById(id) as AudioLog,
          repository: repo,
          playback: SilentAudioPlayback(),
          now: () => now,
        ),
        'audio_detail_screen',
      );
    });
  });

  group('Video', () {
    Future<String> video(String name, Duration length, DateTime at) =>
        repo.createVideo(
          path: p.join(tempDir.path, '$name.mp4'),
          posterPath: p.join(tempDir.path, '$name-missing.jpg'),
          duration: length,
          caption: name == 'a' ? 'Walk to the station' : null,
          createdAt: at,
        );

    testWidgets('New video', (tester) async {
      await expectBaseline(
        tester,
        CreateVideoScreen(
          repository: repo,
          mediaStore: mediaStore,
          picker: FakeVideoPicker(),
          probe: FakeVideoProbe(),
          now: () => now,
          onSaved: (_) {},
          onClose: () {},
        ),
        'create_video_screen',
      );
    });

    testWidgets('Video section', (tester) async {
      await video('a', const Duration(seconds: 48), DateTime.utc(2026, 11, 6));
      await video('b', const Duration(seconds: 21), DateTime.utc(2026, 11, 5));
      await video(
        'c',
        const Duration(minutes: 1, seconds: 5),
        DateTime.utc(2026, 11, 3),
      );
      await expectBaseline(
        tester,
        VideoSectionScreen(repository: repo),
        'video_section_screen',
      );
    });

    testWidgets('Video detail', (tester) async {
      final id = await video(
        'a',
        const Duration(seconds: 48),
        DateTime.utc(2026, 11, 6, 12, 20),
      );
      await expectBaseline(
        tester,
        VideoDetailScreen(
          log: await repo.getById(id) as VideoLog,
          repository: repo,
          mediaStore: mediaStore,
          picker: FakeVideoPicker(),
          probe: FakeVideoProbe(),
          playback: FakeVideoPlaybackController(),
          now: () => now,
        ),
        'video_detail_screen',
      );
    });
  });

  group('Location', () {
    testWidgets('New location', (tester) async {
      await expectBaseline(
        tester,
        CreateLocationScreen(
          repository: repo,
          provider: FakeLocationProvider(),
          now: () => now,
          onSaved: (_) {},
          onClose: () {},
        ),
        'create_location_screen',
      );
    });

    testWidgets('New location, before access is granted', (tester) async {
      await expectBaseline(
        tester,
        CreateLocationScreen(
          repository: repo,
          provider: FakeLocationProvider(access: LocationAccess.denied),
          now: () => now,
          onSaved: (_) {},
          onClose: () {},
        ),
        'create_location_screen_no_access',
      );
    });

    testWidgets('Location section', (tester) async {
      await repo.createLocation(
        latitude: 12.9716,
        longitude: 77.5946,
        accuracyMeters: 12,
        name: 'Favourite bench',
        createdAt: DateTime.utc(2026, 11, 6, 17, 30),
      );
      await repo.createLocation(
        latitude: 12.9352,
        longitude: 77.6245,
        accuracyMeters: 8,
        name: 'Tea stall',
        createdAt: DateTime.utc(2026, 11, 5, 6, 40),
      );
      await repo.createLocation(
        latitude: 13.0108,
        longitude: 77.5551,
        createdAt: DateTime.utc(2026, 11, 3, 17, 5),
      );
      await expectBaseline(
        tester,
        LocationSectionScreen(repository: repo),
        'location_section_screen',
      );
    });

    testWidgets('Location detail', (tester) async {
      final id = await repo.createLocation(
        latitude: 12.9716,
        longitude: 77.5946,
        accuracyMeters: 12,
        name: 'Favourite bench',
        note: 'Under the big tree.',
        createdAt: DateTime.utc(2026, 11, 6, 17, 30),
      );
      await expectBaseline(
        tester,
        LocationDetailScreen(
          log: await repo.getById(id) as LocationLog,
          repository: repo,
          provider: FakeLocationProvider(),
          now: () => now,
        ),
        'location_detail_screen',
      );
    });
  });
}
