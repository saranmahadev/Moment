import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:moment/video/player_screen_control.dart';
import 'package:moment/video/video_picker.dart';
import 'package:moment/video/video_playback_controller.dart';
import 'package:moment/video/video_probe.dart';

/// Stands in for the device's video tooling: a fixed duration and a small
/// poster file, or neither when [readable] is false.
class FakeVideoProbe implements VideoProbe {
  FakeVideoProbe({this.readable = true, this.failFramesAt = const {}});

  final bool readable;

  /// Frame times (whole seconds) for which no frame can be made.
  final Set<int> failFramesAt;

  /// Every frame asked for, in order: where it went and when it was taken.
  final List<({String path, Duration at})> frameRequests = [];

  @override
  Future<Duration> duration(File video) async {
    if (!readable) throw const FormatException('not a video');
    return const Duration(seconds: 48);
  }

  @override
  Future<bool> writeFrame(File video, File destination, Duration at) async {
    frameRequests.add((path: destination.path, at: at));
    if (failFramesAt.contains(at.inSeconds)) return false;
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes([9, 9, 9]);
    return true;
  }

  @override
  Future<bool> writePoster(File video, File destination) async {
    if (!readable) return false;
    await destination.writeAsBytes([1, 2, 3]);
    return true;
  }
}

class FakeVideoPicker implements VideoPicker {
  FakeVideoPicker({this.cameraResult, this.galleryResult});

  File? cameraResult;
  File? galleryResult;

  @override
  Future<File?> recordWithCamera() async => cameraResult;

  @override
  Future<File?> pickFromGallery() async => galleryResult;
}

class FakeVideoPlaybackController implements VideoPlaybackController {
  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  String? loadedPath;
  bool played = false;
  bool paused = false;
  Duration? lastSeek;
  bool disposed = false;
  double? speed;
  bool? loop;
  bool? muted;
  @override
  double aspectRatio = 16 / 9;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> load(String path) async => loadedPath = path;

  @override
  Future<void> play() async {
    played = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    paused = true;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _position.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> setLoop(bool on) async => loop = on;

  @override
  Future<void> setMuted(bool on) async => muted = on;

  /// The video reached its end.
  void ended() {
    _position.add(const Duration(seconds: 48));
    _playing.add(false);
  }

  @override
  Widget buildView() => const SizedBox(key: ValueKey('fake-video-view'));

  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _playing.close();
  }
}


/// Records what the player asks of the screen and the system.
class FakePlayerScreenControl implements PlayerScreenControl {
  final List<bool> fullscreen = [];
  int exits = 0;
  final List<bool> awake = [];

  @override
  Future<void> enterFullscreen({required bool landscape}) async =>
      fullscreen.add(landscape);

  @override
  Future<void> exitFullscreen() async => exits++;

  @override
  Future<void> keepAwake(bool on) async => awake.add(on);
}
