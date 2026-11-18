import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Plays a stored video. Wraps `video_player` so tests can supply a fake
/// instead of a real decoder.
abstract interface class VideoPlaybackController {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;

  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setLoop(bool on);
  Future<void> setMuted(bool on);

  /// Width over height of the loaded video; 16:9 until it is loaded.
  double get aspectRatio;

  /// The surface the video is drawn on.
  Widget buildView();

  Future<void> dispose();
}

class DeviceVideoPlaybackController implements VideoPlaybackController {
  VideoPlayerController? _controller;
  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _ready = ValueNotifier<bool>(false);

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  void _onValue() {
    final value = _controller!.value;
    _position.add(value.position);
    _playing.add(value.isPlaying);
  }

  @override
  Future<void> load(String path) async {
    // Streamed from the file by the platform player; never read into memory.
    final controller = VideoPlayerController.file(File(path));
    _controller = controller;
    await controller.initialize();
    controller.addListener(_onValue);
    _ready.value = true;
  }

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> seek(Duration position) async => _controller?.seekTo(position);

  @override
  Future<void> setSpeed(double speed) async =>
      _controller?.setPlaybackSpeed(speed);

  @override
  Future<void> setLoop(bool on) async => _controller?.setLooping(on);

  @override
  Future<void> setMuted(bool on) async => _controller?.setVolume(on ? 0 : 1);

  @override
  double get aspectRatio {
    final value = _controller?.value;
    return value != null && value.isInitialized ? value.aspectRatio : 16 / 9;
  }

  @override
  Widget buildView() {
    return ValueListenableBuilder<bool>(
      valueListenable: _ready,
      builder: (context, ready, _) {
        final controller = _controller;
        if (!ready || controller == null) return const SizedBox.expand();
        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    _controller?.removeListener(_onValue);
    await _controller?.dispose();
    await _position.close();
    await _playing.close();
    _ready.dispose();
  }
}
