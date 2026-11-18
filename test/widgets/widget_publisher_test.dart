import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/widgets/widget_bridge.dart';
import 'package:moment/widgets/widget_publisher.dart';
import 'package:moment/widgets/widget_snapshot.dart';

class FakeWidgetBridge implements WidgetBridge {
  final published = <WidgetSnapshot>[];
  bool pinAnswer = true;
  int pinRequests = 0;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async =>
      published.add(snapshot);

  @override
  Future<bool> requestPin() async {
    pinRequests++;
    return pinAnswer;
  }
}

DateTime d(int day) => DateTime.utc(2026, 11, day);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AppSettings.widgetShowsStreak', () {
    test('is on by default and survives a restart', () async {
      final store = MemorySettingsStore();
      final first = await AppSettings.load(store);
      expect(first.widgetShowsStreak, isTrue);

      await first.setWidgetShowsStreak(false);
      final second = await AppSettings.load(store);

      expect(second.widgetShowsStreak, isFalse);
    });

    test('a damaged value reads as the default', () async {
      final s = await AppSettings.load(
        MemorySettingsStore({'widgetShowsStreak': 'no'}),
      );

      expect(s.widgetShowsStreak, isTrue);
    });
  });

  group('WidgetPublisher', () {
    late StreamController<Set<DateTime>> days;
    late FakeWidgetBridge bridge;
    late AppSettings settings;

    WidgetPublisher make() => WidgetPublisher(
      days: days.stream,
      settings: settings,
      bridge: bridge,
      now: () => DateTime(2026, 11, 18, 9),
    );

    setUp(() async {
      days = StreamController<Set<DateTime>>.broadcast();
      bridge = FakeWidgetBridge();
      settings = await AppSettings.load(MemorySettingsStore());
    });

    tearDown(() => days.close());

    test('sends nothing until the days have loaded', () {
      fakeAsync((async) {
        make();
        async.elapse(const Duration(seconds: 10));

        expect(bridge.published, isEmpty);
      });
    });

    test('sends the streak once the days load, after a short wait', () {
      fakeAsync((async) {
        make();
        days.add({d(16), d(17), d(18)});
        async.elapse(const Duration(seconds: 1));
        expect(bridge.published, isEmpty);

        async.elapse(const Duration(seconds: 2));

        expect(bridge.published, hasLength(1));
        expect(bridge.published.single.streak, 3);
        expect(bridge.published.single.show, isTrue);
        expect(bridge.published.single.asOf, '2026-11-18');
      });
    });

    test('a burst of changes sends one update with the last state', () {
      fakeAsync((async) {
        make();
        days.add({d(17)});
        async.elapse(const Duration(milliseconds: 500));
        days.add({d(17), d(18)});
        async.elapse(const Duration(milliseconds: 500));
        days.add({d(16), d(17), d(18)});
        async.elapse(const Duration(seconds: 5));

        expect(bridge.published, hasLength(1));
        expect(bridge.published.single.streak, 3);
      });
    });

    test('turning the switch off sends at once, with no numbers', () {
      fakeAsync((async) {
        make();
        days.add({d(17), d(18)});
        async.elapse(const Duration(seconds: 5));
        bridge.published.clear();

        settings.setWidgetShowsStreak(false);
        async.flushMicrotasks();

        expect(bridge.published, hasLength(1));
        expect(bridge.published.single.show, isFalse);
        expect(bridge.published.single.streak, 0);
      });
    });

    test('turning streaks off in the app hides them on the widget too', () {
      fakeAsync((async) {
        make();
        days.add({d(17), d(18)});
        async.elapse(const Duration(seconds: 5));
        bridge.published.clear();

        settings.setShowStreaks(false);
        async.flushMicrotasks();

        expect(bridge.published.single.show, isFalse);
      });
    });

    test('the grace setting changes the streak that is sent', () {
      fakeAsync((async) {
        // Logged 14, 15, 17, 18: the 16th was missed.
        make();
        days.add({d(14), d(15), d(17), d(18)});
        async.elapse(const Duration(seconds: 5));
        expect(bridge.published.last.streak, 5);
        settings.setGraceDays(0);
        async.flushMicrotasks();

        expect(bridge.published.last.streak, 2);
      });
    });

    test('a bridge that fails does not stop later updates', () {
      fakeAsync((async) {
        final failing = _FailingOnce();
        WidgetPublisher(
          days: days.stream,
          settings: settings,
          bridge: failing,
          now: () => DateTime(2026, 11, 18),
        );
        days.add({d(18)});
        async.elapse(const Duration(seconds: 5));
        days.add({d(17), d(18)});
        async.elapse(const Duration(seconds: 5));

        expect(failing.published.single.streak, 2);
      });
    });

    test('dispose stops it', () {
      fakeAsync((async) {
        final p = make();
        days.add({d(18)});
        p.dispose();
        async.elapse(const Duration(seconds: 5));

        expect(bridge.published, isEmpty);
      });
    });
  });

  group('DeviceWidgetBridge', () {
    const channel = MethodChannel('app.moment/widget');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'requestPin' ? true : null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('hands the snapshot text to the platform', () async {
      final snapshot = WidgetSnapshot.build(
        days: {d(18)},
        today: d(18),
        grace: 1,
        show: true,
      );

      await const DeviceWidgetBridge().publish(snapshot);

      expect(calls.single.method, 'publish');
      expect(calls.single.arguments, snapshot.encode());
    });

    test('asks the launcher to pin the widget', () async {
      expect(await const DeviceWidgetBridge().requestPin(), isTrue);
      expect(calls.single.method, 'requestPin');
    });

    test(
      'with no platform behind it, nothing happens and pin is false',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);

        await const DeviceWidgetBridge().publish(
          WidgetSnapshot.build(days: {}, today: d(18), grace: 1, show: true),
        );
        expect(await const DeviceWidgetBridge().requestPin(), isFalse);
      },
    );
  });
}

class _FailingOnce extends FakeWidgetBridge {
  var _first = true;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    if (_first) {
      _first = false;
      throw PlatformException(code: 'nope');
    }
    await super.publish(snapshot);
  }
}
