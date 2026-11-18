import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/lock_gate.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/biometric_authenticator.dart';
import 'package:moment/lock/lock_screen.dart';
import 'package:moment/lock/pin_storage.dart';

import '../support/fake_screen_privacy.dart';

class _FakePinStorage implements PinStorage {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async => stored = value;

  @override
  Future<void> clear() async => stored = null;
}

class _NoBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<bool> authenticate() async => false;
}

void main() {
  late _FakePinStorage storage;
  late FakeScreenPrivacy privacy;
  late DateTime now;
  late AppLockController controller;

  setUp(() {
    storage = _FakePinStorage();
    privacy = FakeScreenPrivacy();
    now = DateTime.utc(2026, 11, 18, 9);
    controller = AppLockController(
      storage,
      random: Random(1),
      screenPrivacy: privacy,
      clock: () => now,
    );
  });

  group('whether a PIN is set is known at once, and kept current', () {
    test('load with no PIN: not set, unlocked, preview shown', () async {
      await controller.load();
      expect(controller.pinIsSet, isFalse);
      expect(controller.isLocked, isFalse);
      expect(privacy.hidden, isFalse);
    });

    test('load with a PIN: set, locked, preview hidden', () async {
      await controller.setPin('1234');
      final fresh = AppLockController(storage, screenPrivacy: privacy);
      await fresh.load();
      expect(fresh.pinIsSet, isTrue);
      expect(fresh.isLocked, isTrue);
      expect(privacy.hidden, isTrue);
    });

    test('setting a PIN hides the preview and tells listeners', () async {
      await controller.load();
      var told = 0;
      controller.addListener(() => told++);
      await controller.setPin('1234');
      expect(controller.pinIsSet, isTrue);
      expect(privacy.hidden, isTrue);
      expect(told, greaterThan(0));
    });

    test('clearing the PIN unlocks and shows the preview again', () async {
      await controller.setPin('1234');
      controller.lock();
      await controller.clearPin();
      expect(controller.pinIsSet, isFalse);
      expect(controller.isLocked, isFalse);
      expect(privacy.hidden, isFalse);
    });
  });

  group('wrong PINs slow down guessing', () {
    Future<void> wrong(int times) async {
      for (var i = 0; i < times; i++) {
        expect(await controller.verifyPin('0000'), isFalse);
      }
    }

    setUp(() async {
      await controller.setPin('1234');
      controller.lock();
    });

    test('four wrong tries cost nothing', () async {
      await wrong(4);
      expect(controller.retryAfter, isNull);
      expect(await controller.verifyPin('1234'), isTrue);
    });

    test('the fifth wrong try means waiting 30 seconds', () async {
      await wrong(5);
      expect(controller.retryAfter, const Duration(seconds: 30));
      // Even the right PIN is refused while waiting.
      expect(await controller.verifyPin('1234'), isFalse);
      expect(controller.isLocked, isTrue);

      now = now.add(const Duration(seconds: 10));
      expect(controller.retryAfter, const Duration(seconds: 20));

      now = now.add(const Duration(seconds: 20));
      expect(controller.retryAfter, isNull);
      expect(await controller.verifyPin('1234'), isTrue);
    });

    test(
      'each wrong try after that doubles the wait, up to 15 minutes',
      () async {
        final waits = <Duration?>[];
        for (var i = 0; i < 12; i++) {
          await controller.verifyPin('0000');
          waits.add(controller.retryAfter);
          now = now.add(controller.retryAfter ?? Duration.zero);
        }
        expect(waits.sublist(4, 10), const [
          Duration(seconds: 30),
          Duration(minutes: 1),
          Duration(minutes: 2),
          Duration(minutes: 4),
          Duration(minutes: 8),
          Duration(minutes: 15),
        ]);
        expect(waits.last, const Duration(minutes: 15));
      },
    );

    test('the right PIN starts the count again', () async {
      await wrong(4);
      expect(await controller.verifyPin('1234'), isTrue);
      controller.lock();
      await wrong(4);
      expect(controller.retryAfter, isNull);
    });
  });

  group('LockGate follows the controller', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: momentTheme(),
          home: LockGate(
            controller: controller,
            biometrics: _NoBiometrics(),
            child: const Text('Shell'),
          ),
        ),
      );
    }

    testWidgets('turning the lock off while away never strands you', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await controller.setPin('1234');
        await controller.clearPin();
      });
      // The app leaves the foreground and comes back.
      controller.handleAppLifecycleState(AppLifecycleState.paused);
      await pump(tester);
      expect(find.text('Shell'), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);
    });

    testWidgets('turning the lock on takes effect the next time you leave', (
      tester,
    ) async {
      await tester.runAsync(controller.load);
      await pump(tester);
      expect(find.text('Shell'), findsOneWidget);

      await tester.runAsync(() => controller.setPin('1234'));
      await tester.pump();
      expect(find.text('Shell'), findsOneWidget);

      controller.handleAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byType(LockScreen), findsOneWidget);
    });
  });

  testWidgets('the Lock screen says how long to wait', (tester) async {
    await tester.runAsync(() async {
      await controller.setPin('1234');
      controller.lock();
      for (var i = 0; i < 5; i++) {
        await controller.verifyPin('0000');
      }
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: LockScreen(controller: controller, biometrics: _NoBiometrics()),
      ),
    );
    expect(find.text('Too many tries. Try again in 30 s.'), findsOneWidget);
    // The keypad does nothing while waiting.
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(controller.isLocked, isTrue);

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Too many tries'), findsNothing);
  });
}
