import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// What the video player asks of the phone's screen: fullscreen in the
/// orientation that suits the clip, and not dimming while a video plays.
/// Behind an interface so tests need no platform.
abstract interface class PlayerScreenControl {
  /// Hides the system bars and turns the screen to [landscape] or portrait.
  Future<void> enterFullscreen({required bool landscape});

  /// Brings the bars back and lets the screen turn freely again.
  Future<void> exitFullscreen();

  /// Keeps the screen on (or stops doing so).
  Future<void> keepAwake(bool on);
}

class DevicePlayerScreenControl implements PlayerScreenControl {
  @override
  Future<void> enterFullscreen({required bool landscape}) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(
      landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
  }

  @override
  Future<void> exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // An empty list lets the app follow the phone's own setting again.
    await SystemChrome.setPreferredOrientations(const []);
  }

  @override
  Future<void> keepAwake(bool on) =>
      on ? WakelockPlus.enable() : WakelockPlus.disable();
}
