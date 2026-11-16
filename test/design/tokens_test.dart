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

  group('dark palette', () {
    const dark = MomentTokens.dark;
    const light = MomentTokens.standard;

    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    test('is a dark ground with light ink', () {
      expect(dark.brightness, Brightness.dark);
      expect(light.brightness, Brightness.light);
      expect(dark.ground.computeLuminance(), lessThan(0.02));
      expect(contrast(dark.ink, dark.ground), greaterThan(12));
      expect(contrast(dark.secondary, dark.ground), greaterThan(7));
    });

    test('every type colour reads on the dark ground and on solid cards', () {
      for (final type in LogType.values) {
        expect(
          contrast(dark.colorFor(type), dark.ground),
          greaterThan(4.5),
          reason: type.name,
        );
        expect(
          contrast(dark.colorFor(type), dark.solidSurface),
          greaterThan(4.5),
          reason: type.name,
        );
        expect(dark.tintFor(type).a, lessThan(1), reason: type.name);
      }
    });

    test('what sits on an ink-filled button reads on it, in both', () {
      expect(light.onInk, const Color(0xFFFFFFFF));
      expect(contrast(light.onInk, light.ink), greaterThan(12));
      expect(contrast(dark.onInk, dark.ink), greaterThan(12));
    });

    test('glass is fainter on dark, so it does not turn grey', () {
      expect(dark.card.fillOpacity, lessThan(light.card.fillOpacity));
      expect(dark.strong.fillOpacity, lessThan(light.strong.fillOpacity));
      expect(dark.surface.fillOpacity, lessThan(light.surface.fillOpacity));
    });

    test('the danger colour reads on the dark ground', () {
      expect(contrast(dark.danger, dark.ground), greaterThan(4.5));
    });
  });

  group('reduce transparency', () {
    test('is off in both palettes and can be switched on', () {
      expect(MomentTokens.standard.reduceTransparency, isFalse);
      expect(MomentTokens.dark.reduceTransparency, isFalse);

      final solid = MomentTokens.dark.copyWith(reduceTransparency: true);
      expect(solid.reduceTransparency, isTrue);
      expect(solid.ground, MomentTokens.dark.ground);
    });

    test('solid surfaces are opaque', () {
      expect(MomentTokens.standard.solidSurface.a, 1);
      expect(MomentTokens.dark.solidSurface.a, 1);
    });
  });
}
