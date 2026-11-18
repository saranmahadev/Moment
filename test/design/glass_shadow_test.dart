import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/glass_surface.dart';
import 'package:moment/design/theme.dart';

/// A glass card's shadow falls outside it, as CSS box-shadow does in the
/// mockups. Drawn under its translucent fill, the offset shadow showed
/// through everywhere but a pale band along the top, so every card looked
/// like two stacked cards.
void main() {
  testWidgets('the inside of a card is one even tone, top to bottom', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momentTheme(),
        home: ColoredBox(
          color: const Color(0xFFEDF0F7),
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: const Padding(
                padding: EdgeInsets.all(40),
                child: SizedBox(
                  width: 200,
                  height: 120,
                  child: GlassSurface(variant: GlassVariant.card),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    late ByteDataPixels pixels;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      pixels = ByteDataPixels(
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
        image.width,
      );
    });

    // Inside the card, away from its 1px border and rounded corners:
    // just under the top edge, and in the middle.
    final nearTop = pixels.at(140, 46);
    final middle = pixels.at(140, 100);
    expect(
      (nearTop - middle).abs(),
      lessThanOrEqualTo(2),
      reason: 'top $nearTop, middle $middle',
    );

    // And there is a shadow below it, outside.
    final below = pixels.at(140, 172);
    final ground = pixels.at(4, 4);
    expect(below, lessThan(ground));
  });
}

/// Brightness (sum of R, G and B) of pixels in a raw RGBA image.
class ByteDataPixels {
  ByteDataPixels(this.data, this.width);
  final ByteData data;
  final int width;

  int at(int x, int y) {
    final i = (y * width + x) * 4;
    return data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
  }
}
