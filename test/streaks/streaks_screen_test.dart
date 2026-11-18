import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/streaks/heatmap_model.dart';
import 'package:moment/streaks/streaks_screen.dart';

void main() {
  // Friday 6 November 2026, late evening.
  final now = DateTime.utc(2026, 11, 6, 22);
  late AppDatabase db;
  late LogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
  });

  Future<void> logOn(int month, int day, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await repo.createText(
        body: 'log $i',
        createdAt: DateTime.utc(2026, month, day, 9 + i),
      );
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    AppSettings? settings,
    VoidCallback? onBack,
    VoidCallback? onOpenSettings,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: StreaksScreen(
          repository: repo,
          settings: settings ?? AppSettings.inMemory(),
          now: () => now,
          onBack: onBack ?? () {},
          onOpenSettings: onOpenSettings ?? () {},
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

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  /// Nov 2 to 6 with 5 missed: five days with one forgiven.
  Future<void> seed() async {
    await logOn(11, 2);
    await logOn(11, 3, times: 2);
    await logOn(11, 4);
    await logOn(11, 6);
  }

  Finder text(Key key, String value) =>
      find.descendant(of: find.byKey(key), matching: find.text(value));

  group('hero', () {
    testWidgets('shows the streak, what makes it up and today', (tester) async {
      await seed();
      await pump(tester);

      expect(text(const ValueKey('streaks-count'), '5'), findsOneWidget);
      expect(find.text('day streak'), findsOneWidget);
      expect(find.text('4 days logged · 1 grace day used'), findsOneWidget);
      expect(find.text('Logged today'), findsOneWidget);
      await close(tester);
    });

    testWidgets('says when today is still open', (tester) async {
      await logOn(11, 3);
      await logOn(11, 4);
      await logOn(11, 5);
      await pump(tester);

      expect(find.text('Not logged yet today'), findsOneWidget);
      expect(text(const ValueKey('streaks-count'), '3'), findsOneWidget);
      await close(tester);
    });

    testWidgets('with nothing logged it starts from zero, gently', (
      tester,
    ) async {
      await pump(tester);

      expect(text(const ValueKey('streaks-count'), '0'), findsOneWidget);
      expect(find.text('Log anything today to start one.'), findsOneWidget);
      expect(find.text('Logged today'), findsNothing);
      await close(tester);
    });

    testWidgets('the week strip names each day', (tester) async {
      await seed();
      await pump(tester);
      final handle = tester.ensureSemantics();

      expect(
        find.bySemanticsLabel('Monday 2 November, logged'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Thursday 5 November, grace day'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Friday 6 November, today, logged'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Saturday 7 November, not yet'),
        findsOneWidget,
      );
      handle.dispose();
      await close(tester);
    });
  });

  group('stats', () {
    testWidgets('longest, days logged and this month', (tester) async {
      await seed();
      await logOn(10, 1);
      await pump(tester);

      expect(text(const ValueKey('streaks-longest'), '5'), findsOneWidget);
      expect(text(const ValueKey('streaks-days-logged'), '5'), findsOneWidget);
      expect(text(const ValueKey('streaks-month-days'), '4'), findsOneWidget);
      expect(find.text('Days logged in November'), findsOneWidget);
      await close(tester);
    });
  });

  group('activity heatmap', () {
    Finder heatmap() => find.byKey(const ValueKey('streaks-heatmap'));

    testWidgets('opens on today with its count', (tester) async {
      await seed();
      await pump(tester);
      await show(tester, heatmap());

      expect(
        find.byKey(const ValueKey('streaks-selected-day')),
        findsOneWidget,
      );
      expect(
        text(const ValueKey('streaks-selected-day'), 'Fri 6 Nov'),
        findsOneWidget,
      );
      expect(find.textContaining('1 log'), findsWidgets);
      await close(tester);
    });

    testWidgets('a tap on a day shows what it holds', (tester) async {
      await seed();
      await pump(tester);
      await show(tester, heatmap());
      final layout = HeatmapLayout.forWidth(
        tester.getSize(heatmap()).width,
        26,
      );

      // Tuesday 3 November has two logs.
      await tester.tapAt(
        tester.getTopLeft(heatmap()) + layout.cellRect(25, 1).center,
      );
      await tester.pump();

      expect(
        text(const ValueKey('streaks-selected-day'), 'Tue 3 Nov'),
        findsOneWidget,
      );
      expect(find.textContaining('2 logs'), findsWidgets);

      // Thursday 5 November was missed and forgiven.
      await tester.tapAt(
        tester.getTopLeft(heatmap()) + layout.cellRect(25, 3).center,
      );
      await tester.pump();
      expect(find.textContaining('Grace day'), findsWidgets);
      await close(tester);
    });

    testWidgets('a tap on a day after today does nothing', (tester) async {
      await seed();
      await pump(tester);
      await show(tester, heatmap());
      final layout = HeatmapLayout.forWidth(
        tester.getSize(heatmap()).width,
        26,
      );

      await tester.tapAt(
        tester.getTopLeft(heatmap()) + layout.cellRect(25, 5).center,
      );
      await tester.pump();

      expect(
        text(const ValueKey('streaks-selected-day'), 'Fri 6 Nov'),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('one slider for a screen reader steps day by day', (
      tester,
    ) async {
      await seed();
      await pump(tester);
      await show(tester, heatmap());
      final handle = tester.ensureSemantics();

      expect(
        tester.getSemantics(heatmap()),
        matchesSemantics(
          label: 'Activity',
          value: 'Friday 6 November, 1 log',
          isSlider: true,
          hasIncreaseAction: false,
          hasDecreaseAction: true,
          increasedValue: '',
          decreasedValue: 'Thursday 5 November, grace day',
        ),
      );

      tester.semantics.performAction(heatmap(), SemanticsAction.decrease);
      await tester.pump();
      expect(
        text(const ValueKey('streaks-selected-day'), 'Thu 5 Nov'),
        findsOneWidget,
      );
      handle.dispose();
      await close(tester);
    });

    testWidgets('the range buttons switch between months and a year', (
      tester,
    ) async {
      await seed();
      await pump(tester);
      await show(tester, heatmap());
      final sixMonths = tester.getSize(heatmap()).width;

      await tester.tap(find.byKey(const ValueKey('streaks-range-12')));
      await tester.pump();
      expect(tester.getSize(heatmap()).width, greaterThan(sixMonths));

      await tester.tap(find.byKey(const ValueKey('streaks-range-3')));
      await tester.pump();
      expect(tester.getSize(heatmap()).width, closeTo(sixMonths, 0.5));
      await close(tester);
    });

    testWidgets('the legend explains the squares', (tester) async {
      await seed();
      await pump(tester);
      await show(tester, find.text('Grace day'));

      expect(find.text('Fewer'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Grace day'), findsOneWidget);
      await close(tester);
    });
  });

  group('milestones', () {
    testWidgets('a reached one carries its date, the next shows progress', (
      tester,
    ) async {
      await seed();
      await pump(tester);
      await show(tester, find.byKey(const ValueKey('milestone-7')));
      final handle = tester.ensureSemantics();

      expect(find.text('1 of 8'), findsOneWidget);
      expect(text(const ValueKey('milestone-3'), '4 Nov 2026'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Milestone 3 days, reached 4 November 2026'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Milestone 7 days, not yet, best so far 5'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Milestone 365 days, not yet'),
        findsOneWidget,
      );
      handle.dispose();
      await close(tester);
    });

    testWidgets('all eight are listed', (tester) async {
      await pump(tester);
      await show(tester, find.byKey(const ValueKey('milestone-365')));

      for (final days in [3, 7, 14, 30, 60, 100, 200, 365]) {
        expect(find.byKey(ValueKey('milestone-$days')), findsOneWidget);
      }
      expect(find.text('0 of 8'), findsOneWidget);
      await close(tester);
    });
  });

  group('header', () {
    testWidgets('Back and Streak settings call their callbacks', (
      tester,
    ) async {
      var back = 0;
      var settings = 0;
      await pump(
        tester,
        onBack: () => back++,
        onOpenSettings: () => settings++,
      );

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.tap(find.bySemanticsLabel('Streak settings'));

      expect(back, 1);
      expect(settings, 1);
      await close(tester);
    });

    testWidgets('follows the grace setting at once', (tester) async {
      await seed();
      final settings = AppSettings.inMemory({'graceDays': 0});
      await pump(tester, settings: settings);
      expect(text(const ValueKey('streaks-count'), '1'), findsOneWidget);

      await settings.setGraceDays(1);
      await tester.pump();
      await tester.pump();

      expect(text(const ValueKey('streaks-count'), '5'), findsOneWidget);
      await close(tester);
    });
  });
}
