import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/capture_frame.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log_type.dart';

/// The New photo and New video screens before anything is chosen: the
/// mockup's viewfinder frame and shutter, opening the phone's own camera.
void main() {
  Future<List<String>> pump(WidgetTester tester, LogType type) async {
    final taps = <String>[];
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: Scaffold(
          body: CaptureFrame(
            type: type,
            captureLabel: type == LogType.photo ? 'Take Photo' : 'Record Video',
            onCapture: () => taps.add('capture'),
            onChoose: () => taps.add('choose'),
          ),
        ),
      ),
    );
    return taps;
  }

  testWidgets('a frame, a shutter and the library', (tester) async {
    final taps = await pump(tester, LogType.photo);
    expect(find.byKey(const ValueKey('capture-frame')), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Library'), findsOneWidget);
    expect(find.text('Opens your camera'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Take Photo'));
    await tester.tap(find.bySemanticsLabel('Choose from Library'));
    expect(taps, ['capture', 'choose']);
  });

  testWidgets('the shutter is the large one, in the middle', (tester) async {
    await pump(tester, LogType.video);
    final shutter = tester.getRect(find.bySemanticsLabel('Record Video'));
    final library = tester.getRect(
      find.bySemanticsLabel('Choose from Library'),
    );
    expect(shutter.center.dx, closeTo(195, 2));
    expect(library.center.dx, lessThan(shutter.center.dx));
    expect(shutter.height, greaterThanOrEqualTo(72));
    final frame = tester.getRect(find.byKey(const ValueKey('capture-frame')));
    expect(frame.bottom, lessThan(shutter.top));
  });
}
