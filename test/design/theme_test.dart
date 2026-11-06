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
}
