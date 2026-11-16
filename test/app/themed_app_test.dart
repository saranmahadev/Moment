import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/themed_app.dart';
import 'package:moment/design/tokens.dart';
import 'package:moment/settings/app_settings.dart';

void main() {
  late BuildContext inside;

  Future<void> pump(
    WidgetTester tester,
    AppSettings? settings, {
    Brightness system = Brightness.light,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = system;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      ThemedApp(
        settings: settings,
        home: Builder(
          builder: (context) {
            inside = context;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  MomentTokens tokens() => Theme.of(inside).extension<MomentTokens>()!;

  testWidgets('follows the system until told otherwise', (tester) async {
    await pump(tester, AppSettings.inMemory(), system: Brightness.dark);
    expect(tokens().brightness, Brightness.dark);

    await pump(tester, AppSettings.inMemory(), system: Brightness.light);
    await tester.pumpAndSettle();
    expect(tokens().brightness, Brightness.light);
  });

  testWidgets('before the settings have loaded, follows the system', (
    tester,
  ) async {
    await pump(tester, null, system: Brightness.dark);

    expect(tokens().brightness, Brightness.dark);
    expect(tokens().reduceTransparency, isFalse);
  });

  testWidgets('a theme choice takes effect at once', (tester) async {
    final settings = AppSettings.inMemory();
    await pump(tester, settings, system: Brightness.light);
    expect(tokens(), MomentTokens.standard);

    await settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(tokens(), MomentTokens.dark);

    await settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(tokens(), MomentTokens.standard);
  });

  testWidgets('light stays light on a dark system', (tester) async {
    await pump(
      tester,
      AppSettings.inMemory({'themeMode': 'light'}),
      system: Brightness.dark,
    );

    expect(tokens().brightness, Brightness.light);
  });

  testWidgets('Reduce Transparency takes effect at once, in either theme', (
    tester,
  ) async {
    final settings = AppSettings.inMemory({'themeMode': 'dark'});
    await pump(tester, settings);
    expect(tokens().reduceTransparency, isFalse);

    await settings.setReduceTransparency(true);
    await tester.pumpAndSettle();
    expect(tokens().reduceTransparency, isTrue);
    expect(tokens().brightness, Brightness.dark);

    await settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(tokens().reduceTransparency, isTrue);
    expect(tokens().brightness, Brightness.light);
  });
}
