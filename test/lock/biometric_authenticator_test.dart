import 'package:flutter_test/flutter_test.dart';
import 'package:moment/lock/biometric_authenticator.dart';

class _StubLocalAuth implements LocalAuthLike {
  _StubLocalAuth({
    this.canCheckBiometrics = true,
    this.isDeviceSupported = true,
    this.authenticateResult = true,
    this.throwOnAuthenticate = false,
  });

  final bool canCheckBiometrics;
  final bool isDeviceSupported;
  final bool authenticateResult;
  final bool throwOnAuthenticate;

  bool authenticateCalled = false;

  @override
  Future<bool> canCheckBiometricsNow() async => canCheckBiometrics;

  @override
  Future<bool> isDeviceSupportedNow() async => isDeviceSupported;

  @override
  Future<bool> authenticateNow() async {
    authenticateCalled = true;
    if (throwOnAuthenticate) {
      throw Exception('platform error');
    }
    return authenticateResult;
  }
}

void main() {
  group('isAvailable', () {
    test('true when the device supports and can check biometrics', () async {
      final auth = DeviceBiometricAuthenticator(_StubLocalAuth());
      expect(await auth.isAvailable, isTrue);
    });

    test('false when the device cannot check biometrics', () async {
      final auth = DeviceBiometricAuthenticator(
        _StubLocalAuth(canCheckBiometrics: false),
      );
      expect(await auth.isAvailable, isFalse);
    });

    test('false when the device is not supported', () async {
      final auth = DeviceBiometricAuthenticator(
        _StubLocalAuth(isDeviceSupported: false),
      );
      expect(await auth.isAvailable, isFalse);
    });
  });

  group('authenticate', () {
    test('returns true when the platform approves', () async {
      final stub = _StubLocalAuth();
      final auth = DeviceBiometricAuthenticator(stub);
      expect(await auth.authenticate(), isTrue);
      expect(stub.authenticateCalled, isTrue);
    });

    test('returns false when the platform declines', () async {
      final auth = DeviceBiometricAuthenticator(
        _StubLocalAuth(authenticateResult: false),
      );
      expect(await auth.authenticate(), isFalse);
    });

    test('returns false instead of throwing on a platform error', () async {
      final auth = DeviceBiometricAuthenticator(
        _StubLocalAuth(throwOnAuthenticate: true),
      );
      expect(await auth.authenticate(), isFalse);
    });
  });
}
