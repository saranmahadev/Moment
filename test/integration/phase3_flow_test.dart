import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/domain/log.dart';
import 'package:path/path.dart' as p;

import '../video/video_fakes.dart';
import 'shell_harness.dart';

/// docs/ROADMAP.md, Phase 3 exit gate: "All six types can be created,
/// viewed, edited, deleted, restored and backed up." These drive the two
/// new types end to end through the real app shell; the earlier four have
/// their own flows, and backup of all six is in test/backup.
void main() {
  testWidgets('video: create, see it on Home, view, edit, delete, restore', (
    tester,
  ) async {
    final clipDir = Directory.systemTemp.createTempSync('phase3_clip_');
    addTearDown(() => clipDir.deleteSync(recursive: true));
    final clip = File(p.join(clipDir.path, 'clip.mp4'))
      ..writeAsBytesSync([1, 2, 3, 4]);
    final shell = await ShellHarness.pump(
      tester,
      videoPicker: FakeVideoPicker(galleryResult: clip),
    );

    // Create.
    await shell.addLogOfType(tester, 'video');
    await tester.tap(find.text('Choose from Library'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Walk to the station');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pumpAndSettle();

    // See it on Home.
    expect(find.text('Walk to the station'), findsOneWidget);
    final stored = (await shell.repo.getAll()).single as VideoLog;
    expect(File(stored.path).readAsBytesSync(), [1, 2, 3, 4]);

    // View.
    await tester.tap(find.text('Walk to the station'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Fullscreen'), findsOneWidget);
    expect(find.text('0:48'), findsOneWidget);

    // Edit.
    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Walk, revised');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Walk, revised'), findsOneWidget);
    expect(find.text('Walk to the station'), findsNothing);

    // Delete.
    await tester.tap(find.text('Walk, revised'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Walk, revised'), findsNothing);
    expect(File(stored.path).existsSync(), isTrue);

    // Restore, via Library's Trash.
    await shell.openTrash(tester);
    expect(find.text('Walk, revised'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await shell.backToHome(tester);
    expect(find.text('Walk, revised'), findsOneWidget);

    await shell.close(tester);
  });

  testWidgets('location: create, see it on Home, view, edit, delete, restore', (
    tester,
  ) async {
    final shell = await ShellHarness.pump(tester);

    // Create.
    await shell.addLogOfType(tester, 'location');
    expect(find.text('Locked on'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('place-name')),
      'Favourite bench',
    );
    await tester.tap(find.text('Save location'));
    await tester.pumpAndSettle();

    // See it on Home.
    expect(find.text('Favourite bench'), findsOneWidget);
    final stored = (await shell.repo.getAll()).single as LocationLog;
    expect(stored.latitude, 12.971598765432101);
    expect(stored.longitude, 77.59456234567891);

    // View.
    await tester.tap(find.text('Favourite bench'));
    await tester.pumpAndSettle();
    expect(find.text('Coordinates stored on this device'), findsOneWidget);
    expect(find.text('Accuracy ±12 m'), findsOneWidget);

    // Edit.
    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('place-name')),
      'The bench, renamed',
    );
    await tester.tap(find.bySemanticsLabel('Save'));
    await tester.pumpAndSettle();
    expect(find.text('The bench, renamed'), findsOneWidget);

    // Delete.
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('The bench, renamed'), findsNothing);

    // Restore, via Library's Trash.
    await shell.openTrash(tester);
    expect(find.text('The bench, renamed'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await shell.backToHome(tester);
    expect(find.text('The bench, renamed'), findsOneWidget);

    await shell.close(tester);
  });

  testWidgets(
    'a library with video and location backs up from the Privacy screen',
    (tester) async {
      final shell = await ShellHarness.pump(tester);
      await shell.repo.createLocation(latitude: 1, longitude: 2, name: 'Here');
      await shell.repo.createVideo(
        path: p.join(shell.tempDir.path, 'app_support', 'a.mp4'),
        posterPath: p.join(shell.tempDir.path, 'app_support', 'a.jpg'),
        duration: const Duration(seconds: 3),
      );

      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pump();
      await tester.tap(find.text('Privacy and backup'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Back up now'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('passphrase')),
        'correct horse',
      );
      await tester.enterText(
        find.byKey(const ValueKey('passphrase-confirm')),
        'correct horse',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Continue'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      expect(shell.gateway.delivered, hasLength(1));
      expect(shell.gateway.delivered.single.lengthSync(), greaterThan(48));

      await shell.close(tester);
    },
  );
}
