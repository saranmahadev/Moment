import 'dart:async';

import '../settings/app_settings.dart';
import 'widget_bridge.dart';
import 'widget_snapshot.dart';

/// Keeps the home screen widget in step with the journal.
///
/// Whenever the days with a log change, it works out a [WidgetSnapshot] and
/// hands it to the [WidgetBridge], after a short wait so a burst of changes
/// (an import, a restore) sends one update. A change to a setting that
/// decides what the widget may show is sent at once, so turning the switch
/// off removes the numbers from the home screen straight away.
class WidgetPublisher {
  WidgetPublisher({
    required Stream<Set<DateTime>> days,
    required this.settings,
    required this.bridge,
    required this.now,
    this.wait = const Duration(seconds: 2),
  }) {
    _subscription = days.listen((value) {
      _days = value;
      _timer?.cancel();
      _timer = Timer(wait, _send);
    });
    settings.addListener(_onSettings);
    _last = _key();
  }

  final AppSettings settings;
  final WidgetBridge bridge;
  final DateTime Function() now;
  final Duration wait;

  late final StreamSubscription<Set<DateTime>> _subscription;
  Set<DateTime>? _days;
  Timer? _timer;
  late String _last;
  var _disposed = false;

  String _key() =>
      '${settings.showStreaks}|${settings.widgetShowsStreak}|${settings.graceDays}';

  void _onSettings() {
    final key = _key();
    if (key == _last) return;
    _last = key;
    _timer?.cancel();
    _send();
  }

  void _send() {
    final days = _days;
    if (_disposed || days == null) return;
    final t = now();
    final snapshot = WidgetSnapshot.build(
      days: days,
      today: DateTime.utc(t.year, t.month, t.day),
      grace: settings.graceDays,
      show: settings.showStreaks && settings.widgetShowsStreak,
    );
    // A widget that cannot be reached is not worth failing the app for.
    unawaited(bridge.publish(snapshot).catchError((Object _) {}));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    settings.removeListener(_onSettings);
    unawaited(_subscription.cancel());
  }
}
