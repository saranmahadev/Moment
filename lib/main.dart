import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/moment_app.dart';
import 'diagnostics/diagnostics_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final dir = await getApplicationSupportDirectory();
    DiagnosticsLog.shared = DiagnosticsLog(
      FileDiagnosticsStore(File(p.join(dir.path, 'diagnostics.jsonl'))),
    );
  } on Object {
    // Without a folder the log stays in memory; the app still starts.
  }
  final log = DiagnosticsLog.shared;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    log.error(details.exception, details.stack).ignore();
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error(error, stack).ignore();
    // Reported as handled: one bad callback does not end the app.
    return !kDebugMode;
  };
  runApp(const MomentApp());
}
