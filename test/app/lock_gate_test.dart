import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/lock_gate.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/biometric_authenticator.dart';
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

class _FakeBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<bool> authenticate() async => false;
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required AppLockController controller,
    required bool hasPin,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: LockGate(
          controller: controller,
          biometrics: _FakeBiometrics(),
          hasPin: hasPin,
          child: const Text('Shell'),
        ),
      ),
    );
  }

  testWidgets('shows the child directly when no PIN has been set', (
    tester,
  ) async {
    final controller = AppLockController(_FakePinStorage());

    await pump(tester, controller: controller, hasPin: false);

    expect(find.text('Shell'), findsOneWidget);
    expect(find.text('Moment'), findsNothing);
  });

  testWidgets('shows the Lock screen when a PIN is set and locked', (
    tester,
  ) async {
    final controller = AppLockController(_FakePinStorage());
    await controller.setPin('1234');
    controller.lock();

    await pump(tester, controller: controller, hasPin: true);

    expect(find.text('Shell'), findsNothing);
    expect(find.text('Moment'), findsOneWidget);
  });

  testWidgets('switches to the child as soon as the controller unlocks', (
    tester,
  ) async {
    final controller = AppLockController(_FakePinStorage());
    await controller.setPin('1234');
    controller.lock();

    await pump(tester, controller: controller, hasPin: true);
    expect(find.text('Shell'), findsNothing);

    controller.unlock();
    await tester.pump();

    expect(find.text('Shell'), findsOneWidget);
  });

  testWidgets('relocks and shows the Lock screen again when told to', (
    tester,
  ) async {
    final controller = AppLockController(_FakePinStorage());
    await controller.setPin('1234');
    controller.unlock();

    await pump(tester, controller: controller, hasPin: true);
    expect(find.text('Shell'), findsOneWidget);

    controller.lock();
    await tester.pump();

    expect(find.text('Shell'), findsNothing);
    expect(find.text('Moment'), findsOneWidget);
  });
}
