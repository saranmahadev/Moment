import 'package:moment/widgets/widget_bridge.dart';
import 'package:moment/widgets/widget_snapshot.dart';

/// A widget bridge that keeps what it was given.
class FakeWidgetBridge implements WidgetBridge {
  final published = <WidgetSnapshot>[];
  bool pinAnswer = true;
  int pinRequests = 0;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async =>
      published.add(snapshot);

  @override
  Future<bool> requestPin() async {
    pinRequests++;
    return pinAnswer;
  }
}
