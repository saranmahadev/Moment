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
    this.brightness = Brightness.light,
    this.reduceTransparency = false,
    required this.ground,
    required this.ink,
    this.onInk = const Color(0xFFFFFFFF),
    required this.secondary,
    required this.switchOff,
    required this.danger,
    this.solidSurface = const Color(0xFFF9FAFD),
    this.scrim = const Color(0xFFFFFFFF),
    this.highlight = const Color(0xFFF7D9A6),
    this.orbs = const [
      [Color(0xFFB7C3FF), Color(0xFF8B93F5)],
      [Color(0xFFFFD3BF), Color(0xFFFFAE9A)],
      [Color(0xFFBFEFDD), Color(0xFF8ADBC2)],
    ],
    this.orbOpacity = 0.8,
    this.mapGradient = const [Color(0xFFCDEBD3), Color(0xFFBFE0EC)],
    required this.typeColors,
    required this.typeTints,
    required this.card,
    required this.strong,
    required this.surface,
  });

  /// The light palette, straight from the mockups.
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

  /// The dark palette. The mockups are light only, so this one was
  /// designed for Phase 4: the same ink-blue family turned down to a
  /// near-black ground, type colours lifted until each passes 4.5:1 on
  /// the ground and on solid cards, and glass thinned to a faint film so
  /// it does not turn grey over a dark backdrop.
  static const MomentTokens dark = MomentTokens(
    brightness: Brightness.dark,
    ground: Color(0xFF0F1218),
    ink: Color(0xFFF1F3F8),
    onInk: Color(0xFF0F1218),
    secondary: Color(0xFFB7BECE),
    switchOff: Color(0xFF5A6172),
    danger: Color(0xFFF87171),
    solidSurface: Color(0xFF1A1F2A),
    scrim: Color(0xFF0F1218),
    highlight: Color(0xFF7A5417),
    orbs: [
      [Color(0xFF3A47A8), Color(0xFF272E7C)],
      [Color(0xFF8C4A38), Color(0xFF6B3226)],
      [Color(0xFF2B6B5B), Color(0xFF1C4F43)],
    ],
    orbOpacity: 0.5,
    mapGradient: [Color(0xFF1D3A30), Color(0xFF1A3340)],
    typeColors: {
      LogType.text: Color(0xFF8FB1FF),
      LogType.emoji: Color(0xFFF2A94E),
      LogType.photo: Color(0xFFF58BB6),
      LogType.video: Color(0xFFB9A0FA),
      LogType.audio: Color(0xFF56CDBF),
      LogType.location: Color(0xFF6BCB88),
    },
    typeTints: {
      LogType.text: Color.fromRGBO(143, 177, 255, 0.20),
      LogType.emoji: Color.fromRGBO(242, 169, 78, 0.22),
      LogType.photo: Color.fromRGBO(245, 139, 182, 0.20),
      LogType.video: Color.fromRGBO(185, 160, 250, 0.20),
      LogType.audio: Color.fromRGBO(86, 205, 191, 0.20),
      LogType.location: Color.fromRGBO(107, 203, 136, 0.20),
    },
    card: GlassRecipe(
      fillOpacity: 0.08,
      blurSigma: 24,
      saturationBoost: 1.40,
      borderOpacity: 0.12,
      shadowColor: Color.fromRGBO(0, 0, 0, 0.30),
      shadowOffset: Offset(0, 8),
      shadowBlurRadius: 32,
      defaultRadius: 24,
    ),
    strong: GlassRecipe(
      fillOpacity: 0.14,
      blurSigma: 28,
      saturationBoost: 1.50,
      borderOpacity: 0.16,
      shadowColor: Color.fromRGBO(0, 0, 0, 0.40),
      shadowOffset: Offset(0, 12),
      shadowBlurRadius: 40,
      defaultRadius: 34,
    ),
    surface: GlassRecipe(
      fillOpacity: 0.10,
      blurSigma: 26,
      saturationBoost: 1.45,
      borderOpacity: 0.14,
      shadowColor: Color.fromRGBO(0, 0, 0, 0.34),
      shadowOffset: Offset(0, 10),
      shadowBlurRadius: 36,
      defaultRadius: 28,
    ),
  );

  /// Light or dark: which palette this is.
  final Brightness brightness;

  /// Set by the "Reduce transparency" setting: glass surfaces are drawn
  /// solid ([solidSurface]) with no blur behind them.
  final bool reduceTransparency;
  final Color ground;
  final Color ink;

  /// Text and icons on an ink-filled control (primary buttons, the
  /// selected chip, the + button).
  final Color onInk;
  final Color secondary;
  final Color switchOff;
  final Color danger;

  /// What a glass surface becomes with Reduce Transparency on.
  final Color solidSurface;

  /// The base of small pills laid over media and maps (used translucent):
  /// light on the light palette, dark on the dark one, so [ink] reads.
  final Color scrim;

  /// Behind a search match.
  final Color highlight;

  /// The gradient pairs of the decorative orbs, and how strongly they
  /// show.
  final List<List<Color>> orbs;
  final double orbOpacity;

  /// The two ends of the stylised map's wash.
  final List<Color> mapGradient;

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
    Brightness? brightness,
    bool? reduceTransparency,
    Color? ground,
    Color? ink,
    Color? onInk,
    Color? secondary,
    Color? switchOff,
    Color? danger,
    Color? solidSurface,
    Color? scrim,
    Color? highlight,
    List<List<Color>>? orbs,
    double? orbOpacity,
    List<Color>? mapGradient,
    Map<LogType, Color>? typeColors,
    Map<LogType, Color>? typeTints,
    GlassRecipe? card,
    GlassRecipe? strong,
    GlassRecipe? surface,
  }) {
    return MomentTokens(
      brightness: brightness ?? this.brightness,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      ground: ground ?? this.ground,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      secondary: secondary ?? this.secondary,
      switchOff: switchOff ?? this.switchOff,
      danger: danger ?? this.danger,
      solidSurface: solidSurface ?? this.solidSurface,
      scrim: scrim ?? this.scrim,
      highlight: highlight ?? this.highlight,
      orbs: orbs ?? this.orbs,
      orbOpacity: orbOpacity ?? this.orbOpacity,
      mapGradient: mapGradient ?? this.mapGradient,
      typeColors: typeColors ?? this.typeColors,
      typeTints: typeTints ?? this.typeTints,
      card: card ?? this.card,
      strong: strong ?? this.strong,
      surface: surface ?? this.surface,
    );
  }

  @override
  MomentTokens lerp(ThemeExtension<MomentTokens>? other, double t) {
    // Fixed design tokens, not an animatable palette: a theme change
    // switches over halfway through the transition.
    if (other is! MomentTokens) return this;
    return t < 0.5 ? this : other;
  }
}
