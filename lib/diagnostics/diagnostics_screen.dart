import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/round_glass_button.dart';
import '../design/tokens.dart';
import 'diagnostics_log.dart';

Future<void> _shareText(String text) async {
  await SharePlus.instance.share(
    ShareParams(text: text, subject: 'Moment diagnostics'),
  );
}

/// Settings → Diagnostics: what the [DiagnosticsLog] holds, to read, copy
/// or share. Also shown, with an [intro], when the app could not start.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    required this.log,
    this.onBack,
    this.intro,
    this.share = _shareText,
  });

  final DiagnosticsLog log;

  /// Null hides the Back button (nothing to go back to).
  final VoidCallback? onBack;

  /// Shown above everything else, when the screen needs explaining.
  final String? intro;
  final Future<void> Function(String text) share;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<DiagnosticEntry>? _entries;
  String? _note;

  @override
  void initState() {
    super.initState();
    _entries = widget.log.loaded?.reversed.toList();
    _reload();
  }

  Future<void> _reload() async {
    final entries = await widget.log.entries();
    if (mounted) setState(() => _entries = entries.reversed.toList());
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: await widget.log.report()));
    if (mounted) setState(() => _note = 'Copied');
  }

  Future<void> _share() async => widget.share(await widget.log.report());

  Future<void> _clear() async {
    final sure = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ConfirmClear(),
    );
    if (sure != true) return;
    await widget.log.clear();
    if (mounted) setState(() => _note = null);
    await _reload();
  }

  static String _when(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final l = t.toLocal();
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final entries = _entries;
    final body = TextStyle(fontSize: 14, height: 1.4, color: tokens.secondary);
    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (widget.onBack case final onBack?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RoundGlassButton(
                      icon: Icons.chevron_left,
                      label: 'Back',
                      onTap: onBack,
                    ),
                  ),
                const SizedBox(height: 14),
                if (widget.intro case final intro?) ...[
                  Text(
                    intro,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.danger,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Diagnostics',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 32,
                    height: 1.15,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Errors and a few app events, kept only on this phone. '
                  'Each error records where in Moment’s code it happened, '
                  'never what you wrote. Nothing is sent anywhere unless '
                  'you share it.',
                  style: body,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Pill(label: 'Copy', icon: Icons.copy, onTap: _copy),
                    _Pill(label: 'Share', icon: Icons.ios_share, onTap: _share),
                    _Pill(
                      label: 'Clear',
                      icon: Icons.delete_outline,
                      onTap: _clear,
                    ),
                  ],
                ),
                if (_note case final note?) ...[
                  const SizedBox(height: 8),
                  Text(note, style: body),
                ],
                const SizedBox(height: 16),
                if (entries == null)
                  const SizedBox.shrink()
                else if (entries.isEmpty)
                  Text('Nothing has been recorded.', style: body)
                else
                  GlassSurface(
                    variant: GlassVariant.card,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (final e in entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    e.kind == DiagnosticKind.error
                                        ? Icons.error_outline
                                        : Icons.circle_outlined,
                                    size: 16,
                                    color: e.kind == DiagnosticKind.error
                                        ? tokens.danger
                                        : tokens.secondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.name,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: tokens.ink,
                                          ),
                                        ),
                                        Text(
                                          [
                                            _when(e.at),
                                            if (e.detail.isNotEmpty) e.detail,
                                          ].join(' · '),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: tokens.secondary,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: GlassSurface(
            variant: GlassVariant.card,
            borderRadius: 22,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: tokens.ink),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmClear extends StatelessWidget {
  const _ConfirmClear();

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    Widget button(String label, bool primary, bool result) => Expanded(
      child: Semantics(
        button: true,
        container: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(result),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? tokens.ink : null,
              borderRadius: BorderRadius.circular(24),
              border: primary ? null : Border.all(color: tokens.switchOff),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: primary ? tokens.onInk : tokens.ink,
              ),
            ),
          ),
        ),
      ),
    );
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
                  'Clear diagnostics?',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 26,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Everything recorded so far is deleted. Your journal is '
                  'not touched.',
                  style: TextStyle(fontSize: 14.5, color: tokens.secondary),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    button('Cancel', false, false),
                    const SizedBox(width: 12),
                    button('Clear diagnostics', true, true),
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
