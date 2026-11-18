import 'package:flutter/services.dart';

import 'widget_snapshot.dart';

/// The way the app talks to the home screen widget. Everything that touches
/// the platform sits behind this, so tests use a fake.
abstract class WidgetBridge {
  /// Stores [snapshot] where the widget reads it, and asks the launcher to
  /// draw the widget again.
  Future<void> publish(WidgetSnapshot snapshot);

  /// Asks the launcher to offer adding the widget to the home screen. False
  /// when the launcher cannot or will not.
  Future<bool> requestPin();
}

/// Android: a method channel to `MainActivity`, which keeps the snapshot in
/// the widget's own preferences file (never in the encrypted database, which
/// a widget cannot open).
class DeviceWidgetBridge implements WidgetBridge {
  const DeviceWidgetBridge();

  static const _channel = MethodChannel('app.moment/widget');

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>('publish', snapshot.encode());
    } on MissingPluginException {
      // No widget on this platform; nothing to update.
    }
  }

  @override
  Future<bool> requestPin() async {
    try {
      return await _channel.invokeMethod<bool>('requestPin') ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
