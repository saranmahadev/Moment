import 'dart:io';

import 'package:flutter/material.dart';

import '../backup/backup_service.dart';
import '../data/journal_opener.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../privacy/passphrase_sheet.dart';

/// Shown at launch instead of the app when the journal on this phone
/// cannot be opened (see [JournalOpener]). Offers a restore from a backup,
/// or an empty journal after a second confirmation. Neither deletes the
/// old file: [JournalOpener.startFresh] keeps it aside.
class JournalProblemScreen extends StatefulWidget {
  const JournalProblemScreen({
    super.key,
    required this.problem,
    required this.pickBackup,
    required this.restore,
    required this.startFresh,
  });

  final JournalProblem problem;
  final Future<File?> Function() pickBackup;

  /// Restores [file] into a new journal. Throws what [BackupService]
  /// throws; the screen says what went wrong and stays.
  final Future<void> Function(File file, String passphrase) restore;
  final Future<void> Function() startFresh;

  @override
  State<JournalProblemScreen> createState() => _JournalProblemScreenState();
}

class _JournalProblemScreenState extends State<JournalProblemScreen> {
  bool _busy = false;
  String? _error;

  String get _explanation => switch (widget.problem) {
    JournalProblem.keyMissing =>
      'Your journal is still on this phone, but the key that unlocks it is '
          'missing. This can happen when the phone’s secure storage is '
          'cleared, for example after restoring the phone from a backup.',
    JournalProblem.unreadable =>
      'Your journal is still on this phone, but the key Moment has '
          'doesn’t open it. The file may have been damaged.',
  };

  Future<void> _restore() async {
    if (_busy) return;
    final file = await widget.pickBackup();
    if (file == null || !mounted) return;
    final passphrase = await showPassphraseSheet(
      context,
      title: 'Enter the backup passphrase',
      confirm: false,
    );
    if (passphrase == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.restore(file, passphrase);
    } on Object catch (error) {
      if (mounted) setState(() => _error = describeBackupError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startFresh() async {
    if (_busy) return;
    final sure = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ConfirmFresh(),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.startFresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(Icons.lock_outline, size: 32, color: tokens.ink),
                ),
                const SizedBox(height: 16),
                Text(
                  'This journal can’t be opened',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 32,
                    height: 1.15,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _explanation,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: tokens.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'If you have a backup, restore it to get everything back. '
                  'Either way, the file that can’t be opened stays on this '
                  'phone and is not deleted.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: tokens.secondary,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 14, color: tokens.danger),
                  ),
                ],
                const SizedBox(height: 28),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _Button(
                    label: 'Restore from a backup',
                    primary: true,
                    onTap: _restore,
                  ),
                  const SizedBox(height: 12),
                  _Button(
                    label: 'Start an empty journal',
                    primary: false,
                    onTap: _startFresh,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmFresh extends StatelessWidget {
  const _ConfirmFresh();

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          variant: GlassVariant.strong,
          borderRadius: 28,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start an empty journal?',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 26,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Moment will start again with no logs. The old file stays '
                  'on this phone, unopened, and you can still restore a '
                  'backup later from Privacy and backup.',
                  style: TextStyle(fontSize: 14.5, color: tokens.secondary),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _Button(
                        label: 'Cancel',
                        primary: false,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Button(
                        label: 'Start empty',
                        primary: true,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary ? tokens.onInk : tokens.ink,
      ),
    );
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: primary
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.ink,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: text,
                    ),
                  ),
                )
              : GlassSurface(
                  variant: GlassVariant.card,
                  borderRadius: 26,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: text,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
