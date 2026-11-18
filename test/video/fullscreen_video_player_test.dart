import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/video/fullscreen_video_player.dart';
import 'package:moment/video/video_player_model.dart';

import 'video_fakes.dart';

void main() {
  const length = Duration(seconds: 48);
  late FakeVideoPlaybackController playback;
  late VideoPlayerModel model;
  var closed = 0;

  Future<void> pump(WidgetTester tester) async {
    // Made inside the test, so its timers run on the test's clock.
    closed = 0;
    playback = FakeVideoPlaybackController();
    model = VideoPlayerModel(playback: playback, duration: length);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: FullscreenVideoPlayer(
          model: model,
          playback: playback,
          title: 'Lake at dusk',
          subtitle: 'Sunday 15 November · 17:58',
          frames: const [],
          onClose: () => closed++,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  }

  testWidgets('shows the controls to begin with: title, play, skips, exit', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Lake at dusk'), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
    expect(find.bySemanticsLabel('Back 15 seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('Forward 15 seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('Exit fullscreen'), findsWidgets);
    expect(find.byKey(const ValueKey('fake-video-view')), findsOneWidget);

    await finish(tester);
  });

  testWidgets('while playing the controls fade after three seconds and a tap '
      'brings them back', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.bySemanticsLabel('Pause'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.bySemanticsLabel('Pause'), findsNothing);
    expect(find.text('Lake at dusk'), findsNothing);

    await tester.tapAt(const Offset(422, 200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Pause'), findsOneWidget);

    await finish(tester);
  });

  testWidgets('paused, the controls stay', (tester) async {
    await pump(tester);

    await tester.pump(const Duration(seconds: 10));

    expect(find.bySemanticsLabel('Play'), findsOneWidget);

    await finish(tester);
  });

  testWidgets('double-tapping the right half jumps 10 s and says so', (
    tester,
  ) async {
    await pump(tester);

    await tester.tapAt(const Offset(700, 200));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(700, 200));
    await tester.pump(const Duration(milliseconds: 50));

    expect(playback.lastSeek, const Duration(seconds: 10));
    expect(find.text('10 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('10 s'), findsNothing);

    await finish(tester);
  });

  testWidgets('double-tapping the left half jumps back 10 s', (tester) async {
    await pump(tester);
    await playback.seek(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 10));

    await tester.tapAt(const Offset(100, 200));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(100, 200));
    await tester.pump(const Duration(milliseconds: 50));

    expect(playback.lastSeek, const Duration(seconds: 20));

    await tester.pump(const Duration(seconds: 1));
    await finish(tester);
  });

  testWidgets('the video can be pinched larger', (tester) async {
    await pump(tester);

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, 1.0);
    expect(viewer.maxScale, greaterThan(1.0));

    await finish(tester);
  });

  testWidgets('mute, loop and speed work from here too', (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Mute'));
    await tester.tap(find.bySemanticsLabel('Loop off'));
    await tester.tap(find.bySemanticsLabel('Speed 1.0 times'));
    await tester.pump();

    expect(playback.muted, isTrue);
    expect(playback.loop, isTrue);
    expect(playback.speed, 1.25);

    await finish(tester);
  });

  testWidgets('exit closes it', (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Exit fullscreen').first);

    expect(closed, 1);

    await finish(tester);
  });
}
