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

  /// Plays the recording again from the start each time it ends.
  Future<void> setLoop(bool on);
  Future<void> dispose();
}

/// Whether the play button should show "pause". just_audio keeps `playing`
/// true after the clip ends, so the end must count as stopped, or the button
/// stays on pause and the note cannot be replayed.
bool isAudibleState(just_audio.PlayerState state) =>
    state.playing &&
    state.processingState != just_audio.ProcessingState.completed;

class DeviceAudioPlaybackController implements AudioPlaybackController {
  final _player = just_audio.AudioPlayer();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream =>
      _player.playerStateStream.map(isAudibleState).distinct();

  @override
  Future<void> load(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> play() async {
    // After the end, play from the start rather than doing nothing.
    if (_player.processingState == just_audio.ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setLoop(bool on) => _player.setLoopMode(
    on ? just_audio.LoopMode.one : just_audio.LoopMode.off,
  );

  @override
  Future<void> dispose() => _player.dispose();
}
