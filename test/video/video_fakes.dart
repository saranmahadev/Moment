import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:moment/video/video_picker.dart';
import 'package:moment/video/video_playback_controller.dart';
import 'package:moment/video/video_probe.dart';

/// Stands in for the device's video tooling: a fixed duration and a small
/// poster file, or neither when [readable] is false.
class FakeVideoProbe implements VideoProbe {
  FakeVideoProbe({this.readable = true});

  final bool readable;

  @override
  Future<Duration> duration(File video) async {
    if (!readable) throw const FormatException('not a video');
    return const Duration(seconds: 48);
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
  Widget buildView() => const SizedBox(key: ValueKey('fake-video-view'));

  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _playing.close();
  }
}
