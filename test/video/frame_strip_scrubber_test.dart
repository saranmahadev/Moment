import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/video/frame_strip_scrubber.dart';

import '../support/screen_cases.dart';

void main() {
  late Directory tempDir;
  final seeks = <double>[];
  final scrubs = <double?>[];

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('frame_strip_test_');
    seeks.clear();
    scrubs.clear();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<void> pump(
    WidgetTester tester, {
    double fraction = 0.4,
    List<File?>? frames,
    ThemeData? theme,
    bool debugScrubbing = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme ?? momentTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 318,
              child: FrameStripScrubber(
                frames: frames ?? List.filled(10, null),
                duration: const Duration(seconds: 48),
                position: Duration(milliseconds: (48000 * fraction).round()),
                onSeekFraction: seeks.add,
                onScrubChanged: scrubs.add,
                debugScrubbing: debugScrubbing,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a tap seeks to that point', (tester) async {
    await pump(tester);
    final rect = tester.getRect(find.byType(FrameStripScrubber));

    await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy + 10));

    expect(seeks.single, closeTo(0.25, 0.04));
  });

  testWidgets('dragging reports the finger, shows its time, and seeks on release', (
    tester,
  ) async {
    await pump(tester);
    final rect = tester.getRect(find.byType(FrameStripScrubber));
    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width * 0.4, rect.center.dy + 10),
    );
    await gesture.moveTo(Offset(rect.left + rect.width * 0.75, rect.center.dy + 10));
    await tester.pump();

    expect(find.text('0:36'), findsOneWidget); // 75% of 48 s
    expect(scrubs.last, closeTo(0.75, 0.04));
    expect(seeks, isEmpty);

    await gesture.up();
    await tester.pump();

    expect(seeks.single, closeTo(0.75, 0.04));
    expect(scrubs.last, isNull);
    expect(find.text('0:36'), findsNothing);
  });

  testWidgets('the preview shows the frame nearest the finger', (tester) async {
    final frames = [
      for (var i = 0; i < 10; i++)
        File('${tempDir.path}/$i.jpg')..writeAsBytesSync([1, 2, 3]),
    ];
    await pump(tester, frames: frames);
    final rect = tester.getRect(find.byType(FrameStripScrubber));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveTo(Offset(rect.left + rect.width * 0.9, rect.center.dy));
    await tester.pump();

    final previews = tester
        .widgetList<Image>(find.byKey(const ValueKey('scrub-preview')))
        .toList();
    expect(previews, hasLength(1));
    expect(((previews.single.image) as FileImage).file.path, frames[9].path);

    await gesture.up();
  });

  testWidgets('without frames it still scrubs and shows the time', (tester) async {
    await pump(tester);
    final rect = tester.getRect(find.byType(FrameStripScrubber));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveTo(Offset(rect.right + 100, rect.center.dy));
    await tester.pump();

    expect(find.text('0:48'), findsOneWidget);
    await gesture.up();
    expect(seeks.single, 1.0);
  });

  testWidgets('for screen readers it is one slider with the position', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, fraction: 0.5);

    final node = tester.getSemantics(find.byType(FrameStripScrubber));
    expect(node.label, contains('Video position'));
    expect(node.value, '0:24 of 0:48');
    expect(node.flagsCollection.isSlider, isTrue);

    tester.semantics.increase(find.semantics.byLabel('Video position'));
    await tester.pump();
    expect(seeks.single, greaterThan(0.5));

    handle.dispose();
  });

  group('goldens, as in the approved design', () {
    setUpAll(loadAppFonts);

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}, scrubbing', (tester) async {
        await pump(
          tester,
          fraction: 0.7,
          theme: momentTheme(brightness: brightness),
          debugScrubbing: true,
        );
        await expectLater(
          find.byType(FrameStripScrubber),
          matchesGoldenFile('goldens/frame_strip_${brightness.name}.png'),
        );
      });
    }
  });
}
