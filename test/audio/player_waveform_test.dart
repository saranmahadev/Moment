import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/audio/player_waveform.dart';
import 'package:moment/design/theme.dart';

import '../support/screen_cases.dart';

void main() {
  group('resamplePeaks', () {
    test('gives exactly the number of bars asked for', () {
      expect(resamplePeaks([0.2, 0.9, 0.4], 56), hasLength(56));
      expect(resamplePeaks(List.filled(400, 0.5), 56), hasLength(56));
    });

    test('keeps the shape: the loud part stays loud', () {
      final bars = resamplePeaks([0.1, 0.1, 1.0, 0.1, 0.1], 5);
      expect(bars[2], greaterThan(bars[0]));
      expect(bars[2], greaterThan(bars[4]));
    });

    test('a recording with no peaks is a quiet flat line, not a crash', () {
      final bars = resamplePeaks(const [], 56);
      expect(bars, hasLength(56));
      expect(bars.every((b) => b > 0 && b < 0.2), isTrue);
    });

    test('values stay between 0 and 1', () {
      final bars = resamplePeaks([-1, 3, 0.5], 20);
      expect(bars.every((b) => b >= 0 && b <= 1), isTrue);
    });
  });

  group('PlayerWaveform', () {
    final seeks = <double>[];

    Future<void> pump(
      WidgetTester tester, {
      double fraction = 0.25,
      ThemeData? theme,
    }) async {
      seeks.clear();
      await tester.binding.setSurfaceSize(const Size(390, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? momentTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                child: PlayerWaveform(
                  peaks: const [0.2, 0.6, 0.9, 0.4, 0.7, 0.3],
                  duration: const Duration(minutes: 2, seconds: 41),
                  position: Duration(seconds: (161 * fraction).round()),
                  onSeekFraction: seeks.add,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a tap seeks to that point', (tester) async {
      await pump(tester);
      final rect = tester.getRect(find.byType(PlayerWaveform));

      await tester.tapAt(Offset(rect.left + rect.width / 2, rect.center.dy));

      expect(seeks, hasLength(1));
      expect(seeks.single, closeTo(0.5, 0.06));
    });

    testWidgets('dragging shows the time under the finger and seeks only on '
        'release', (tester) async {
      await pump(tester);
      final rect = tester.getRect(find.byType(PlayerWaveform));
      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width * 0.25, rect.center.dy),
      );
      await gesture.moveTo(
        Offset(rect.left + rect.width * 0.75, rect.center.dy),
      );
      await tester.pump();

      expect(find.text('2:00'), findsOneWidget); // 75% of 2:41 is 120.75 s
      expect(seeks, isEmpty);

      await gesture.up();
      await tester.pump();

      expect(seeks, hasLength(1));
      expect(seeks.single, closeTo(0.75, 0.06));
      expect(find.text('2:00'), findsNothing);
    });

    testWidgets('dragging past either end stays inside the recording', (
      tester,
    ) async {
      await pump(tester);
      final rect = tester.getRect(find.byType(PlayerWaveform));
      final gesture = await tester.startGesture(rect.center);
      await gesture.moveTo(Offset(rect.right + 200, rect.center.dy));
      await gesture.up();
      await tester.pump();

      expect(seeks.single, 1.0);
    });

    testWidgets(
      'screen readers get a slider with the position, not a drawing',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, fraction: 0.5);

        final node = tester.getSemantics(find.byType(PlayerWaveform));
        expect(node.label, contains('Playback position'));
        expect(node.value, '1:21 of 2:41');
        expect(node.flagsCollection.isSlider, isTrue);

        tester.semantics.increase(find.semantics.byLabel('Playback position'));
        await tester.pump();
        expect(seeks.single, greaterThan(0.5));

        handle.dispose();
      },
    );
  });

  group('goldens, as in the approved design', () {
    setUpAll(loadAppFonts);

    for (final brightness in Brightness.values) {
      for (final scrubbing in [false, true]) {
        testWidgets('${brightness.name}${scrubbing ? ', scrubbing' : ''}', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(390, 190));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: momentTheme(brightness: brightness),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 350,
                    child: PlayerWaveform(
                      peaks: [
                        for (var i = 0; i < 120; i++)
                          (0.15 + 0.8 * ((i * 37) % 17) / 17).clamp(0.0, 1.0),
                      ],
                      duration: const Duration(minutes: 2, seconds: 41),
                      position: const Duration(seconds: 102),
                      onSeekFraction: (_) {},
                      debugScrubbing: scrubbing,
                    ),
                  ),
                ),
              ),
            ),
          );
          await expectLater(
            find.byType(PlayerWaveform),
            matchesGoldenFile(
              'goldens/player_waveform_${brightness.name}'
              '${scrubbing ? '_scrubbing' : ''}.png',
            ),
          );
        });
      }
    }
  });
}
