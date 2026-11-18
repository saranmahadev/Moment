import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/tokens.dart';
import 'package:moment/video/video_poster.dart';

void main() {
  Future<Image> pumpPoster(WidgetTester tester, VideoPoster poster) async {
    await tester.pumpWidget(
      MaterialApp(home: SizedBox(width: 200, height: 160, child: poster)),
    );
    return tester.widget<Image>(find.byType(Image));
  }

  testWidgets('a poster in a tile or card is decoded small', (tester) async {
    final image = await pumpPoster(
      tester,
      const VideoPoster(
        path: '/none/poster.jpg',
        tokens: MomentTokens.standard,
        decodeWidth: VideoPoster.tileDecodeWidth,
      ),
    );
    final provider = image.image as ResizeImage;
    expect(provider.width, VideoPoster.tileDecodeWidth);
    expect((provider.imageProvider as FileImage).file.path, '/none/poster.jpg');
  });

  testWidgets('without a decode width it is decoded as it is', (tester) async {
    final image = await pumpPoster(
      tester,
      VideoPoster(
        path: File('/none/p.jpg').path,
        tokens: MomentTokens.standard,
      ),
    );
    expect(image.image, isA<FileImage>());
  });

  test('tiles are decoded wide enough for a sharp 2x2 tile on a phone', () {
    // A 180-point card on a 3x screen is 540 pixels across at most.
    expect(VideoPoster.tileDecodeWidth, greaterThanOrEqualTo(540));
  });
}
