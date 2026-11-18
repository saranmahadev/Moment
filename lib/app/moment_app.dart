import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import '../audio/audio_playback_controller.dart';
import '../audio/audio_recorder_controller.dart';
import '../backup/backup_coordinator.dart';
import '../backup/backup_file_gateway.dart';
import '../backup/backup_service.dart';
import '../backup/last_backup_store.dart';
import '../export/export_coordinator.dart';
import '../export/export_service.dart';
import '../storage/storage_service.dart';
import '../video/video_picker.dart';
import '../video/video_playback_controller.dart';
import '../video/video_probe.dart';
import '../data/log_repository.dart';
import '../data/media_store.dart';
import '../data/secure_database.dart';
import '../location/map/map_source.dart';
import '../location/location_provider.dart';
import '../location/nominatim_place_names.dart';
import '../settings/app_settings.dart';
import '../settings/reminder_scheduler.dart';
import '../lock/app_lock_controller.dart';
import '../lock/biometric_authenticator.dart';
import '../lock/pin_storage.dart';
import '../photo/photo_picker.dart';
import '../shell/app_shell.dart';
import 'lock_gate.dart';
import 'themed_app.dart';
import '../data/database.dart';
import '../data/key_store.dart';

class _Resources {
  _Resources({
    required this.repository,
    required this.lockController,
    required this.mediaStore,
    required this.backups,
    required this.exports,
    required this.storage,
    required this.settings,
    required this.hasPin,
  });

  final LogRepository repository;
  final AppLockController lockController;
  final MediaStore mediaStore;
  final BackupCoordinator backups;
  final ExportCoordinator exports;
  final StorageService storage;
  final AppSettings settings;
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

  final settings = await AppSettings.load(
    FileSettingsStore(File(p.join(supportDir.path, 'settings.json'))),
  );
  final tempDir = await getTemporaryDirectory();
  final repository = LogRepository(db);
  final gateway = DeviceBackupFileGateway();
  return _Resources(
    repository: repository,
    lockController: lockController,
    mediaStore: MediaStore(
      root: supportDir,
      photoQuality: () => settings.mediaQuality,
    ),
    backups: BackupCoordinator(
      service: BackupService(db: db, mediaRoot: supportDir),
      gateway: gateway,
      lastBackupStore: FileLastBackupStore(
        File(p.join(supportDir.path, 'backup-state.json')),
      ),
      scratchDirectory: Directory(p.join(tempDir.path, 'backups')),
    ),
    exports: ExportCoordinator(
      service: ExportService(repository: repository),
      gateway: gateway,
      scratchDirectory: Directory(p.join(tempDir.path, 'exports')),
    ),
    storage: StorageService(repository: repository),
    settings: settings,
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

  /// One lookup for the life of the app, so its one-request-a-second
  /// spacing and its memory of spots already asked about hold. It is only
  /// handed to a screen while "Look up place names" is on.
  final _placeNames = NominatimPlaceNameLookup();
  final _mapSource = AssetMapSource();

  final _reminders = DeviceReminderScheduler();
  AppLockController? _lockController;

  /// Null until the bootstrap has read them; the app follows the system
  /// theme until then.
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resources.then((resources) {
      if (mounted) setState(() => _settings = resources.settings);
      // Schedule the reminder afresh at each launch: it survives a change
      // of time zone, and a schedule the system dropped comes back.
      final settings = resources.settings;
      if (settings.reminderOn) {
        _reminders.enable(settings.reminderTime).ignore();
      }
    });
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
    return ThemedApp(
      settings: _settings,
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
              mediaStore: resources.mediaStore,
              picker: DevicePhotoPicker(),
              createAudioRecorder: DeviceAudioRecorderController.new,
              createAudioPlayback: DeviceAudioPlaybackController.new,
              videoPicker: DeviceVideoPicker(),
              videoProbe: DeviceVideoProbe(),
              createVideoPlayback: DeviceVideoPlaybackController.new,
              locationProvider: DeviceLocationProvider(),
              placeNames: _placeNames,
              mapSource: _mapSource,
              settings: resources.settings,
              reminders: _reminders,
              backups: resources.backups,
              exports: resources.exports,
              storage: resources.storage,
            ),
          );
        },
      ),
    );
  }
}
