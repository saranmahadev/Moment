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

/// A translucent, blurred surface in one of Moment's glass recipes: a
/// white fill over a saturation-boosted blur of whatever is behind it, with
/// a soft 1px border and shadow.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.variant,
    this.borderRadius,
    this.child,
  });

  final GlassVariant variant;

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

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.compose(
          outer: ColorFilter.matrix(_saturationMatrix(recipe.saturationBoost)),
          inner: ImageFilter.blur(
            sigmaX: recipe.blurSigma,
            sigmaY: recipe.blurSigma,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: recipe.fillOpacity),
            border: Border.all(
              color: Colors.white.withValues(alpha: recipe.borderOpacity),
            ),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: recipe.shadowColor,
                offset: recipe.shadowOffset,
                blurRadius: recipe.shadowBlurRadius,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
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
