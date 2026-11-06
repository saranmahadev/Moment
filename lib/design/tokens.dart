import 'package:flutter/material.dart';

import '../domain/log_type.dart';

/// One glass-surface recipe: how translucent the fill is, how strong the
/// blur and saturation boost behind it are, and its border and shadow.
///
/// Values come verbatim from the `GL` table and `glass()` helper in
/// design/generators/lib.py, which design/README.md names as the source of
/// truth for exact numbers.
@immutable
class GlassRecipe {
  const GlassRecipe({
    required this.fillOpacity,
    required this.blurSigma,
    required this.saturationBoost,
    required this.borderOpacity,
    required this.shadowColor,
    required this.shadowOffset,
    required this.shadowBlurRadius,
    required this.defaultRadius,
  });

  /// Opacity of the white fill behind the blur, 0 to 1.
  final double fillOpacity;

  /// Gaussian blur sigma applied to whatever is behind the surface.
  final double blurSigma;

  /// Saturation multiplier applied to the blurred backdrop, e.g. 1.60 for
  /// CSS's `saturate(160%)`.
  final double saturationBoost;

  /// Opacity of the 1px white border, 0 to 1.
  final double borderOpacity;

  final Color shadowColor;
  final Offset shadowOffset;
  final double shadowBlurRadius;

  /// Corner radius used when a surface does not ask for a different one.
  final double defaultRadius;
}

/// Design tokens shared across Moment's UI: base colours, one colour per
/// log type, and the three glass-surface recipes. See design/README.md.
@immutable
class MomentTokens extends ThemeExtension<MomentTokens> {
  const MomentTokens({
    required this.ground,
    required this.ink,
    required this.secondary,
    required this.switchOff,
    required this.danger,
    required this.typeColors,
    required this.typeTints,
    required this.card,
    required this.strong,
    required this.surface,
  });

  /// Moment's one and only theme for now; dark mode is designed at the
  /// start of Phase 4.
  static const MomentTokens standard = MomentTokens(
    ground: Color(0xFFEDF0F7),
    ink: Color(0xFF1B1F2A),
    secondary: Color(0xFF3A4152),
    switchOff: Color(0xFF8B91A3),
    danger: Color(0xFFB91C1C),
    typeColors: {
      LogType.text: Color(0xFF1D4ED8),
      LogType.emoji: Color(0xFFB45309),
      LogType.photo: Color(0xFFBE185D),
      LogType.video: Color(0xFF6D28D9),
      LogType.audio: Color(0xFF0F766E),
      LogType.location: Color(0xFF15803D),
    },
    typeTints: {
      LogType.text: Color.fromRGBO(29, 78, 216, 0.14),
      LogType.emoji: Color.fromRGBO(245, 158, 11, 0.24),
      LogType.photo: Color.fromRGBO(236, 72, 153, 0.16),
      LogType.video: Color.fromRGBO(139, 92, 246, 0.18),
      LogType.audio: Color.fromRGBO(20, 184, 166, 0.20),
      LogType.location: Color.fromRGBO(34, 197, 94, 0.20),
    },
    card: GlassRecipe(
      fillOpacity: 0.46,
      blurSigma: 24,
      saturationBoost: 1.60,
      borderOpacity: 0.72,
      shadowColor: Color.fromRGBO(40, 50, 100, 0.10),
      shadowOffset: Offset(0, 8),
      shadowBlurRadius: 32,
      defaultRadius: 24,
    ),
    strong: GlassRecipe(
      fillOpacity: 0.62,
      blurSigma: 28,
      saturationBoost: 1.70,
      borderOpacity: 0.8,
      shadowColor: Color.fromRGBO(40, 50, 100, 0.16),
      shadowOffset: Offset(0, 12),
      shadowBlurRadius: 40,
      // design/README.md gives a range (32 to 36) rather than one number;
      // individual screens can override via GlassSurface.borderRadius.
      defaultRadius: 34,
    ),
    surface: GlassRecipe(
      fillOpacity: 0.5,
      blurSigma: 26,
      saturationBoost: 1.65,
      borderOpacity: 0.75,
      shadowColor: Color.fromRGBO(40, 50, 100, 0.12),
      shadowOffset: Offset(0, 10),
      shadowBlurRadius: 36,
      defaultRadius: 28,
    ),
  );

  final Color ground;
  final Color ink;
  final Color secondary;
  final Color switchOff;
  final Color danger;

  final Map<LogType, Color> typeColors;
  final Map<LogType, Color> typeTints;

  /// Feed cards.
  final GlassRecipe card;

  /// The tab dock and modal sheets.
  final GlassRecipe strong;

  /// The writing surface: the largest glass area, kept quiet.
  final GlassRecipe surface;

  Color colorFor(LogType type) => typeColors[type]!;
  Color tintFor(LogType type) => typeTints[type]!;

  @override
  MomentTokens copyWith({
    Color? ground,
    Color? ink,
    Color? secondary,
    Color? switchOff,
    Color? danger,
    Map<LogType, Color>? typeColors,
    Map<LogType, Color>? typeTints,
    GlassRecipe? card,
    GlassRecipe? strong,
    GlassRecipe? surface,
  }) {
    return MomentTokens(
      ground: ground ?? this.ground,
      ink: ink ?? this.ink,
      secondary: secondary ?? this.secondary,
      switchOff: switchOff ?? this.switchOff,
      danger: danger ?? this.danger,
      typeColors: typeColors ?? this.typeColors,
      typeTints: typeTints ?? this.typeTints,
      card: card ?? this.card,
      strong: strong ?? this.strong,
      surface: surface ?? this.surface,
    );
  }

  @override
  MomentTokens lerp(ThemeExtension<MomentTokens>? other, double t) {
    // These are fixed design tokens, not an animatable palette: until a
    // second theme (dark mode, Phase 4) exists there is nothing to
    // interpolate between.
    if (other is! MomentTokens) return this;
    return t < 0.5 ? this : other;
  }
}
