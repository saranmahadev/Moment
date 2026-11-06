import 'package:local_auth/local_auth.dart';

/// What [DeviceBiometricAuthenticator] needs from `local_auth`'s
/// [LocalAuthentication], as a seam tests can fake without a platform
/// channel.
abstract class LocalAuthLike {
  Future<bool> canCheckBiometricsNow();
  Future<bool> isDeviceSupportedNow();
  Future<bool> authenticateNow();
}

/// Adapts the real `local_auth` plugin to [LocalAuthLike].
class RealLocalAuth implements LocalAuthLike {
  RealLocalAuth([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canCheckBiometricsNow() => _auth.canCheckBiometrics;

  @override
  Future<bool> isDeviceSupportedNow() => _auth.isDeviceSupported();

  @override
  Future<bool> authenticateNow() => _auth.authenticate(
    localizedReason: 'Unlock Moment',
    options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
  );
}

/// Face ID, Touch ID or Android biometric unlock, backed by `local_auth`.
abstract class BiometricAuthenticator {
  Future<bool> get isAvailable;
  Future<bool> authenticate();
}

/// The production [BiometricAuthenticator]. Platform errors (no biometrics
/// enrolled, hardware unavailable, the user cancels) are treated as "not
/// authenticated" rather than left to crash the Lock screen.
class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  DeviceBiometricAuthenticator([LocalAuthLike? localAuth])
    : _localAuth = localAuth ?? RealLocalAuth();

  final LocalAuthLike _localAuth;

  @override
  Future<bool> get isAvailable async {
    try {
      return await _localAuth.canCheckBiometricsNow() &&
          await _localAuth.isDeviceSupportedNow();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticateNow();
    } catch (_) {
      return false;
    }
  }
}
