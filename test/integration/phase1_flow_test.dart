import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/pin_storage.dart';
import 'package:moment/photo/photo_picker.dart';
import 'package:moment/shell/app_shell.dart';
import 'package:path/path.dart' as p;

class _FakePinStorage implements PinStorage {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async => stored = value;

  @override
  Future<void> clear() async => stored = null;
}

class _FakePhotoPicker implements PhotoPicker {
  @override
  Future<File?> pickFromCamera() async => null;

  @override
  Future<File?> pickFromGallery() async => null;
}

void main() {
  // End-to-end through the real app shell, matching docs/ROADMAP.md's
  // Phase 1 exit gate: "create a text log, see it on Home, edit it,
  // delete it, restore it."
  testWidgets(
    'create a text log, see it on Home, edit it, delete it, restore it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tempDir = Directory.systemTemp.createTempSync('phase1_flow_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db);
      final lockController = AppLockController(_FakePinStorage());
      final mediaStore = MediaStore(
        root: Directory(p.join(tempDir.path, 'app_support')),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: momentTheme(),
          home: AppShell(
            repository: repo,
            lockController: lockController,
            mediaStore: mediaStore,
            picker: _FakePhotoPicker(),
          ),
        ),
      );
      await tester.pump();

      // Create.
      await tester.tap(find.bySemanticsLabel('Add a log'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('add-sheet-type-LogType.text')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'First day of the trip');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // See it on Home.
      expect(find.text('First day of the trip'), findsOneWidget);

      // Edit.
      await tester.tap(find.text('First day of the trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'First day, revised');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('First day, revised'), findsOneWidget);
      expect(find.text('First day of the trip'), findsNothing);

      // Delete.
      await tester.tap(find.text('First day, revised'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('First day, revised'), findsNothing);

      // Restore, via Library's Trash.
      await tester.tap(find.bySemanticsLabel('Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trash'));
      await tester.pumpAndSettle();

      expect(find.text('First day, revised'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.text('First day, revised'), findsNothing);

      // Back on Home.
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Home'));
      await tester.pumpAndSettle();

      expect(find.text('First day, revised'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );
}
