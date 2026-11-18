import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/log.dart';
import 'video_probe.dart';

/// The small pictures along the player's scrubber: [count] frames, one from
/// the middle of each equal slice of the clip, made the first time a video
/// is opened and kept in the cache folder (the system may clear it; they are
/// simply made again). Never part of a backup, and never needed.
class VideoFrameStrip {
  VideoFrameStrip({
    required this.probe,
    required this.cacheRoot,
    this.count = 12,
    this.maxCachedVideos = 40,
  });

  final VideoProbe probe;
  final Directory cacheRoot;
  final int count;

  /// How many videos keep frames; the least recently opened are dropped.
  final int maxCachedVideos;

  Directory get _root => Directory(p.join(cacheRoot.path, 'video-frames'));

  Directory dirFor(String logId) => Directory(p.join(_root.path, logId));

  /// The strip for [log], as a growing list: first all gaps (null), then a
  /// frame at a time. A frame that cannot be made stays a gap.
  Stream<List<File?>> framesFor(VideoLog log) async* {
    final dir = dirFor(log.id);
    await dir.create(recursive: true);
    // A marker file's time says when this video was last opened.
    final used = File(p.join(dir.path, '.used'));
    await used.writeAsString('');
    await used.setLastModified(DateTime.now());

    final files = [
      for (var i = 0; i < count; i++) File(p.join(dir.path, '$i.jpg')),
    ];
    final frames = <File?>[for (final f in files) f.existsSync() ? f : null];
    yield List.of(frames);

    final length = log.duration.inMicroseconds;
    for (var i = 0; i < count; i++) {
      if (frames[i] != null) continue;
      final at = Duration(microseconds: (length * (i + 0.5) / count).floor());
      try {
        if (await probe.writeFrame(File(log.path), files[i], at) &&
            files[i].existsSync()) {
          frames[i] = files[i];
        }
      } catch (_) {
        // A frame that cannot be read is a gap.
      }
      yield List.of(frames);
    }
    await _prune(keep: log.id);
  }

  /// Removes one video's frames, for when the video is deleted for good.
  Future<void> delete(String logId) async {
    final dir = dirFor(logId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  DateTime _usedAt(Directory dir) {
    final marker = File(p.join(dir.path, '.used'));
    return marker.existsSync() ? marker.lastModifiedSync() : DateTime(1970);
  }

  Future<void> _prune({required String keep}) async {
    if (!await _root.exists()) return;
    final dirs = [
      for (final e in _root.listSync())
        if (e is Directory) e,
    ]..sort((a, b) => _usedAt(b).compareTo(_usedAt(a)));
    for (final dir in dirs.skip(maxCachedVideos)) {
      if (p.basename(dir.path) == keep) continue;
      await dir.delete(recursive: true);
    }
  }
}
