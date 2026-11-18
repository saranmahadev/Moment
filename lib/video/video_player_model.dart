import 'dart:async';

import 'package:flutter/foundation.dart';

import 'video_playback_controller.dart';

const _speeds = [1.0, 1.25, 1.5, 2.0, 0.5];

/// The state and actions behind the video player, shared by the detail
/// screen and the fullscreen player so both always agree: where it is,
/// whether it plays, mute, loop and speed. It listens to the playback
/// controller; the screen that made the controller still disposes it.
class VideoPlayerModel extends ChangeNotifier {
  VideoPlayerModel({required this.playback, required this.duration}) {
    _subscriptions = [
      playback.positionStream.listen((position) {
        this.position = position;
        notifyListeners();
      }),
      playback.playingStream.listen((playing) {
        this.playing = playing;
        notifyListeners();
      }),
    ];
  }

  final VideoPlaybackController playback;
  final Duration duration;

  late final List<StreamSubscription<Object?>> _subscriptions;

  Duration position = Duration.zero;
  bool playing = false;

  /// Whether it has been played at all, so the poster can give way to video.
  bool started = false;
  bool muted = false;
  bool loop = false;
  double speed = 1.0;

  /// Played to the end and stopped there (a looping clip never ends).
  bool get ended =>
      started &&
      !playing &&
      !loop &&
      duration > Duration.zero &&
      position >= duration - const Duration(milliseconds: 100);

  double get fraction => duration.inMicroseconds == 0
      ? 0
      : (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);

  Duration _clamp(Duration target) => target < Duration.zero
      ? Duration.zero
      : (target > duration ? duration : target);

  Future<void> togglePlay() async {
    if (playing) {
      await playback.pause();
      return;
    }
    started = true;
    notifyListeners();
    if (ended) await playback.seek(Duration.zero);
    await playback.play();
  }

  Future<void> skip(Duration delta) => playback.seek(_clamp(position + delta));

  Future<void> seekToFraction(double fraction) => playback.seek(
    _clamp(
      Duration(
        microseconds: (duration.inMicroseconds * fraction.clamp(0.0, 1.0))
            .round(),
      ),
    ),
  );

  Future<void> toggleMute() async {
    muted = !muted;
    notifyListeners();
    await playback.setMuted(muted);
  }

  Future<void> toggleLoop() async {
    loop = !loop;
    notifyListeners();
    await playback.setLoop(loop);
  }

  Future<void> nextSpeed() async {
    speed = _speeds[(_speeds.indexOf(speed) + 1) % _speeds.length];
    notifyListeners();
    await playback.setSpeed(speed);
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
