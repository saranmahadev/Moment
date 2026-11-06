import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/biometric_authenticator.dart';
import 'package:moment/lock/lock_screen.dart';
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
  _FakeBiometrics({this.available = true, this.result = true});

  final bool available;
  final bool result;
  bool authenticateCalled = false;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<bool> authenticate() async {
    authenticateCalled = true;
    return result;
  }
}

void main() {
  late AppLockController controller;
  late _FakeBiometrics biometrics;
  late bool unlocked;

  setUp(() async {
    controller = AppLockController(_FakePinStorage());
    await controller.setPin('1234');
    controller.lock();
    biometrics = _FakeBiometrics();
    unlocked = false;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: LockScreen(
          controller: controller,
          biometrics: biometrics,
          onUnlocked: () => unlocked = true,
        ),
      ),
    );
  }

  Future<void> enter(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('digit-$digit')));
      await tester.pump();
    }
  }

  testWidgets('shows the title, subtitle and footer', (tester) async {
    await pump(tester);

    expect(find.text('Moment'), findsOneWidget);
    expect(find.text('Everything stays on this device'), findsOneWidget);
    expect(find.text('No account · No cloud · No tracking'), findsOneWidget);
  });

  testWidgets('starts with no digits entered', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('0 of 4 digits entered'), findsOneWidget);
  });

  testWidgets('entering the correct PIN unlocks', (tester) async {
    await pump(tester);

    await enter(tester, '1234');
    await tester.pumpAndSettle();

    expect(controller.isLocked, isFalse);
    expect(unlocked, isTrue);
  });

  testWidgets('entering a wrong PIN shows an error and clears the dots', (
    tester,
  ) async {
    await pump(tester);

    await enter(tester, '0000');
    await tester.pump();

    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(controller.isLocked, isTrue);
    expect(unlocked, isFalse);

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('0 of 4 digits entered'), findsOneWidget);
    expect(find.text('Incorrect PIN'), findsNothing);
  });

  testWidgets('delete removes the last entered digit', (tester) async {
    await pump(tester);

    await enter(tester, '12');
    expect(find.bySemanticsLabel('2 of 4 digits entered'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete')));
    await tester.pump();
    expect(find.bySemanticsLabel('1 of 4 digits entered'), findsOneWidget);
  });

  testWidgets('Face ID unlocks on success', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('face-id')));
    await tester.pumpAndSettle();

    expect(biometrics.authenticateCalled, isTrue);
    expect(controller.isLocked, isFalse);
    expect(unlocked, isTrue);
  });

  testWidgets('Face ID failure leaves the screen locked', (tester) async {
    biometrics = _FakeBiometrics(result: false);
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('face-id')));
    await tester.pumpAndSettle();

    expect(controller.isLocked, isTrue);
    expect(unlocked, isFalse);
  });

  testWidgets('matches its approved baseline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pump(tester);

    await expectLater(
      find.byType(LockScreen),
      matchesGoldenFile('goldens/lock_screen.png'),
    );
  });
}
