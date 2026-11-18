import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/library/log_filter.dart';
import 'package:moment/location/location_section_screen.dart';
import 'package:moment/location/stylised_map.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late AppDatabase db;
  late LogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
  });

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onBack,
    ValueChanged<Log>? onOpenLog,
    LogFilter filter = const LogFilter(),
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: LocationSectionScreen(
          repository: repo,
          onBack: onBack,
          onOpenLog: onOpenLog,
          filter: filter,
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

  testWidgets('shows the type name and log count', (tester) async {
    await repo.createLocation(latitude: 1, longitude: 2);
    await repo.createLocation(latitude: 3, longitude: 4);

    await pump(tester);

    expect(find.text('Location'), findsOneWidget);
    expect(find.text('2 logs'), findsOneWidget);

    await close(tester);
  });

  testWidgets('a filter keeps only the named places, on the map too', (
    tester,
  ) async {
    await repo.createLocation(latitude: 1, longitude: 2, name: 'Bench');
    await repo.createLocation(latitude: 3, longitude: 4);

    await pump(tester, filter: const LogFilter(onlyNamed: true));

    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('Showing 1 of 2'), findsOneWidget);
    expect(
      tester.widget<StylisedMap>(find.byType(StylisedMap)).pins,
      hasLength(1),
    );

    await close(tester);
  });

  testWidgets('the map shows one pin per place', (tester) async {
    await repo.createLocation(latitude: 1, longitude: 2);
    await repo.createLocation(latitude: 3, longitude: 4);
    await repo.createLocation(latitude: 5, longitude: 1);

    await pump(tester);

    expect(
      tester.widget<StylisedMap>(find.byType(StylisedMap)).pins,
      hasLength(3),
    );

    await close(tester);
  });

  testWidgets('each row shows the name, when it was pinned and the accuracy', (
    tester,
  ) async {
    final id = await repo.createLocation(
      latitude: 12.9716,
      longitude: 77.5946,
      accuracyMeters: 12,
      name: 'Favourite bench',
      createdAt: DateTime.utc(2026, 11, 6, 17, 30),
    );

    await pump(tester);

    expect(find.byKey(ValueKey('location-row-$id')), findsOneWidget);
    expect(find.text('Favourite bench'), findsOneWidget);
    expect(find.text('Fri 6 Nov · 17:30'), findsOneWidget);
    expect(find.text('±12 m'), findsOneWidget);

    await close(tester);
  });

  testWidgets('an unnamed place shows its coordinates, and typed ones no '
      'accuracy', (tester) async {
    await repo.createLocation(latitude: 12.9716, longitude: 77.5946);

    await pump(tester);

    expect(find.text('12.97160° N, 77.59460° E'), findsOneWidget);
    expect(find.textContaining('±'), findsNothing);

    await close(tester);
  });

  testWidgets('tapping a row reports the log', (tester) async {
    final id = await repo.createLocation(
      latitude: 1,
      longitude: 2,
      name: 'Tea stall',
    );
    Log? opened;

    await pump(tester, onOpenLog: (log) => opened = log);
    await tester.tap(find.text('Tea stall'));

    expect(opened, isA<LocationLog>());
    expect(opened!.id, id);

    await close(tester);
  });

  testWidgets('trashed places are not shown or pinned', (tester) async {
    final id = await repo.createLocation(
      latitude: 1,
      longitude: 2,
      name: 'Gone',
    );
    await repo.softDelete(id);

    await pump(tester);

    expect(find.text('Gone'), findsNothing);
    expect(tester.widget<StylisedMap>(find.byType(StylisedMap)).pins, isEmpty);

    await close(tester);
  });

  testWidgets('the back button calls onBack', (tester) async {
    var backed = false;
    await pump(tester, onBack: () => backed = true);

    await tester.tap(find.byKey(const ValueKey('location-section-back')));

    expect(backed, isTrue);

    await close(tester);
  });
}
