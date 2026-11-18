import 'dart:ui';

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Which of Moment's three glass recipes a [GlassSurface] uses. See
/// design/README.md.
enum GlassVariant {
  /// Feed cards.
  card,

  /// The tab dock and modal sheets.
  strong,

  /// The writing surface: the largest glass area, kept quiet.
  surface,
}

/// A glass surface in one of Moment's recipes: a translucent white film
/// with a soft 1px border and shadow, and, for the dock and sheets, a
/// saturation-boosted blur of whatever is behind it (see [blur]). With
/// Reduce Transparency on it is a solid surface of the same shape instead.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.variant,
    this.borderRadius,
    this.blur,
    this.child,
  });

  final GlassVariant variant;

  /// Whether to blur what is behind the surface. Left unset, only
  /// [GlassVariant.strong] does: the dock and sheets, which float above
  /// everything. A blur re-reads and re-blurs the screen behind it on
  /// every frame, so cards, tiles and buttons (there can be a dozen on a
  /// screen, and they scroll) are a translucent fill with no blur; that
  /// is what keeps scrolling smooth on a mid-range phone.
  final bool? blur;

  /// Overrides the recipe's default corner radius.
  final double? borderRadius;

  final Widget? child;

  GlassRecipe _recipeOf(MomentTokens tokens) => switch (variant) {
    GlassVariant.card => tokens.card,
    GlassVariant.strong => tokens.strong,
    GlassVariant.surface => tokens.surface,
  };

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final recipe = _recipeOf(tokens);
    final radius = BorderRadius.circular(borderRadius ?? recipe.defaultRadius);

    final shadow = [
      BoxShadow(
        color: recipe.shadowColor,
        offset: recipe.shadowOffset,
        blurRadius: recipe.shadowBlurRadius,
      ),
    ];

    if (tokens.reduceTransparency) {
      // Reduce Transparency: the same shape and shadow, filled solid, with
      // nothing blurred behind it.
      return ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.solidSurface,
            border: Border.all(color: tokens.ink.withValues(alpha: 0.10)),
            borderRadius: radius,
            boxShadow: shadow,
          ),
          child: child,
        ),
      );
    }

    final film = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: recipe.fillOpacity),
        border: Border.all(
          color: Colors.white.withValues(alpha: recipe.borderOpacity),
        ),
        borderRadius: radius,
      ),
      child: child,
    );

    final glass = (blur ?? variant == GlassVariant.strong)
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.compose(
                outer: ColorFilter.matrix(
                  _saturationMatrix(recipe.saturationBoost),
                ),
                inner: ImageFilter.blur(
                  sigmaX: recipe.blurSigma,
                  sigmaY: recipe.blurSigma,
                ),
              ),
              child: film,
            ),
          )
        : ClipRRect(borderRadius: radius, child: film);

    // The shadow falls outside the glass only, as CSS box-shadow does in
    // the mockups. Painted under the translucent fill, the offset shadow
    // showed through everywhere but a pale band along the top edge.
    return CustomPaint(
      painter: _OuterShadowPainter(radius: radius, shadows: shadow),
      child: glass,
    );
  }
}

/// Paints [shadows] around a rounded rectangle the size of the child,
/// leaving its inside untouched.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({required this.radius, required this.shadows});

  final BorderRadius radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = radius.toRRect(Offset.zero & size);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(shape.outerRect.inflate(200)),
      Path()..addRRect(shape),
    );
    canvas.save();
    canvas.clipPath(outside);
    for (final shadow in shadows) {
      canvas.drawRRect(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.radius != radius || old.shadows != shadows;
}

/// A saturation-boosting colour matrix equivalent to CSS's
/// `saturate(amount * 100%)`. Uses the same formula Flutter itself uses to
/// recreate iOS's backdrop blur: see
/// `CupertinoDesktopTextSelectionToolbar._matrixWithSaturation`.
List<double> _saturationMatrix(double saturation) {
  final r = 0.213 * (1 - saturation);
  final g = 0.715 * (1 - saturation);
  final b = 0.072 * (1 - saturation);
  return [
    r + saturation, g, b, 0, 0, //
    r, g + saturation, b, 0, 0, //
    r, g, b + saturation, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
