import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/design/tokens.dart';

void main() {
  group('momentTheme', () {
    test('carries the design tokens', () {
      expect(momentTheme().extension<MomentTokens>(), MomentTokens.standard);
    });

    test('uses Ground as the scaffold background', () {
      expect(
        momentTheme().scaffoldBackgroundColor,
        MomentTokens.standard.ground,
      );
    });

    test('UI text defaults to Inter', () {
      expect(momentTheme().textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(momentTheme().textTheme.labelLarge?.fontFamily, 'Inter');
    });

    test('headline and title styles use Newsreader for the user\'s words', () {
      expect(momentTheme().textTheme.headlineMedium?.fontFamily, 'Newsreader');
      expect(momentTheme().textTheme.titleLarge?.fontFamily, 'Newsreader');
    });
  });

  group('momentTheme, dark', () {
    final dark = momentTheme(brightness: Brightness.dark);

    test('is a dark theme carrying the dark tokens', () {
      expect(dark.brightness, Brightness.dark);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.extension<MomentTokens>(), MomentTokens.dark);
      expect(dark.scaffoldBackgroundColor, MomentTokens.dark.ground);
    });

    test('keeps the same typefaces', () {
      expect(dark.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(dark.textTheme.titleLarge?.fontFamily, 'Newsreader');
    });
  });

  group('momentTheme, reduce transparency', () {
    test('marks the tokens of either brightness', () {
      for (final brightness in Brightness.values) {
        final tokens = momentTheme(
          brightness: brightness,
          reduceTransparency: true,
        ).extension<MomentTokens>()!;
        expect(tokens.reduceTransparency, isTrue, reason: brightness.name);
        expect(tokens.brightness, brightness);
      }
    });
  });
}
