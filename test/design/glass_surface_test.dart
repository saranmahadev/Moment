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

  group('live blur is kept to what floats', () {
    Future<void> pumpVariant(
      WidgetTester tester,
      GlassVariant variant, {
      bool? blur,
    }) => tester.pumpWidget(
      host(
        SizedBox(
          width: 100,
          height: 100,
          child: GlassSurface(variant: variant, blur: blur),
        ),
      ),
    );

    testWidgets('the dock and sheets blur what is behind them', (tester) async {
      await pumpVariant(tester, GlassVariant.strong);

      final backdrop = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(backdrop.filter, isA<ImageFilter>());
      // The compose filter does not expose its inner sigma directly, but
      // its string form does.
      expect(backdrop.filter.toString(), contains('28.0'));
    });

    for (final variant in [GlassVariant.card, GlassVariant.surface]) {
      testWidgets('${variant.name}: a translucent fill, no blur', (
        tester,
      ) async {
        // A blur re-reads and re-blurs the screen behind it on every
        // frame; a list of them is what made scrolling stutter.
        await pumpVariant(tester, variant);

        expect(find.byType(BackdropFilter), findsNothing);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(GlassSurface),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.color!.a, lessThan(1));
        expect(decoration.border, isNotNull);
      });
    }

    testWidgets('a surface can ask for blur, or refuse it', (tester) async {
      await pumpVariant(tester, GlassVariant.card, blur: true);
      expect(find.byType(BackdropFilter), findsOneWidget);

      await pumpVariant(tester, GlassVariant.strong, blur: false);
      expect(find.byType(BackdropFilter), findsNothing);
    });
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

  group('with Reduce Transparency on', () {
    for (final palette in [MomentTokens.standard, MomentTokens.dark]) {
      testWidgets('${palette.brightness.name}: a solid surface, no blur', (
        tester,
      ) async {
        final tokens = palette.copyWith(reduceTransparency: true);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [tokens]),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: GlassSurface(
                    variant: GlassVariant.strong,
                    child: Text('on top'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('on top'), findsOneWidget);
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(DecoratedBox),
          ),
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, tokens.solidSurface);
        expect(decoration.color!.a, 1);
      });
    }
  });

  testWidgets('on dark, glass is a faint light film over the blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [MomentTokens.dark]),
        home: const Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: GlassSurface(variant: GlassVariant.strong),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(GlassSurface),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(
      decoration.color!.a,
      closeTo(MomentTokens.dark.strong.fillOpacity, 0.01),
    );
  });
}
