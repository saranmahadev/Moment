import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/orb_field.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/create_pin_screen.dart';
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
  late AppLockController controller;

  setUp(() {
    controller = AppLockController(_FakePinStorage());
  });

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onDone,
    VoidCallback? onCancel,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePinScreen(
          controller: controller,
          onDone: onDone ?? () {},
          onCancel: onCancel ?? () {},
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

  testWidgets('asks to choose a PIN first', (tester) async {
    await pump(tester);
    expect(find.text('Choose a PIN'), findsOneWidget);
  });

  testWidgets('shows the decorative background orbs', (tester) async {
    await pump(tester);
    expect(find.byType(OrbField), findsOneWidget);
  });

  testWidgets('after 4 digits, asks to confirm the PIN', (tester) async {
    await pump(tester);
    await enter(tester, '1234');

    expect(find.text('Confirm your PIN'), findsOneWidget);
  });

  testWidgets('matching confirmation sets the PIN and calls onDone', (
    tester,
  ) async {
    var done = false;
    await pump(tester, onDone: () => done = true);

    await enter(tester, '1234');
    await enter(tester, '1234');
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(await controller.verifyPin('1234'), isTrue);
  });

  testWidgets('a mismatched confirmation shows an error and restarts', (
    tester,
  ) async {
    var done = false;
    await pump(tester, onDone: () => done = true);

    await enter(tester, '1234');
    await enter(tester, '0000');
    await tester.pump();

    expect(find.text("PINs don't match"), findsOneWidget);
    expect(done, isFalse);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Choose a PIN'), findsOneWidget);
    expect(await controller.hasPin(), isFalse);
  });

  testWidgets('Cancel calls onCancel without setting a PIN', (tester) async {
    var cancelled = false;
    await pump(tester, onCancel: () => cancelled = true);

    await tester.tap(find.bySemanticsLabel('Cancel'));
    expect(cancelled, isTrue);
    expect(await controller.hasPin(), isFalse);
  });
}
