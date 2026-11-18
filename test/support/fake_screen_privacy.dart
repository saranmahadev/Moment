import 'package:moment/lock/screen_privacy.dart';

/// Records what the app asked of the app switcher preview.
class FakeScreenPrivacy implements ScreenPrivacy {
  final calls = <bool>[];

  /// The last request, or null if none was made.
  bool? get hidden => calls.isEmpty ? null : calls.last;

  @override
  Future<void> setHidden(bool hidden) async => calls.add(hidden);
}
