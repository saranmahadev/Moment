import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/location/location_detail_screen.dart';
import 'package:moment/location/location_provider.dart';
import 'package:moment/location/place_map.dart';
import 'package:moment/location/stylised_map.dart';
import 'map/fake_map_source.dart';

import 'location_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late AppDatabase db;
  late LogRepository repo;
  late LocationLog log;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
    final id = await repo.createLocation(
      latitude: 12.971598765432101,
      longitude: 77.59456234567891,
      accuracyMeters: 12,
      name: 'Favourite bench',
      createdAt: DateTime.utc(2026, 11, 6, 17, 30),
    );
    log = await repo.getById(id) as LocationLog;
  });

  Future<void> pump(
    WidgetTester tester, {
    FakeLocationProvider? provider,
    LocationLog? log_,
    VoidCallback? onBack,
    FakeMapSource? mapSource,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: LocationDetailScreen(
          log: log_ ?? log,
          repository: repo,
          provider: provider ?? FakeLocationProvider(),
          now: () => now,
          onBack: onBack ?? () {},
          mapSource: mapSource,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  Future<LocationLog> stored() async =>
      await repo.getById(log.id) as LocationLog;

  testWidgets('shows when, where and how accurately it was pinned', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Friday 6 November · 17:30'), findsOneWidget);
    expect(find.text('Favourite bench'), findsOneWidget);
    expect(find.text('12.97160° N, 77.59456° E'), findsOneWidget);
    expect(find.text('Accuracy ±12 m'), findsOneWidget);
    expect(find.text('Coordinates stored on this device'), findsOneWidget);

    await close(tester);
  });

  testWidgets('shows the place on the bundled map, with zoom buttons', (
    tester,
  ) async {
    final source = FakeMapSource();
    await pump(tester, mapSource: source);

    final map = tester.widget<PlaceMap>(find.byType(PlaceMap));
    expect(map.latitude, log.latitude);
    expect(map.longitude, log.longitude);
    expect(map.zoomable, isTrue);
    expect(find.byType(StylisedMap), findsNothing);
    expect(find.bySemanticsLabel('Zoom to City'), findsOneWidget);

    await close(tester);
  });

  testWidgets('without a map source it keeps the plain tile', (tester) async {
    await pump(tester);

    expect(find.byType(StylisedMap), findsOneWidget);
    expect(find.byType(PlaceMap), findsNothing);

    await close(tester);
  });

  testWidgets('a place with no name or accuracy shows neither', (tester) async {
    final id = await repo.createLocation(latitude: 1, longitude: 2);
    final bare = await repo.getById(id) as LocationLog;
    await pump(tester, log_: bare);

    expect(find.text('Pinned place'), findsOneWidget);
    expect(find.textContaining('Accuracy'), findsNothing);

    await close(tester);
  });

  testWidgets('Copy coordinates puts them on the clipboard and says so', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester);

    await tester.tap(find.text('Copy coordinates'));
    await tester.pump();

    expect(copied, '12.971599, 77.594562');
    expect(find.text('Coordinates copied'), findsOneWidget);

    await close(tester);
  });

  testWidgets('Edit lets the name and note be changed, Save stores them', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('place-name')),
      'The bench',
    );
    await tester.enterText(
      find.byKey(const ValueKey('place-note')),
      'Under the big tree',
    );
    await tester.tap(find.bySemanticsLabel('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('The bench'), findsOneWidget);
    expect(find.text('Under the big tree'), findsOneWidget);
    final after = await stored();
    expect(after.name, 'The bench');
    expect(after.note, 'Under the big tree');
    expect(after.latitude, log.latitude);

    await close(tester);
  });

  testWidgets('clearing the name removes it', (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('place-name')), '');
    await tester.tap(find.bySemanticsLabel('Save'));
    await tester.pump();
    await tester.pump();

    expect((await stored()).name, isNull);
    expect(find.text('Pinned place'), findsOneWidget);

    await close(tester);
  });

  group('Move pin', () {
    testWidgets('to the current position stores the new fix', (tester) async {
      final provider = FakeLocationProvider(
        fix: const LocationFix(
          latitude: -33.8688,
          longitude: 151.2093,
          accuracyMeters: 6,
        ),
      );
      await pump(tester, provider: provider);

      await tester.tap(find.text('Move pin'));
      await tester.pump();
      await tester.tap(find.text('Use current position'));
      await tester.pump();
      await tester.pump();

      final after = await stored();
      expect(after.latitude, -33.8688);
      expect(after.longitude, 151.2093);
      expect(after.accuracyMeters, 6);
      expect(after.name, 'Favourite bench');
      expect(find.text('33.86880° S, 151.20930° E'), findsOneWidget);
      expect(find.text('Accuracy ±6 m'), findsOneWidget);

      await close(tester);
    });

    testWidgets('to typed coordinates stores them without an accuracy', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Move pin'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('coordinates-field')),
        '48.8584, 2.2945',
      );
      await tester.tap(find.text('Use these coordinates'));
      await tester.pump();
      await tester.pump();

      final after = await stored();
      expect(after.latitude, 48.8584);
      expect(after.longitude, 2.2945);
      expect(after.accuracyMeters, isNull);
      expect(find.textContaining('Accuracy'), findsNothing);

      await close(tester);
    });

    testWidgets('asks for access first, and explains when it is refused', (
      tester,
    ) async {
      final provider = FakeLocationProvider(
        access: LocationAccess.deniedForever,
      );
      await pump(tester, provider: provider);

      await tester.tap(find.text('Move pin'));
      await tester.pump();
      await tester.tap(find.text('Use current position'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Location access is turned off for Moment. Turn it on in '
          'Settings, or enter coordinates instead.',
        ),
        findsOneWidget,
      );
      expect((await stored()).latitude, log.latitude);

      await close(tester);
    });

    testWidgets('Cancel leaves the pin where it was', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Move pin'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.byKey(const ValueKey('coordinates-field')), findsNothing);
      expect((await stored()).latitude, log.latitude);

      await close(tester);
    });
  });

  testWidgets('Delete soft-deletes the log and calls onBack', (tester) async {
    var backed = false;
    await pump(tester, onBack: () => backed = true);

    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();

    expect(backed, isTrue);
    expect((await stored()).deletedAt, isNotNull);

    await close(tester);
  });

  testWidgets('the back button calls onBack', (tester) async {
    var backed = false;
    await pump(tester, onBack: () => backed = true);

    await tester.tap(find.bySemanticsLabel('Back'));

    expect(backed, isTrue);

    await close(tester);
  });
}
