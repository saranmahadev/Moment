import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/log_repository.dart';
import '../data/secure_database.dart';
import '../design/theme.dart';
import '../lock/app_lock_controller.dart';
import '../lock/biometric_authenticator.dart';
import '../lock/pin_storage.dart';
import '../shell/app_shell.dart';
import 'lock_gate.dart';
import '../data/database.dart';
import '../data/key_store.dart';

class _Resources {
  _Resources({
    required this.repository,
    required this.lockController,
    required this.hasPin,
  });

  final LogRepository repository;
  final AppLockController lockController;
  final bool hasPin;
}

Future<_Resources> _bootstrap() async {
  final supportDir = await getApplicationSupportDirectory();
  final key = await KeyStore(SecureKeyStorage()).getOrCreateKey();
  final dbPath = p.join(supportDir.path, 'moment.db');
  final db = AppDatabase(openEncryptedDatabase(dbPath, key));

  final lockController = AppLockController(SecurePinStorage());
  final hasPin = await lockController.hasPin();
  if (hasPin) {
    lockController.lock();
  } else {
    lockController.unlock();
  }

  return _Resources(
    repository: LogRepository(db),
    lockController: lockController,
    hasPin: hasPin,
  );
}

/// Moment's root widget: opens the encrypted database and the lock
/// controller, then shows the Lock screen or the app shell.
class MomentApp extends StatefulWidget {
  const MomentApp({super.key});

  @override
  State<MomentApp> createState() => _MomentAppState();
}

class _MomentAppState extends State<MomentApp> with WidgetsBindingObserver {
  late final Future<_Resources> _resources = _bootstrap();
  AppLockController? _lockController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lockController?.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moment',
      debugShowCheckedModeBanner: false,
      theme: momentTheme(),
      home: FutureBuilder<_Resources>(
        future: _resources,
        builder: (context, snapshot) {
          final resources = snapshot.data;
          if (resources == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          _lockController = resources.lockController;

          return LockGate(
            controller: resources.lockController,
            biometrics: DeviceBiometricAuthenticator(),
            hasPin: resources.hasPin,
            child: AppShell(
              repository: resources.repository,
              lockController: resources.lockController,
            ),
          );
        },
      ),
    );
  }
}
