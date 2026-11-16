import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backup/backup_coordinator.dart';
import '../backup/backup_service.dart';
import '../design/glass_surface.dart';
import '../design/type_icons.dart';
import '../domain/log_type.dart';
import '../export/export_coordinator.dart';
import '../settings/app_settings.dart';
import '../storage/storage_service.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../lock/app_lock_controller.dart';
import '../lock/create_pin_screen.dart';
import 'passphrase_sheet.dart';

final _lastBackupFormat = DateFormat('d MMM yyyy, HH:mm');

/// Privacy and backup: Security (App lock), Backup (encrypted backup and
/// restore), Export (readable copy of chosen types) and Storage by type,
/// matching design/mockups/png/26-Privacy-and-backup.png. Place names is
/// the one switch that lets anything leave the device; it says so.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({
    super.key,
    required this.controller,
    required this.backups,
    required this.exports,
    required this.storage,
    required this.settings,
    DateTime Function()? now,
    this.onBack,
  }) : now = now ?? DateTime.now;

  final AppLockController controller;
  final BackupCoordinator backups;
  final ExportCoordinator exports;
  final StorageService storage;
  final AppSettings settings;
  final DateTime Function() now;
  final VoidCallback? onBack;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _appLockOn = false;
  DateTime? _lastBackup;
  bool _busy = false;
  final Set<LogType> _exportTypes = {...builtLogTypes};
  Map<LogType, int>? _usage;

  @override
  void initState() {
    super.initState();
    _loadAppLockState();
    _loadLastBackup();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final usage = await widget.storage.measure();
    if (!mounted) return;
    setState(() => _usage = usage);
  }

  Future<void> _export() async {
    if (_busy || _exportTypes.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.exports.export({..._exportTypes});
      _notify('Export ready to save');
    } on Object {
      _notify('The export could not be made.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadAppLockState() async {
    final hasPin = await widget.controller.hasPin();
    if (!mounted) return;
    setState(() => _appLockOn = hasPin);
  }

  Future<void> _loadLastBackup() async {
    final at = await widget.backups.lastBackup();
    if (!mounted) return;
    setState(() => _lastBackup = at);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _backUpNow() async {
    if (_busy) return;
    final passphrase = await showPassphraseSheet(
      context,
      title: 'Choose a passphrase',
      confirm: true,
    );
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.backups.backUp(passphrase: passphrase);
      await _loadLastBackup();
      _notify('Backup ready to save');
    } on Object catch (error) {
      _notify(describeBackupError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final file = await widget.backups.pickBackup();
    if (file == null || !mounted) return;
    final passphrase = await showPassphraseSheet(
      context,
      title: 'Enter the backup passphrase',
      confirm: false,
    );
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final summary = await widget.backups.restore(
        file,
        passphrase: passphrase,
      );
      final n = summary.logsRestored;
      _notify(
        n == 0 && summary.logsSkipped > 0
            ? 'Everything in that backup is already here'
            : 'Restored $n ${n == 1 ? 'log' : 'logs'}',
      );
    } on Object catch (error) {
      _notify(describeBackupError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onAppLockChanged(bool value) async {
    if (value) {
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => CreatePinScreen(
            controller: widget.controller,
            onDone: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          ),
        ),
      );
      if (!mounted) return;
      if (done ?? false) {
        setState(() => _appLockOn = true);
      }
      return;
    }

    await widget.controller.clearPin();
    if (!mounted) return;
    setState(() => _appLockOn = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Semantics(
                  button: true,
                  label: 'Back',
                  onTap: widget.onBack,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: widget.onBack,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: GlassSurface(
                        variant: GlassVariant.card,
                        borderRadius: 22,
                        child: Icon(Icons.chevron_left, color: tokens.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Privacy and backup',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 34,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 14),
                GlassSurface(
                  variant: GlassVariant.card,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.ground,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: tokens.ink,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local only',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink,
                                ),
                              ),
                              Text(
                                'No account, no servers. Nothing leaves this device '
                                'unless you turn on place names.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: tokens.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel('SECURITY', tokens: tokens),
                const SizedBox(height: 8),
                GlassSurface(
                  variant: GlassVariant.card,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'App lock',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.ink,
                                    ),
                                  ),
                                  Text(
                                    'PIN with Face ID',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: tokens.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _appLockOn,
                              activeThumbColor: tokens.onInk,
                              activeTrackColor: tokens.ink,
                              inactiveTrackColor: tokens.switchOff,
                              onChanged: _onAppLockChanged,
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: tokens.secondary.withValues(alpha: 0.15),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Lock after',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                            Text(
                              'Immediately',
                              style: TextStyle(
                                fontSize: 15,
                                color: tokens.secondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: tokens.secondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel('BACKUP', tokens: tokens),
                const SizedBox(height: 8),
                GlassSurface(
                  variant: GlassVariant.card,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Encrypted backup',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.ink,
                                    ),
                                  ),
                                  Text(
                                    _lastBackup == null
                                        ? 'Last backup: never'
                                        : 'Last backup: '
                                              '${_lastBackupFormat.format(_lastBackup!.toLocal())}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: tokens.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _busy ? null : _backUpNow,
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.ink,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                alignment: Alignment.center,
                                child: _busy
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: tokens.onInk,
                                        ),
                                      )
                                    : Text(
                                        'Back up now',
                                        style: TextStyle(
                                          color: tokens.onInk,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: tokens.secondary.withValues(alpha: 0.15),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _busy ? null : _restore,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Restore from backup',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.ink,
                                      ),
                                    ),
                                    Text(
                                      'Choose a backup file',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: tokens.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: tokens.secondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel('EXPORT', tokens: tokens),
                const SizedBox(height: 8),
                GlassSurface(
                  variant: GlassVariant.card,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                        Text(
                          'Markdown, JSON and original files. Choose types.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: tokens.secondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final type in builtLogTypes)
                              _ExportChip(
                                type: type,
                                selected: _exportTypes.contains(type),
                                tokens: tokens,
                                onTap: () => setState(() {
                                  if (!_exportTypes.remove(type)) {
                                    _exportTypes.add(type);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: _busy || _exportTypes.isEmpty ? null : _export,
                          child: Opacity(
                            opacity: _exportTypes.isEmpty ? 0.5 : 1,
                            child: SizedBox(
                              height: 48,
                              width: double.infinity,
                              child: GlassSurface(
                                variant: GlassVariant.surface,
                                borderRadius: 24,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.file_download_outlined,
                                      size: 18,
                                      color: tokens.ink,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Export selected types',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel('PLACE NAMES', tokens: tokens),
                const SizedBox(height: 8),
                GlassSurface(
                  variant: GlassVariant.card,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Look up place names',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.ink,
                                    ),
                                  ),
                                  Text(
                                    'Uses the internet. Keep off to stay '
                                    'fully offline.',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: tokens.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListenableBuilder(
                              listenable: widget.settings,
                              builder: (context, _) => Semantics(
                                label: 'Look up place names',
                                child: Switch(
                                  key: const ValueKey('place-names-switch'),
                                  value: widget.settings.lookUpPlaceNames,
                                  activeThumbColor: tokens.onInk,
                                  activeTrackColor: tokens.ink,
                                  inactiveTrackColor: tokens.switchOff,
                                  onChanged:
                                      widget.settings.setLookUpPlaceNames,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'When on, the coordinates of a new pin are sent to '
                          'OpenStreetMap to suggest a name. Nothing else ever '
                          'leaves this device. Names © OpenStreetMap '
                          'contributors.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: tokens.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel('STORAGE', tokens: tokens),
                const SizedBox(height: 8),
                GlassSurface(
                  variant: GlassVariant.card,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage by type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._storageRows(tokens),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _storageRows(MomentTokens tokens) {
    final usage = _usage;
    if (usage == null) return const [];
    final types = [...builtLogTypes]
      ..sort((a, b) => usage[b]!.compareTo(usage[a]!));
    final largest = usage.values.fold<int>(0, (a, b) => a > b ? a : b);
    return [
      for (final type in types)
        Padding(
          key: ValueKey('storage-row-${type.name}'),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  momentLabelFor(type),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, color: tokens.secondary),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        color: tokens.ink.withValues(alpha: 0.08),
                      ),
                      FractionallySizedBox(
                        widthFactor: largest == 0
                            ? 0
                            : (usage[type]! / largest).clamp(0.02, 1.0),
                        child: Container(
                          height: 8,
                          color: tokens.colorFor(type),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  formatBytes(usage[type]!),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _ExportChip extends StatelessWidget {
  const _ExportChip({
    required this.type,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final LogType type;
  final bool selected;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = tokens.colorFor(type);
    return Semantics(
      key: ValueKey('export-chip-${type.name}'),
      button: true,
      selected: selected,
      label: momentLabelFor(type),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? tokens.tintFor(type) : Colors.transparent,
            border: Border.all(color: selected ? color : tokens.switchOff),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check : momentIconFor(type),
                size: 16,
                color: selected ? color : tokens.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                momentLabelFor(type),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: selected ? color : tokens.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.tokens});

  final String text;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: tokens.secondary,
        ),
      ),
    );
  }
}
