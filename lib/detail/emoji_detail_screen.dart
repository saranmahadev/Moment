import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import '../emoji/create_emoji_screen.dart';

String _intensityWordFor(int strength) {
  if (strength <= 2) return 'Light';
  if (strength == 3) return 'Moderate';
  return 'Strong';
}

/// A single emoji log, full screen. Matches
/// design/mockups/png/18-Detail-Emoji.png.
class EmojiDetailScreen extends StatelessWidget {
  const EmojiDetailScreen({
    super.key,
    required this.log,
    required this.repository,
    DateTime Function()? now,
    this.onBack,
  }) : now = now ?? DateTime.now;

  final EmojiLog log;
  final LogRepository repository;
  final DateTime Function() now;
  final VoidCallback? onBack;

  Future<void> _delete() async {
    await repository.softDelete(log.id);
    onBack?.call();
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateEmojiScreen(
          repository: repository,
          now: now,
          editing: log,
          onSaved: (_) {
            Navigator.of(context).pop();
            onBack?.call();
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.emoji);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.chevron_left,
                        label: 'Back',
                        tokens: tokens,
                        onTap: onBack,
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        tokens: tokens,
                        onTap: () => _edit(context),
                      ),
                      const SizedBox(width: 10),
                      _RoundIconButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        tokens: tokens,
                        onTap: _delete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: GlassSurface(
                      variant: GlassVariant.surface,
                      borderRadius: 75,
                      child: Center(
                        child: Text(
                          log.emoji,
                          style: const TextStyle(fontSize: 88),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (log.label != null)
                    Text(
                      log.label!,
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 34,
                        color: tokens.ink,
                      ),
                    ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i <= log.strength
                                    ? color
                                    : tokens.switchOff,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          '${_intensityWordFor(log.strength)} · ${log.strength} of 5',
                          style: TextStyle(
                            fontSize: 14,
                            color: tokens.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PillButton(
                          icon: Icons.emoji_emotions_outlined,
                          label: 'Change emoji',
                          tokens: tokens,
                          onTap: () => _edit(context),
                        ),
                        const SizedBox(width: 12),
                        _PillButton(
                          label: 'Change strength',
                          tokens: tokens,
                          onTap: () => _edit(context),
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
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.tokens,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final MomentTokens tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: GlassSurface(
            variant: GlassVariant.card,
            borderRadius: 22,
            child: Icon(icon, size: 20, color: tokens.ink),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    this.icon,
    required this.label,
    required this.tokens,
    required this.onTap,
  });

  final IconData? icon;
  final String label;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: GlassSurface(
          variant: GlassVariant.card,
          borderRadius: 22,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: tokens.ink),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(fontSize: 14, color: tokens.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
