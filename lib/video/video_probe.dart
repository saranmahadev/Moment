import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:video_player/video_player.dart';

/// Reads what the media pipeline needs from a video file: how long it is,
/// and a still frame to show before it plays. Wraps the platform's video
/// tooling so tests can supply a fake.
abstract interface class VideoProbe {
  /// Throws if [video] cannot be read as a video.
  Future<Duration> duration(File video);

  /// Writes a small JPEG of the frame at [at] to [destination], for the
  /// frame strip. Returns false when no frame could be made.
  Future<bool> writeFrame(File video, File destination, Duration at);

  /// Writes a JPEG poster frame of [video] to [destination]. Returns false
  /// when no frame could be made.
  Future<bool> writePoster(File video, File destination);
}

class DeviceVideoProbe implements VideoProbe {
  static const _posterSize = 720;
  static const _frameSize = 160;

  @override
  Future<Duration> duration(File video) async {
    final controller = VideoPlayerController.file(video);
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }

  @override
  Future<bool> writeFrame(File video, File destination, Duration at) {
    return FcNativeVideoThumbnail().saveThumbnailToFile(
      srcFile: video.path,
      destFile: destination.path,
      width: _frameSize,
      height: _frameSize,
      format: 'jpeg',
      quality: 60,
      at: FcVideoThumbnailTime(
        at.inMilliseconds,
        FcVideoThumbnailTimeUnit.milliseconds,
      ),
    );
  }

  // The platform decodes and scales the frame on its own thread.
  @override
  Future<bool> writePoster(File video, File destination) {
    return FcNativeVideoThumbnail().saveThumbnailToFile(
      srcFile: video.path,
      destFile: destination.path,
      width: _posterSize,
      height: _posterSize,
      format: 'jpeg',
      quality: 80,
    );
  }
}
