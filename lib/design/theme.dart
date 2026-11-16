import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds Moment's theme for [brightness]: Inter for UI text and
/// controls, Newsreader for the user's own words, and the matching
/// [MomentTokens] as a [ThemeExtension]. With [reduceTransparency] the
/// tokens tell every glass surface to draw solid.
ThemeData momentTheme({
  Brightness brightness = Brightness.light,
  bool reduceTransparency = false,
}) {
  final palette = brightness == Brightness.dark
      ? MomentTokens.dark
      : MomentTokens.standard;
  final tokens = reduceTransparency
      ? palette.copyWith(reduceTransparency: true)
      : palette;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: tokens.ground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MomentTokens.standard.ink,
      brightness: brightness,
    ),
    fontFamily: 'Inter',
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(fontFamily: 'Inter')
        .copyWith(
          // The user's own words and screen titles are set in Newsreader; see
          // design/README.md's "Type colours at a glance".
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontFamily: 'Newsreader',
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontFamily: 'Newsreader',
          ),
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontFamily: 'Newsreader',
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontFamily: 'Newsreader',
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: 'Newsreader',
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Newsreader',
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: 'Newsreader',
          ),
        ),
    extensions: [tokens],
  );
}
