import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/app_info.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/settings/about_screen.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/settings/media_quality.dart';
import 'package:moment/settings/quick_emoji_screen.dart';
import 'package:moment/settings/reminder_scheduler.dart';
import 'package:moment/settings/settings_screen.dart';

class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.allowed = true});

  bool allowed;
  final enabledAt = <TimeOfDay>[];
  int disabled = 0;

  @override
  Future<bool> enable(TimeOfDay time) async {
    if (!allowed) return false;
    enabledAt.add(time);
    return true;
  }

  @override
  Future<void> disable() async => disabled++;
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    VoidCallback? onOpenPrivacy,
    VoidCallback? onOpenTrash,
    AppSettings? settings,
    FakeReminderScheduler? reminders,
    TimeOfDay? pickedTime,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: SettingsScreen(
          repository: repo,
          settings: settings ?? AppSettings.inMemory(),
          reminders: reminders ?? FakeReminderScheduler(),
          pickTime: (context, initial) async => pickedTime,
          onOpenPrivacy: onOpenPrivacy ?? () {},
          onOpenTrash: onOpenTrash ?? () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the title and every section label', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db);

    await pump(tester, repo);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('YOUR DATA'), findsOneWidget);
    expect(find.text('LOGGING'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('ABOUT'), 300);
    await tester.pump();
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping Privacy and backup calls onOpenPrivacy', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db);
    var opened = false;

    await pump(tester, repo, onOpenPrivacy: () => opened = true);
    await tester.tap(find.text('Privacy and backup'));

    expect(opened, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Trash shows the current trash count and calls onOpenTrash', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db);
    final id = await repo.createText(body: 'Gone');
    await repo.softDelete(id);
    var opened = false;

    await pump(tester, repo, onOpenTrash: () => opened = true);
    await tester.pump();

    expect(find.text('1 log'), findsOneWidget);

    await tester.tap(find.text('Trash'));
    expect(opened, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  group('with a library open', () {
    late AppDatabase db;
    late LogRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = LogRepository(db);
    });

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    }

    Future<void> show(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
      await tester.pump();
    }

    testWidgets('shows every row with its current value', (tester) async {
      await pump(
        tester,
        repo,
        settings: AppSettings.inMemory({
          'themeMode': 'dark',
          'mediaQuality': 'high',
          'reminderOn': true,
          'reminderMinutes': 7 * 60 + 5,
        }),
      );

      expect(find.text('Quick emoji row'), findsOneWidget);
      expect(find.text('Evening reminder'), findsOneWidget);
      expect(find.text('Local notification at 07:05'), findsOneWidget);
      await show(tester, find.text('Video and photo quality'));
      expect(find.text('High'), findsOneWidget);
      await show(tester, find.text('Theme'));
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Reduce transparency'), findsOneWidget);
      await show(tester, find.text('Version'));
      expect(find.text('How Moment stays local'), findsOneWidget);
      expect(find.text(appVersion), findsOneWidget);

      await close(tester);
    });

    group('Theme', () {
      testWidgets('offers System, Light and Dark, and applies the choice', (
        tester,
      ) async {
        final settings = AppSettings.inMemory();
        await pump(tester, repo, settings: settings);
        await show(tester, find.text('Theme'));
        expect(find.text('System'), findsOneWidget);

        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();
        expect(find.text('Follow the system'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();

        expect(settings.themeMode, ThemeMode.dark);
        expect(find.text('Follow the system'), findsNothing);
        expect(find.text('Dark'), findsOneWidget);

        await close(tester);
      });
    });

    group('Reduce transparency', () {
      testWidgets('the switch changes the setting both ways', (tester) async {
        final settings = AppSettings.inMemory();
        await pump(tester, repo, settings: settings);
        final toggle = find.byKey(const ValueKey('reduce-transparency-switch'));
        await show(tester, toggle);
        expect(tester.widget<Switch>(toggle).value, isFalse);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(settings.reduceTransparency, isTrue);
        expect(tester.widget<Switch>(toggle).value, isTrue);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(settings.reduceTransparency, isFalse);

        await close(tester);
      });
    });

    group('Video and photo quality', () {
      testWidgets('offers three levels and says videos are untouched', (
        tester,
      ) async {
        final settings = AppSettings.inMemory();
        await pump(tester, repo, settings: settings);
        await show(tester, find.text('Video and photo quality'));
        expect(find.text('Original'), findsOneWidget);

        await tester.tap(find.text('Video and photo quality'));
        await tester.pumpAndSettle();
        expect(find.text('Every pixel, as taken'), findsOneWidget);
        expect(
          find.text('Photos up to 2560 px on the long edge'),
          findsOneWidget,
        );
        expect(
          find.text('Photos up to 1600 px on the long edge'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Applies to photos added from now on. Videos are always kept '
            'as recorded.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Smaller'));
        await tester.pumpAndSettle();

        expect(settings.mediaQuality, MediaQuality.smaller);
        expect(find.text('Smaller'), findsOneWidget);
        expect(find.text('Every pixel, as taken'), findsNothing);

        await close(tester);
      });
    });

    group('Evening reminder', () {
      final toggle = find.byKey(const ValueKey('reminder-switch'));

      testWidgets('is off until turned on, then schedules at 21:00', (
        tester,
      ) async {
        final settings = AppSettings.inMemory();
        final reminders = FakeReminderScheduler();
        await pump(tester, repo, settings: settings, reminders: reminders);
        expect(tester.widget<Switch>(toggle).value, isFalse);
        expect(find.text('Local notification at 21:00'), findsOneWidget);

        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(reminders.enabledAt, [const TimeOfDay(hour: 21, minute: 0)]);
        expect(settings.reminderOn, isTrue);
        expect(tester.widget<Switch>(toggle).value, isTrue);

        await close(tester);
      });

      testWidgets('turning it off cancels the notification', (tester) async {
        final settings = AppSettings.inMemory({'reminderOn': true});
        final reminders = FakeReminderScheduler();
        await pump(tester, repo, settings: settings, reminders: reminders);

        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(reminders.disabled, 1);
        expect(settings.reminderOn, isFalse);

        await close(tester);
      });

      testWidgets('stays off, and says why, when notifications are refused', (
        tester,
      ) async {
        final settings = AppSettings.inMemory();
        await pump(
          tester,
          repo,
          settings: settings,
          reminders: FakeReminderScheduler(allowed: false),
        );

        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(settings.reminderOn, isFalse);
        expect(tester.widget<Switch>(toggle).value, isFalse);
        expect(
          find.text(
            'Notifications are off for Moment. Allow them in the system '
            'settings, then turn the reminder on again.',
          ),
          findsOneWidget,
        );

        await close(tester);
      });

      testWidgets('tapping the row changes the time and reschedules', (
        tester,
      ) async {
        final settings = AppSettings.inMemory({'reminderOn': true});
        final reminders = FakeReminderScheduler();
        await pump(
          tester,
          repo,
          settings: settings,
          reminders: reminders,
          pickedTime: const TimeOfDay(hour: 20, minute: 30),
        );

        await tester.tap(find.text('Evening reminder'));
        await tester.pumpAndSettle();

        expect(settings.reminderTime, const TimeOfDay(hour: 20, minute: 30));
        expect(find.text('Local notification at 20:30'), findsOneWidget);
        expect(reminders.enabledAt, [const TimeOfDay(hour: 20, minute: 30)]);

        await close(tester);
      });

      testWidgets('a new time with the reminder off schedules nothing', (
        tester,
      ) async {
        final settings = AppSettings.inMemory();
        final reminders = FakeReminderScheduler();
        await pump(
          tester,
          repo,
          settings: settings,
          reminders: reminders,
          pickedTime: const TimeOfDay(hour: 6, minute: 0),
        );

        await tester.tap(find.text('Evening reminder'));
        await tester.pumpAndSettle();

        expect(settings.reminderTime, const TimeOfDay(hour: 6, minute: 0));
        expect(reminders.enabledAt, isEmpty);

        await close(tester);
      });

      testWidgets('dismissing the time picker changes nothing', (tester) async {
        final settings = AppSettings.inMemory();
        await pump(tester, repo, settings: settings);

        await tester.tap(find.text('Evening reminder'));
        await tester.pumpAndSettle();

        expect(settings.reminderTime, const TimeOfDay(hour: 21, minute: 0));

        await close(tester);
      });
    });

    testWidgets('Quick emoji row opens its editor', (tester) async {
      await pump(tester, repo);

      await tester.tap(find.text('Quick emoji row'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickEmojiScreen), findsOneWidget);

      await close(tester);
    });

    testWidgets('How Moment stays local opens the About screen', (
      tester,
    ) async {
      await pump(tester, repo);
      await show(tester, find.text('How Moment stays local'));

      await tester.tap(find.text('How Moment stays local'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutScreen), findsOneWidget);

      await close(tester);
    });
  });
}
