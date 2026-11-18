import 'package:flutter/services.dart';

/// Whether the app's preview in the system app switcher (Recents) shows
/// the journal. Hidden while the app lock is on, so a locked journal is
/// not readable from a thumbnail.
abstract interface class ScreenPrivacy {
  Future<void> setHidden(bool hidden);
}

/// Asks MainActivity: on Android 13 and later it turns off the Recents
/// screenshot only; on older versions it sets FLAG_SECURE, which also
/// blocks screenshots.
class DeviceScreenPrivacy implements ScreenPrivacy {
  const DeviceScreenPrivacy();

  static const _channel = MethodChannel('app.moment/screen_privacy');

  @override
  Future<void> setHidden(bool hidden) async {
    try {
      await _channel.invokeMethod<void>('setHidden', hidden);
    } on MissingPluginException {
      // No Android host (tests, other platforms): nothing to hide.
    }
  }
}
