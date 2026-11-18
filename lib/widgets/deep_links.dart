import 'package:flutter/foundation.dart';

import '../domain/log_type.dart';

/// Where a tap on the home screen widget should land.
sealed class AppLink {
  const AppLink();
}

/// Open the New screen for [type].
class AddLink extends AppLink {
  const AddLink(this.type);

  final LogType type;
}

/// Open the Streaks page.
class StreaksLink extends AppLink {
  const StreaksLink();
}

/// Reads `moment://add/<type>` and `moment://streaks`; null for anything
/// else, so a stray or hostile string can only ever do nothing.
AppLink? parseAppLink(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'moment') return null;
  final parts = [
    if (uri.host.isNotEmpty) uri.host.toLowerCase(),
    ...uri.pathSegments.where((s) => s.isNotEmpty).map((s) => s.toLowerCase()),
  ];
  if (parts.length == 1 && parts[0] == 'streaks') return const StreaksLink();
  if (parts.length == 2 && parts[0] == 'add') {
    for (final type in LogType.values) {
      if (type.name == parts[1]) return AddLink(type);
    }
  }
  return null;
}

/// Holds the link from the widget until the app shell can act on it. The
/// shell is not built while the app lock shows, or before the app has
/// started, so the link waits here and is opened on the shell's first frame.
class DeepLinkInbox extends ChangeNotifier {
  AppLink? _pending;

  void post(AppLink link) {
    _pending = link;
    notifyListeners();
  }

  /// Posts the link in [text], if it is one.
  void postText(String text) {
    final link = parseAppLink(text);
    if (link != null) post(link);
  }

  /// The waiting link, once.
  AppLink? take() {
    final link = _pending;
    _pending = null;
    return link;
  }
}
