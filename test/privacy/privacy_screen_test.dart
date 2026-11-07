import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/orb_field.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/pin_storage.dart';
import 'package:moment/privacy/privacy_screen.dart';

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
  Future<void> pump(
    WidgetTester tester,
    AppLockController controller, {
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: PrivacyScreen(controller: controller, onBack: onBack),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the title and the local-only banner', (tester) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    expect(find.text('Privacy and backup'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
    expect(
      find.text('No account, no servers, no internet permission.'),
      findsOneWidget,
    );
    expect(find.byType(OrbField), findsOneWidget);
  });

  testWidgets('shows the Security section with App lock and Lock after', (
    tester,
  ) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('App lock'), findsOneWidget);
    expect(find.text('PIN with Face ID'), findsOneWidget);
    expect(find.text('Lock after'), findsOneWidget);
    expect(find.text('Immediately'), findsOneWidget);
  });

  testWidgets('App lock is off when no PIN is set', (tester) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isFalse);
  });

  testWidgets('App lock is on when a PIN is already set', (tester) async {
    final storage = _FakePinStorage();
    final controller = AppLockController(storage);
    await controller.setPin('1234');

    await pump(tester, controller);

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);
  });

  testWidgets('turning App lock on opens CreatePinScreen', (tester) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Choose a PIN'), findsOneWidget);
  });

  testWidgets('finishing CreatePinScreen returns to Privacy with App lock on', (
    tester,
  ) async {
    final controller = AppLockController(_FakePinStorage());
    await pump(tester, controller);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    for (final digit in '1234'.split('')) {
      await tester.tap(find.byKey(ValueKey('digit-$digit')));
      await tester.pump();
    }
    for (final digit in '1234'.split('')) {
      await tester.tap(find.byKey(ValueKey('digit-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Privacy and backup'), findsOneWidget);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);
    expect(await controller.hasPin(), isTrue);
  });

  testWidgets('turning App lock off clears the PIN', (tester) async {
    final storage = _FakePinStorage();
    final controller = AppLockController(storage);
    await controller.setPin('1234');

    await pump(tester, controller);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isFalse);
    expect(await controller.hasPin(), isFalse);
  });

  testWidgets('the back button calls onBack', (tester) async {
    final controller = AppLockController(_FakePinStorage());
    var backed = false;
    await pump(tester, controller, onBack: () => backed = true);

    await tester.tap(find.bySemanticsLabel('Back'));

    expect(backed, isTrue);
  });
}
