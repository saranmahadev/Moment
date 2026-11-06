import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/glass_surface.dart';
import 'package:moment/design/tokens.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      theme: ThemeData(extensions: const [MomentTokens.standard]),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('renders a BackdropFilter blurring by the recipe sigma', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 100,
          height: 100,
          child: GlassSurface(variant: GlassVariant.card),
        ),
      ),
    );

    final backdrop = tester.widget<BackdropFilter>(
      find.byType(BackdropFilter),
    );
    final filter = backdrop.filter;
    expect(filter, isA<ImageFilter>());
    // The compose filter does not expose its inner sigma directly, but its
    // string form does, which is the simplest faithful way to assert it.
    expect(filter.toString(), contains('24.0'));
  });

  testWidgets('card variant uses the card recipe default radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 100,
          height: 100,
          child: GlassSurface(variant: GlassVariant.card),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = decorated.decoration as BoxDecoration;
    final radius = decoration.borderRadius! as BorderRadius;
    expect(radius.topLeft.x, MomentTokens.standard.card.defaultRadius);
    expect(
      decoration.color!.a,
      closeTo(MomentTokens.standard.card.fillOpacity, 0.01),
    );
  });

  testWidgets('an explicit borderRadius overrides the recipe default', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 100,
          height: 100,
          child: GlassSurface(variant: GlassVariant.surface, borderRadius: 12),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = decorated.decoration as BoxDecoration;
    final radius = decoration.borderRadius! as BorderRadius;
    expect(radius.topLeft.x, 12);
  });

  testWidgets('renders its child on top of the glass', (tester) async {
    await tester.pumpWidget(
      host(
        const GlassSurface(
          variant: GlassVariant.card,
          child: Text('Quiet evening.'),
        ),
      ),
    );

    expect(find.text('Quiet evening.'), findsOneWidget);
  });

  testWidgets('matches its approved baseline', (tester) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 200,
          height: 120,
          child: GlassSurface(
            variant: GlassVariant.card,
            child: Center(child: Text('Quiet evening.')),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(GlassSurface),
      matchesGoldenFile('goldens/glass_surface_card.png'),
    );
  });
}
