import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/tokens.dart';
import 'package:moment/domain/log_type.dart';

void main() {
  final tokens = MomentTokens.standard;

  group('base colours', () {
    test('match design/README.md', () {
      expect(tokens.ground, const Color(0xFFEDF0F7));
      expect(tokens.ink, const Color(0xFF1B1F2A));
      expect(tokens.secondary, const Color(0xFF3A4152));
      expect(tokens.switchOff, const Color(0xFF8B91A3));
      expect(tokens.danger, const Color(0xFFB91C1C));
    });
  });

  group('type colours', () {
    test('one per log type, matching the design language board', () {
      expect(tokens.colorFor(LogType.text), const Color(0xFF1D4ED8));
      expect(tokens.colorFor(LogType.emoji), const Color(0xFFB45309));
      expect(tokens.colorFor(LogType.photo), const Color(0xFFBE185D));
      expect(tokens.colorFor(LogType.video), const Color(0xFF6D28D9));
      expect(tokens.colorFor(LogType.audio), const Color(0xFF0F766E));
      expect(tokens.colorFor(LogType.location), const Color(0xFF15803D));
    });

    test('every type also has a tint for its icon background', () {
      for (final type in LogType.values) {
        expect(tokens.tintFor(type), isNotNull);
      }
    });
  });

  group('glass recipes', () {
    // Values are taken verbatim from the GL table in
    // design/generators/lib.py, the source of truth for exact numbers.
    test('card: feed cards', () {
      expect(tokens.card.fillOpacity, 0.46);
      expect(tokens.card.blurSigma, 24);
      expect(tokens.card.saturationBoost, 1.60);
      expect(tokens.card.borderOpacity, 0.72);
      expect(tokens.card.defaultRadius, 24);
    });

    test('strong: dock and sheets', () {
      expect(tokens.strong.fillOpacity, 0.62);
      expect(tokens.strong.blurSigma, 28);
      expect(tokens.strong.saturationBoost, 1.70);
      expect(tokens.strong.borderOpacity, 0.8);
    });

    test('surface: the writing surface', () {
      expect(tokens.surface.fillOpacity, 0.5);
      expect(tokens.surface.blurSigma, 26);
      expect(tokens.surface.saturationBoost, 1.65);
      expect(tokens.surface.borderOpacity, 0.75);
      expect(tokens.surface.defaultRadius, 28);
    });
  });

  group('ThemeExtension', () {
    test('is retrievable from a ThemeData carrying it', () {
      final theme = ThemeData(extensions: [MomentTokens.standard]);
      expect(theme.extension<MomentTokens>(), MomentTokens.standard);
    });
  });
}
