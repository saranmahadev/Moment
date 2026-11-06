import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/pin_storage.dart';

class _FakePinStorage implements PinStorage {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async => stored = value;

  @override
  Future<void> clear() async => stored = null;
}

void main() {
  late _FakePinStorage storage;
  late AppLockController controller;

  setUp(() {
    storage = _FakePinStorage();
    controller = AppLockController(storage, random: Random(1));
  });

  group('hasPin', () {
    test('is false before a PIN is ever set', () async {
      expect(await controller.hasPin(), isFalse);
    });

    test('is true after setPin', () async {
      await controller.setPin('1234');
      expect(await controller.hasPin(), isTrue);
    });

    test('is false again after clearPin', () async {
      await controller.setPin('1234');
      await controller.clearPin();
      expect(await controller.hasPin(), isFalse);
    });
  });

  group('setPin', () {
    test('rejects a PIN that is not exactly 4 digits', () async {
      expect(() => controller.setPin('123'), throwsArgumentError);
      expect(() => controller.setPin('12345'), throwsArgumentError);
      expect(() => controller.setPin('12a4'), throwsArgumentError);
    });

    test('never stores the PIN itself', () async {
      await controller.setPin('1234');
      expect(storage.stored, isNot(contains('1234')));
    });

    test('salts each PIN differently, even for the same digits', () async {
      await controller.setPin('1234');
      final first = storage.stored;

      await controller.clearPin();
      await controller.setPin('1234');
      final second = storage.stored;

      expect(first, isNot(second));
    });
  });

  group('verifyPin', () {
    test('accepts the correct PIN and unlocks', () async {
      await controller.setPin('1234');
      controller.lock();

      expect(await controller.verifyPin('1234'), isTrue);
      expect(controller.isLocked, isFalse);
    });

    test('rejects an incorrect PIN and stays locked', () async {
      await controller.setPin('1234');
      controller.lock();

      expect(await controller.verifyPin('0000'), isFalse);
      expect(controller.isLocked, isTrue);
    });

    test('rejects any PIN when none has been set', () async {
      expect(await controller.verifyPin('1234'), isFalse);
    });
  });

  group('lock and unlock', () {
    test('starts locked', () {
      expect(controller.isLocked, isTrue);
    });

    test('unlock clears isLocked and notifies listeners', () {
      var notified = 0;
      controller.addListener(() => notified++);

      controller.unlock();

      expect(controller.isLocked, isFalse);
      expect(notified, 1);
    });

    test('lock sets isLocked and notifies listeners', () {
      controller.unlock();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.lock();

      expect(controller.isLocked, isTrue);
      expect(notified, 1);
    });

    test('does not notify when already in the target state', () {
      var notified = 0;
      controller.addListener(() => notified++);

      controller.lock(); // already locked
      expect(notified, 0);
    });
  });

  group('handleAppLifecycleState', () {
    for (final state in [
      AppLifecycleState.paused,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      test('locks on $state', () {
        controller.unlock();
        controller.handleAppLifecycleState(state);
        expect(controller.isLocked, isTrue);
      });
    }

    test('does not unlock on resumed', () {
      controller.lock();
      controller.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.isLocked, isTrue);
    });
  });
}
