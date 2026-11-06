import 'package:flutter/material.dart';

import '../lock/app_lock_controller.dart';
import '../lock/biometric_authenticator.dart';
import '../lock/lock_screen.dart';

/// Shows the Lock screen whenever a PIN has been set and the app is
/// locked, otherwise shows [child]. Watches [controller] so it switches
/// the moment the lock state changes (unlocked by PIN, Face ID, or
/// relocked after the app was backgrounded).
class LockGate extends StatelessWidget {
  const LockGate({
    super.key,
    required this.controller,
    required this.biometrics,
    required this.hasPin,
    required this.child,
  });

  final AppLockController controller;
  final BiometricAuthenticator biometrics;

  /// Whether a PIN has ever been set. When false, the app is never gated,
  /// matching app-lock being opt-in.
  final bool hasPin;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (hasPin && controller.isLocked) {
          return LockScreen(controller: controller, biometrics: biometrics);
        }
        return child;
      },
    );
  }
}
