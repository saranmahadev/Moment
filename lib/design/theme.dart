import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds Moment's single light theme (dark mode is designed at the start
/// of Phase 4): Inter for UI text and controls, Newsreader for the user's
/// own words, and [MomentTokens.standard] as a [ThemeExtension].
ThemeData momentTheme() {
  const tokens = MomentTokens.standard;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: tokens.ground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.ink,
      brightness: Brightness.light,
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
    extensions: const [tokens],
  );
}
