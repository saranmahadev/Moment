import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Runs every test in this suite with the OS "reduce motion" accessibility
/// feature on by default. OrbField (lib/design/orb_field.dart) drifts and
/// squishes continuously in the real app, which would otherwise leave every
/// pumpAndSettle() call waiting forever on any screen that includes one
/// (which, by design, is nearly every screen). Tests that want to exercise
/// the real animation turn this back off explicitly and use bounded pump()
/// calls instead of pumpAndSettle().
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestWidgetsFlutterBinding
      .instance
      .platformDispatcher
      .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
    disableAnimations: true,
  );
  await testMain();
}
