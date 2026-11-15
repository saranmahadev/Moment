import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

/// Moves backup files across the app boundary: handing a finished backup
/// to the user, and letting them pick one to restore. Wraps the share
/// sheet and the system file picker so tests can supply a fake.
abstract interface class BackupFileGateway {
  /// Offers [backup] to the user to save or send wherever they like.
  Future<void> deliver(File backup);

  /// Lets the user choose a `.moment` file; null when they cancel.
  Future<File?> pick();
}

class DeviceBackupFileGateway implements BackupFileGateway {
  @override
  Future<void> deliver(File backup) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(backup.path)], subject: 'Moment backup'),
    );
  }

  @override
  Future<File?> pick() async {
    final picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Moment backup',
          extensions: ['moment'],
          mimeTypes: ['application/octet-stream'],
          uniformTypeIdentifiers: ['public.data'],
        ),
      ],
    );
    return picked == null ? null : File(picked.path);
  }
}
