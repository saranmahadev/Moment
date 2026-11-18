@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen_cases.dart';

/// Writes every screen, light and dark, to `build/previews/` (or the
/// directory in MOMENT_PREVIEW_DIR) at twice the logical size, with the
/// app's typefaces and, where the machine has one, an emoji font. These
/// are for a person to look at when approving a design; nothing is
/// compared, so the test is skipped unless asked for (see dart_test.yaml).
void main() {
  const emojiFont = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
  final out = Directory(
    Platform.environment['MOMENT_PREVIEW_DIR'] ?? 'build/previews',
  );
  var hasEmoji = false;

  setUpAll(() async {
    await loadAppFonts();
    if (File(emojiFont).existsSync()) {
      final loader = FontLoader('Preview Emoji')
        ..addFont(File(emojiFont).readAsBytes().then(ByteData.sublistView));
      await loader.load();
      hasEmoji = true;
    }
    out.createSync(recursive: true);
  });

  for (final screen in screenCases) {
    for (final brightness in Brightness.values) {
      for (final solid in [false, true]) {
        final name =
            '${screen.name}_${brightness.name}${solid ? '_solid' : ''}';
        testWidgets(name, (tester) async {
          // Soft shadows, as a phone draws them (see the goldens).
          debugDisableShadows = false;
          final ScreenFixture fixture;
          try {
            fixture = await pumpScreenCase(
              tester,
              screen,
              brightness: brightness,
              reduceTransparency: solid,
              fontFamilyFallback: hasEmoji ? const ['Preview Emoji'] : null,
            );

            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(screenBoundaryKey),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                '${out.path}/$name.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
            });
          } finally {
            debugDisableShadows = true;
          }

          await closeScreenCase(tester, fixture);
        });
      }
    }
  }
}
