import 'dart:io';

import '../backup/backup_file_gateway.dart';
import '../domain/log_type.dart';
import 'export_service.dart';

/// Writes an export under the scratch directory and offers it through the
/// gateway, so the Privacy screen has one call to make.
class ExportCoordinator {
  ExportCoordinator({
    required ExportService service,
    required BackupFileGateway gateway,
    required Directory scratchDirectory,
  }) : _service = service,
       _gateway = gateway,
       _scratch = scratchDirectory;

  final ExportService _service;
  final BackupFileGateway _gateway;
  final Directory _scratch;

  Future<void> export(Set<LogType> types) async {
    final file = await _service.exportTo(_scratch, types: types);
    await _gateway.deliver(file);
  }
}
