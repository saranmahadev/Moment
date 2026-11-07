import 'package:just_audio/just_audio.dart' as just_audio;

/// Plays back a recorded voice note. Wraps `just_audio` so tests can supply
/// a fake instead of touching the audio hardware.
abstract interface class AudioPlaybackController {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;

  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

class DeviceAudioPlaybackController implements AudioPlaybackController {
  final _player = just_audio.AudioPlayer();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream =>
      _player.playerStateStream.map((state) => state.playing);

  @override
  Future<void> load(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() => _player.dispose();
}
