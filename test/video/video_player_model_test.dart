import 'package:flutter_test/flutter_test.dart';
import 'package:moment/video/video_player_model.dart';

import 'video_fakes.dart';

void main() {
  const length = Duration(seconds: 48);
  late FakeVideoPlaybackController playback;
  late VideoPlayerModel model;

  setUp(() {
    playback = FakeVideoPlaybackController();
    model = VideoPlayerModel(playback: playback, duration: length);
  });

  tearDown(() => model.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts stopped at zero, not yet played', () {
    expect(model.playing, isFalse);
    expect(model.started, isFalse);
    expect(model.position, Duration.zero);
    expect(model.ended, isFalse);
    expect(model.speed, 1.0);
    expect(model.muted, isFalse);
    expect(model.loop, isFalse);
  });

  test('play starts it and marks it started, pause stops it', () async {
    await model.togglePlay();
    await settle();
    expect(model.playing, isTrue);
    expect(model.started, isTrue);

    await model.togglePlay();
    await settle();
    expect(model.playing, isFalse);
    expect(model.started, isTrue);
  });

  test('follows the position the player reports', () async {
    await playback.seek(const Duration(seconds: 12));
    await settle();
    expect(model.position, const Duration(seconds: 12));
  });

  test('skips are clamped to the start and the end', () async {
    await model.skip(const Duration(seconds: -15));
    expect(playback.lastSeek, Duration.zero);

    await model.skip(const Duration(seconds: 15));
    await settle();
    expect(playback.lastSeek, const Duration(seconds: 15));

    await model.skip(const Duration(minutes: 5));
    expect(playback.lastSeek, length);
  });

  test('seeking to a fraction lands on that point of the clip', () async {
    await model.seekToFraction(0.5);
    expect(playback.lastSeek, const Duration(seconds: 24));
    await model.seekToFraction(2);
    expect(playback.lastSeek, length);
  });

  test('when it reaches the end it is "ended", and play replays it', () async {
    await model.togglePlay();
    playback.ended();
    await settle();

    expect(model.ended, isTrue);
    expect(model.playing, isFalse);

    await model.togglePlay();
    await settle();
    expect(playback.lastSeek, Duration.zero);
    expect(model.playing, isTrue);
    expect(model.ended, isFalse);
  });

  test('a clip that was never played is not "ended" at zero', () {
    expect(model.ended, isFalse);
  });

  test('looping is passed on, and a looping clip never counts as ended', () async {
    await model.toggleLoop();
    expect(playback.loop, isTrue);
    expect(model.loop, isTrue);

    await model.togglePlay();
    playback.ended();
    await settle();
    expect(model.ended, isFalse);

    await model.toggleLoop();
    expect(playback.loop, isFalse);
  });

  test('mute is passed on and toggles back', () async {
    await model.toggleMute();
    expect(playback.muted, isTrue);
    expect(model.muted, isTrue);
    await model.toggleMute();
    expect(playback.muted, isFalse);
  });

  test('speed steps 1, 1.25, 1.5, 2, 0.5 and round again', () async {
    final seen = <double>[];
    for (var i = 0; i < 5; i++) {
      await model.nextSpeed();
      seen.add(playback.speed!);
    }
    expect(seen, [1.25, 1.5, 2.0, 0.5, 1.0]);
    expect(model.speed, 1.0);
  });

  test('tells listeners when anything changes', () async {
    var calls = 0;
    model.addListener(() => calls++);

    await model.toggleMute();
    await playback.seek(const Duration(seconds: 3));
    await settle();

    expect(calls, greaterThanOrEqualTo(2));
  });
}
