import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/widgets/deep_links.dart';
import 'package:moment/widgets/widget_link_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.moment/widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('picks up the link the app was started with', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'initialLink' ? 'moment://add/photo' : null,
    );
    final inbox = DeepLinkInbox();

    await WidgetLinkChannel(inbox).start();

    expect((inbox.take() as AddLink).type, LogType.photo);
  });

  test('no starting link leaves the inbox empty', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final inbox = DeepLinkInbox();

    await WidgetLinkChannel(inbox).start();

    expect(inbox.take(), isNull);
  });

  test('a platform without the channel is fine', () async {
    final inbox = DeepLinkInbox();

    await WidgetLinkChannel(inbox).start();

    expect(inbox.take(), isNull);
  });

  test('links that arrive while the app runs are posted', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final inbox = DeepLinkInbox();
    await WidgetLinkChannel(inbox).start();

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('link', 'moment://streaks')),
      (_) {},
    );

    expect(inbox.take(), isA<StreaksLink>());
  });

  test('an unrecognised link does nothing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final inbox = DeepLinkInbox();
    await WidgetLinkChannel(inbox).start();

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('link', 'moment://wipe')),
      (_) {},
    );

    expect(inbox.take(), isNull);
  });
}
