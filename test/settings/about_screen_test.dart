import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/app_info.dart';
import 'package:moment/design/round_glass_button.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/settings/about_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onBack}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: AboutScreen(onBack: onBack ?? () {}),
      ),
    );
  }

  testWidgets('says where the data lives and what protects it', (tester) async {
    await pump(tester);

    expect(find.text('How Moment stays local'), findsOneWidget);
    expect(find.text('Everything stays on this device'), findsOneWidget);
    expect(find.text('Encrypted where it is stored'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No account, no analytics, no ads'),
      200,
    );
    expect(find.text('No account, no analytics, no ads'), findsOneWidget);
  });

  testWidgets('is honest about the one thing that can use the internet', (
    tester,
  ) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Moment $appVersion'), 200);

    expect(find.text('One switch can use the internet'), findsOneWidget);
    expect(
      find.textContaining('“Look up place names” is off unless you turn it on'),
      findsOneWidget,
    );
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(find.text('Backups are yours to keep'), findsOneWidget);
    expect(find.text('Moment $appVersion'), findsOneWidget);
  });

  testWidgets('says where the maps come from', (tester) async {
    await pump(tester);

    expect(find.textContaining('Natural Earth'), findsOneWidget);
  });

  testWidgets('never claims the app has no internet permission', (
    tester,
  ) async {
    await pump(tester);

    expect(find.textContaining('no internet permission'), findsNothing);
  });

  testWidgets('Back calls onBack', (tester) async {
    var back = false;
    await pump(tester, onBack: () => back = true);

    // The label belongs to the whole first row of the list, so aim at the
    // button itself.
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    await tester.tap(find.byType(RoundGlassButton));

    expect(back, isTrue);
  });

  testWidgets('credits the work Moment is built on, and where its source is', (
    tester,
  ) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Open-source licences'), 200);
    expect(find.textContaining('GPL-3.0'), findsWidgets);
    expect(
      find.textContaining('github.com/saranmahadev/Moment'),
      findsOneWidget,
    );

    await tester.tap(find.text('Open-source licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
