import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/round_glass_button.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/design/tokens.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/home/type_filter_chips.dart';
import 'package:moment/search/search_screen.dart';
import 'package:moment/settings/app_settings.dart';

void main() {
  late AppDatabase db;
  late LogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db);
  });

  Future<void> pump(
    WidgetTester tester, {
    AppSettings? settings,
    ValueChanged<Log>? onOpenLog,
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: SearchScreen(
          repository: repo,
          settings: settings ?? AppSettings.inMemory(),
          onOpenLog: onOpenLog ?? (_) {},
          onBack: onBack ?? () {},
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

  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();
    await tester.pump();
  }

  /// The pieces of text on screen drawn over the highlight colour.
  List<String> highlighted(WidgetTester tester) {
    final hits = <String>[];
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      rich.text.visitChildren((span) {
        if (span is TextSpan &&
            span.style?.backgroundColor == MomentTokens.standard.highlight) {
          hits.add(span.text!);
        }
        return true;
      });
    }
    return hits;
  }

  Future<void> seedBalcony() async {
    await repo.createText(
      body: 'Wrote the whole page sitting on the balcony floor.',
      createdAt: DateTime.utc(2026, 10, 26, 17, 20),
    );
    await repo.createLocation(
      latitude: 1,
      longitude: 2,
      name: 'Home balcony',
      createdAt: DateTime.utc(2026, 10, 30, 8),
    );
    await repo.createAudio(
      path: '/a.m4a',
      duration: const Duration(seconds: 42),
      peaks: const [0.1],
      title: 'Balcony thoughts',
      createdAt: DateTime.utc(2026, 11, 5, 7, 15),
    );
    await repo.createText(
      body: 'Morning light on the balcony. First coffee, no phone.',
      createdAt: DateTime.utc(2026, 11, 6, 8, 40),
    );
    await repo.createText(
      body: 'Nothing relevant',
      createdAt: DateTime.utc(2026, 11, 6, 9),
    );
  }

  testWidgets('opens ready to type, and says search stays on the device', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search your logs'), findsOneWidget);
    expect(
      find.text('Search runs on this device. Nothing is sent anywhere.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);

    await close(tester);
  });

  testWidgets('results are grouped by type, with a count, newest first', (
    tester,
  ) async {
    await seedBalcony();
    await pump(tester);

    await type(tester, 'balcony');

    expect(find.text('TEXT · 2'), findsOneWidget);
    expect(find.text('AUDIO · 1'), findsOneWidget);
    expect(find.text('LOCATION · 1'), findsOneWidget);
    expect(find.text('PHOTO · 0'), findsNothing);
    expect(find.text('Fri 6 Nov · 08:40'), findsOneWidget);
    expect(find.text('Mon 26 Oct · 17:20'), findsOneWidget);
    expect(find.text('Thu 5 Nov · 07:15'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Fri 6 Nov · 08:40')).dy,
      lessThan(tester.getTopLeft(find.text('Mon 26 Oct · 17:20')).dy),
    );
    expect(
      tester.getTopLeft(find.text('TEXT · 2')).dy,
      lessThan(tester.getTopLeft(find.text('AUDIO · 1')).dy),
    );
    expect(find.textContaining('Nothing relevant'), findsNothing);

    await close(tester);
  });

  testWidgets('the matched words are highlighted in each result', (
    tester,
  ) async {
    await seedBalcony();
    await pump(tester);

    await type(tester, 'balc');

    expect(highlighted(tester), ['balc', 'balc', 'Balc', 'balc']);

    await close(tester);
  });

  testWidgets('results follow the typing', (tester) async {
    await seedBalcony();
    await pump(tester);

    await type(tester, 'balcony');
    expect(find.text('TEXT · 2'), findsOneWidget);

    await type(tester, 'balcony coffee');
    expect(find.text('TEXT · 1'), findsOneWidget);
    expect(find.text('AUDIO · 1'), findsNothing);

    await close(tester);
  });

  testWidgets('a type filter keeps only that type', (tester) async {
    await seedBalcony();
    await pump(tester);
    await type(tester, 'balcony');

    await tester.tap(
      find.descendant(
        of: find.byType(TypeFilterChips),
        matching: find.text('Text'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('TEXT · 2'), findsOneWidget);
    expect(find.text('AUDIO · 1'), findsNothing);
    expect(find.text('LOCATION · 1'), findsNothing);

    await close(tester);
  });

  testWidgets('says so when nothing matches', (tester) async {
    await seedBalcony();
    await pump(tester);

    await type(tester, 'zebra');

    expect(find.text('Nothing matches “zebra”.'), findsOneWidget);

    await close(tester);
  });

  testWidgets('logs in Trash are never found', (tester) async {
    final id = await repo.createText(body: 'balcony, deleted');
    await repo.softDelete(id);
    await pump(tester);

    await type(tester, 'balcony');

    expect(find.text('Nothing matches “balcony”.'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the clear button empties the search', (tester) async {
    await seedBalcony();
    await pump(tester);
    expect(find.bySemanticsLabel('Clear search'), findsNothing);

    await type(tester, 'balcony');
    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text('TEXT · 2'), findsNothing);

    await close(tester);
  });

  testWidgets('opening a result reports it and remembers the search', (
    tester,
  ) async {
    await seedBalcony();
    final settings = AppSettings.inMemory();
    Log? opened;
    await pump(tester, settings: settings, onOpenLog: (log) => opened = log);
    await type(tester, 'balcony');

    await tester.tap(find.text('Thu 5 Nov · 07:15'));
    await tester.pump();

    expect(opened, isA<AudioLog>());
    expect(settings.recentSearches, ['balcony']);

    await close(tester);
  });

  testWidgets('submitting from the keyboard remembers the search', (
    tester,
  ) async {
    final settings = AppSettings.inMemory();
    await pump(tester, settings: settings);
    await type(tester, 'train');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(settings.recentSearches, ['train']);

    await close(tester);
  });

  testWidgets('recent searches show while the field is empty and run again', (
    tester,
  ) async {
    await seedBalcony();
    final settings = AppSettings.inMemory({
      'recentSearches': ['balcony', 'train'],
    });
    await pump(tester, settings: settings);

    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('train'), findsOneWidget);

    await tester.tap(find.text('balcony'));
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'balcony',
    );
    expect(find.text('TEXT · 2'), findsOneWidget);
    expect(find.text('RECENT'), findsNothing);

    await close(tester);
  });

  testWidgets('recent searches can be cleared', (tester) async {
    final settings = AppSettings.inMemory({
      'recentSearches': ['balcony'],
    });
    await pump(tester, settings: settings);

    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(settings.recentSearches, isEmpty);
    expect(find.text('RECENT'), findsNothing);

    await close(tester);
  });

  testWidgets('Back calls onBack', (tester) async {
    var back = false;
    await pump(tester, onBack: () => back = true);

    await tester.tap(find.widgetWithIcon(RoundGlassButton, Icons.chevron_left));

    expect(back, isTrue);

    await close(tester);
  });
}
