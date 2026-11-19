import 'dart:async';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/location/create_location_screen.dart';
import 'package:moment/location/location_provider.dart';

import 'map/fake_map_source.dart';
import 'package:moment/location/place_map.dart';
import 'package:moment/location/stylised_map.dart';
import 'location_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late AppDatabase db;
  late LogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
  });

  Future<void> pump(
    WidgetTester tester,
    FakeLocationProvider provider, {
    ValueChanged<String>? onSaved,
    VoidCallback? onClose,
    FakePlaceNameLookup? placeNames,
    FakeMapSource? mapSource,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: CreateLocationScreen(
          repository: repo,
          provider: provider,
          placeNames: placeNames,
          mapSource: mapSource,
          now: () => now,
          onSaved: onSaved ?? (_) {},
          onClose: onClose ?? () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  Future<LocationLog> savedLog(String id) async =>
      await repo.getById(id) as LocationLog;

  group('the map', () {
    testWidgets('shows the locked-on spot on the bundled map', (tester) async {
      await pump(tester, FakeLocationProvider(), mapSource: FakeMapSource());

      final map = tester.widget<PlaceMap>(find.byType(PlaceMap));
      expect(map.latitude, isNotNull);
      expect(map.zoomable, isFalse);
      expect(find.byType(StylisedMap), findsNothing);

      await close(tester);
    });

    testWidgets('before there is a spot, or with no source, the plain tile', (
      tester,
    ) async {
      await pump(tester, FakeLocationProvider(), mapSource: null);

      expect(find.byType(PlaceMap), findsNothing);
      expect(find.byType(StylisedMap), findsOneWidget);

      await close(tester);
    });
  });

  group('with location access', () {
    testWidgets('locks on to the current position when it opens', (
      tester,
    ) async {
      final provider = FakeLocationProvider();
      await pump(tester, provider);

      expect(provider.requests, 0);
      expect(provider.fixes, 1);
      expect(find.text('Pin this spot'), findsOneWidget);
      expect(find.text('Locked on'), findsOneWidget);
      expect(find.text('Accuracy ±12 m · Sat 7 Nov · 10:00'), findsOneWidget);
      expect(find.textContaining('Nothing is looked up online'), findsNothing);
      expect(find.text('Move pin'), findsOneWidget);
      expect(find.text('Save location'), findsOneWidget);

      await close(tester);
    });

    testWidgets('Save stores the exact position, accuracy and name', (
      tester,
    ) async {
      final provider = FakeLocationProvider();
      String? savedId;
      await pump(tester, provider, onSaved: (id) => savedId = id);

      await tester.enterText(
        find.byKey(const ValueKey('place-name')),
        'Favourite bench',
      );
      await tester.tap(find.text('Save location'));
      await tester.pump();
      await tester.pump();

      final log = await savedLog(savedId!);
      expect(log.latitude, 12.971598765432101);
      expect(log.longitude, 77.59456234567891);
      expect(log.accuracyMeters, 12);
      expect(log.name, 'Favourite bench');
      expect(log.createdAt, now);

      await close(tester);
    });

    testWidgets('a blank name is saved as no name', (tester) async {
      String? savedId;
      await pump(tester, FakeLocationProvider(), onSaved: (id) => savedId = id);

      await tester.tap(find.text('Save location'));
      await tester.pump();
      await tester.pump();

      expect((await savedLog(savedId!)).name, isNull);

      await close(tester);
    });

    testWidgets('the recentre button reads the position again', (tester) async {
      final provider = FakeLocationProvider();
      await pump(tester, provider);

      provider.fix = const LocationFix(
        latitude: 1,
        longitude: 2,
        accuracyMeters: 5,
      );
      await tester.tap(find.bySemanticsLabel('Use current position'));
      await tester.pump();
      await tester.pump();

      expect(provider.fixes, 2);
      expect(find.text('Accuracy ±5 m · Sat 7 Nov · 10:00'), findsOneWidget);

      await close(tester);
    });

    testWidgets('Move pin takes typed coordinates in place of the fix', (
      tester,
    ) async {
      String? savedId;
      await pump(tester, FakeLocationProvider(), onSaved: (id) => savedId = id);

      await tester.tap(find.text('Move pin'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('coordinates-field')),
        '48.858370123456789, 2.2944813',
      );
      await tester.tap(find.text('Use these coordinates'));
      await tester.pump();

      expect(
        find.text('Typed coordinates · Sat 7 Nov · 10:00'),
        findsOneWidget,
      );
      expect(find.text('Locked on'), findsNothing);

      await tester.tap(find.text('Save location'));
      await tester.pump();
      await tester.pump();

      final log = await savedLog(savedId!);
      expect(log.latitude, 48.858370123456789);
      expect(log.longitude, 2.2944813);
      expect(log.accuracyMeters, isNull);

      await close(tester);
    });

    testWidgets('coordinates that make no sense are refused with a hint', (
      tester,
    ) async {
      await pump(tester, FakeLocationProvider());

      await tester.tap(find.text('Move pin'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('coordinates-field')),
        'somewhere nice',
      );
      await tester.tap(find.text('Use these coordinates'));
      await tester.pump();

      expect(
        find.text('Enter a latitude and longitude, like 12.9716, 77.5946'),
        findsOneWidget,
      );
      expect(find.text('Locked on'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Locked on'), findsOneWidget);

      await close(tester);
    });
  });

  group('without location access', () {
    testWidgets('explains before asking, and asks only when told to', (
      tester,
    ) async {
      final provider = FakeLocationProvider(
        access: LocationAccess.denied,
        afterRequest: LocationAccess.granted,
      );
      await pump(tester, provider);

      expect(provider.requests, 0);
      expect(provider.fixes, 0);
      expect(
        find.text('Moment uses your location only to pin this spot.'),
        findsOneWidget,
      );
      expect(find.text('Save location'), findsNothing);

      await tester.tap(find.text('Allow location'));
      await tester.pump();
      await tester.pump();

      expect(provider.requests, 1);
      expect(find.text('Locked on'), findsOneWidget);
      expect(find.text('Save location'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a refusal keeps the explanation and offers coordinates', (
      tester,
    ) async {
      final provider = FakeLocationProvider(access: LocationAccess.denied);
      await pump(tester, provider);

      await tester.tap(find.text('Allow location'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Locked on'), findsNothing);
      expect(find.text('Allow location'), findsOneWidget);
      expect(find.text('Enter coordinates'), findsOneWidget);

      await close(tester);
    });

    testWidgets('access revoked in Settings says so and links to Settings', (
      tester,
    ) async {
      final provider = FakeLocationProvider(
        access: LocationAccess.deniedForever,
      );
      await pump(tester, provider);

      expect(
        find.text(
          'Location access is turned off for Moment. Turn it on in '
          'Settings, or enter coordinates instead.',
        ),
        findsOneWidget,
      );
      expect(find.text('Allow location'), findsNothing);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();

      expect(provider.settingsOpened, 1);
      expect(provider.requests, 0);

      await close(tester);
    });

    testWidgets('location switched off for the device says so', (tester) async {
      await pump(
        tester,
        FakeLocationProvider(access: LocationAccess.serviceOff),
      );

      expect(
        find.text(
          'Location is turned off on this device. Turn it on, or enter '
          'coordinates instead.',
        ),
        findsOneWidget,
      );
      expect(find.text('Enter coordinates'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a place can still be pinned by typing coordinates', (
      tester,
    ) async {
      String? savedId;
      await pump(
        tester,
        FakeLocationProvider(access: LocationAccess.deniedForever),
        onSaved: (id) => savedId = id,
      );

      await tester.tap(find.text('Enter coordinates'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('coordinates-field')),
        '33.8688 S, 151.2093 E',
      );
      await tester.tap(find.text('Use these coordinates'));
      await tester.pump();
      await tester.tap(find.text('Save location'));
      await tester.pump();
      await tester.pump();

      final log = await savedLog(savedId!);
      expect(log.latitude, -33.8688);
      expect(log.longitude, 151.2093);

      await close(tester);
    });
  });

  group('with place names turned on', () {
    const typedByYou =
        'Place names are typed by you. Nothing is looked up online.';

    testWidgets('suggests a name for the spot it locked on to', (tester) async {
      final names = FakePlaceNameLookup(name: 'Cubbon Park');
      String? savedId;
      await pump(
        tester,
        FakeLocationProvider(),
        placeNames: names,
        onSaved: (id) => savedId = id,
      );
      await tester.pump();

      expect(names.asked, [(12.971598765432101, 77.59456234567891)]);
      expect(find.text('Cubbon Park'), findsOneWidget);
      expect(
        find.text('Name suggested by OpenStreetMap. Change it if you like.'),
        findsOneWidget,
      );
      expect(find.text(typedByYou), findsNothing);

      await tester.tap(find.text('Save location'));
      await tester.pump();
      await tester.pump();
      expect((await savedLog(savedId!)).name, 'Cubbon Park');

      await close(tester);
    });

    testWidgets('the suggestion can be replaced before saving', (tester) async {
      String? savedId;
      await pump(
        tester,
        FakeLocationProvider(),
        placeNames: FakePlaceNameLookup(),
        onSaved: (id) => savedId = id,
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('place-name')),
        'Favourite bench',
      );
      await tester.tap(find.text('Save location'));
      await tester.pump();
      await tester.pump();

      expect((await savedLog(savedId!)).name, 'Favourite bench');

      await close(tester);
    });

    testWidgets('says so when no name was found, and still saves', (
      tester,
    ) async {
      String? savedId;
      await pump(
        tester,
        FakeLocationProvider(),
        placeNames: FakePlaceNameLookup(name: null),
        onSaved: (id) => savedId = id,
      );
      await tester.pump();

      expect(
        find.text('No name was found online. Type one if you like.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Save location'));
      await tester.pump();
      await tester.pump();
      expect((await savedLog(savedId!)).name, isNull);

      await close(tester);
    });

    testWidgets('typed coordinates are looked up too', (tester) async {
      final names = FakePlaceNameLookup(name: 'Hampi');
      await pump(
        tester,
        FakeLocationProvider(access: LocationAccess.deniedForever),
        placeNames: names,
      );

      await tester.tap(find.text('Enter coordinates'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('coordinates-field')),
        '15.335, 76.46',
      );
      await tester.tap(find.text('Use these coordinates'));
      await tester.pump();
      await tester.pump();

      expect(names.asked, [(15.335, 76.46)]);
      expect(find.text('Hampi'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a name already typed is never overwritten', (tester) async {
      final names = FakePlaceNameLookup(name: 'First');
      final provider = FakeLocationProvider();
      await pump(tester, provider, placeNames: names);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('place-name')),
        'My own name',
      );

      names.name = 'Second';
      provider.fix = const LocationFix(latitude: 1, longitude: 2);
      await tester.tap(find.bySemanticsLabel('Use current position'));
      await tester.pump();
      await tester.pump();

      expect(names.asked, hasLength(2));
      expect(find.text('My own name'), findsOneWidget);
      expect(find.text('Second'), findsNothing);

      await close(tester);
    });
  });

  testWidgets('Close calls onClose without creating a log', (tester) async {
    var closed = false;
    await pump(tester, FakeLocationProvider(), onClose: () => closed = true);

    await tester.tap(find.bySemanticsLabel('Close without saving'));

    expect(closed, isTrue);
    expect(await db.select(db.logsTable).get(), isEmpty);

    await close(tester);
  });

  testWidgets('pinning and naming a place opens no network connection', (
    tester,
  ) async {
    var connections = 0;
    await HttpOverrides.runZoned(
      () async {
        String? savedId;
        await pump(
          tester,
          FakeLocationProvider(),
          onSaved: (id) => savedId = id,
        );
        await tester.enterText(
          find.byKey(const ValueKey('place-name')),
          'Tea stall',
        );
        await tester.tap(find.text('Save location'));
        await tester.pump();
        await tester.pump();

        expect((await savedLog(savedId!)).name, 'Tea stall');
      },
      createHttpClient: (_) {
        connections++;
        throw StateError('Moment must not open network connections');
      },
    );

    expect(connections, 0);

    await close(tester);
  });

  testWidgets('a position that cannot be found offers a retry and typing', (
    tester,
  ) async {
    final provider = FakeLocationProvider()
      ..failWith = TimeoutException('no fix');
    await pump(tester, provider);

    expect(find.text('Finding where you are…'), findsNothing);
    expect(
      find.text(
        'Could not find where you are. Try again, or enter coordinates.',
      ),
      findsOneWidget,
    );
    expect(find.text('Enter coordinates'), findsOneWidget);

    provider.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Locked on'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
