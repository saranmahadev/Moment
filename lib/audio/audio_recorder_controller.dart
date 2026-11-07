import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

/// How often the recorder samples amplitude while recording. Each sample
/// becomes one point in the saved waveform, so this also sets how far
/// apart the peaks are in time.
const audioSampleInterval = Duration(milliseconds: 200);

/// Records a voice note and reports its live amplitude. Wraps the `record`
/// package so tests can supply a fake instead of touching the microphone.
/// Manages its own file: callers never see a path until [stop] returns one.
abstract interface class AudioRecorderController {
  /// Normalized (0.0 to 1.0) amplitude, sampled every [audioSampleInterval]
  /// while recording.
  Stream<double> get amplitudeStream;

  Future<bool> hasPermission();
  Future<void> start();
  Future<void> pause();
  Future<void> resume();

  /// Stops recording and returns the path of the finished file, or null if
  /// nothing was recorded.
  Future<String?> stop();

  /// Stops recording and discards the file.
  Future<void> cancel();

  Future<void> dispose();
}

class DeviceAudioRecorderController implements AudioRecorderController {
  final _recorder = record.AudioRecorder();

  static double _normalize(double dBFS) {
    const floor = -60.0;
    if (dBFS.isNaN || dBFS < floor) return 0;
    return ((dBFS - floor) / -floor).clamp(0.0, 1.0);
  }

  @override
  Stream<double> get amplitudeStream => _recorder
      .onAmplitudeChanged(audioSampleInterval)
      .map((amplitude) => _normalize(amplitude.current));

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'recording-${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    await _recorder.start(
      const record.RecordConfig(encoder: record.AudioEncoder.aacLc),
      path: path,
    );
  }

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}
