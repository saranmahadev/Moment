import 'package:flutter/services.dart';

import 'deep_links.dart';

/// Carries taps on the home screen widget from Android into [inbox]: the
/// link the app was started with, and links that arrive while it runs.
class WidgetLinkChannel {
  WidgetLinkChannel(this.inbox);

  final DeepLinkInbox inbox;

  static const _channel = MethodChannel('app.moment/widget');

  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        inbox.postText(call.arguments as String);
      }
      return null;
    });
    try {
      final initial = await _channel.invokeMethod<String>('initialLink');
      if (initial != null) inbox.postText(initial);
    } on MissingPluginException {
      // No widget on this platform.
    }
  }
}
