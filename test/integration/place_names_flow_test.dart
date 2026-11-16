import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/design/round_glass_button.dart';

import '../location/location_fakes.dart';
import 'shell_harness.dart';

/// "Look up place names" is the only thing that can use the internet, and
/// only when it is on: with it off, the app never even reaches the lookup.
void main() {
  Future<void> pinAPlace(WidgetTester tester, ShellHarness shell) async {
    await shell.addLogOfType(tester, 'location');
    await tester.pump();
    await tester.tap(find.text('Save location'));
    await tester.pumpAndSettle();
  }

  testWidgets('off by default: nothing is looked up', (tester) async {
    final names = FakePlaceNameLookup();
    final shell = await ShellHarness.pump(tester, placeNames: names);

    await pinAPlace(tester, shell);

    expect(names.asked, isEmpty);
    expect(((await shell.repo.getAll()).single as LocationLog).name, isNull);

    await shell.close(tester);
  });

  testWidgets('turned on in Privacy: the next pin gets a suggested name', (
    tester,
  ) async {
    final names = FakePlaceNameLookup(name: 'Cubbon Park');
    final settings = AppSettings.inMemory();
    final shell = await ShellHarness.pump(
      tester,
      placeNames: names,
      settings: settings,
    );

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy and backup'));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('place-names-switch'));
    await tester.scrollUntilVisible(
      toggle,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(settings.lookUpPlaceNames, isTrue);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(RoundGlassButton, Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();

    await pinAPlace(tester, shell);

    expect(names.asked, hasLength(1));
    expect(
      ((await shell.repo.getAll()).single as LocationLog).name,
      'Cubbon Park',
    );

    await shell.close(tester);
  });

  testWidgets('turned off again: back to nothing looked up', (tester) async {
    final names = FakePlaceNameLookup();
    final settings = AppSettings.inMemory({'lookUpPlaceNames': true});
    final shell = await ShellHarness.pump(
      tester,
      placeNames: names,
      settings: settings,
    );

    await settings.setLookUpPlaceNames(false);
    await pinAPlace(tester, shell);

    expect(names.asked, isEmpty);

    await shell.close(tester);
  });
}
