import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backup/backup_coordinator.dart';
import '../backup/backup_service.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../lock/app_lock_controller.dart';
import '../lock/create_pin_screen.dart';
import 'passphrase_sheet.dart';

final _lastBackupFormat = DateFormat('d MMM yyyy, HH:mm');

/// Privacy and backup: the Security section (App lock) and the Backup
/// section (encrypted backup and restore), matching
/// design/mockups/png/26-Privacy-and-backup.png. Export, Place names and
/// Storage follow in their own chunks.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({
    super.key,
    required this.controller,
    required this.backups,
    DateTime Function()? now,
    this.onBack,
  }) : now = now ?? DateTime.now;

  final AppLockController controller;
  final BackupCoordinator backups;
  final DateTime Function() now;
  final VoidCallback? onBack;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _appLockOn = false;
  DateTime? _lastBackup;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadAppLockState();
    _loadLastBackup();
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
                                'No account, no servers, no internet permission.',
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
                              activeThumbColor: Colors.white,
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
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Back up now',
                                        style: TextStyle(
                                          color: Colors.white,
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
              ],
            ),
          ),
        ],
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
