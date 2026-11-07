import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../domain/log.dart';

/// Settings hub matching design/mockups/png/25-Settings.png. Only Privacy
/// and backup and Trash are wired to real navigation in Phase 1; every
/// other row is a static placeholder for a later phase.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.onOpenPrivacy,
    required this.onOpenTrash,
  });

  final LogRepository repository;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTrash;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontWeight: FontWeight.w500,
                fontSize: 38,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 14),
            _SectionLabel('YOUR DATA', tokens: tokens),
            const SizedBox(height: 8),
            GlassSurface(
              variant: GlassVariant.card,
              child: Column(
                children: [
                  _Row(
                    tokens: tokens,
                    title: 'Privacy and backup',
                    subtitle: 'App lock, encrypted backup, export',
                    onTap: onOpenPrivacy,
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tokens.secondary,
                    ),
                  ),
                  _divider(tokens),
                  StreamBuilder<List<Log>>(
                    stream: repository.watchTrash(),
                    builder: (context, snapshot) {
                      final count = (snapshot.data ?? const []).length;
                      return _Row(
                        tokens: tokens,
                        title: 'Trash',
                        subtitle: 'Deleted logs stay for 30 days',
                        onTap: onOpenTrash,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$count ${count == 1 ? 'log' : 'logs'}',
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
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel('LOGGING', tokens: tokens),
            const SizedBox(height: 8),
            GlassSurface(
              variant: GlassVariant.card,
              child: Column(
                children: [
                  _Row(
                    tokens: tokens,
                    title: 'Quick emoji row',
                    subtitle: 'Five emoji on Home',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Edit',
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
                  _divider(tokens),
                  _Row(
                    tokens: tokens,
                    title: 'Evening reminder',
                    subtitle: 'Local notification at 21:00',
                    trailing: _StaticToggle(tokens: tokens, value: true),
                  ),
                  _divider(tokens),
                  _Row(
                    tokens: tokens,
                    title: 'Video and photo quality',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Original',
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
            _SectionLabel('APPEARANCE', tokens: tokens),
            const SizedBox(height: 8),
            GlassSurface(
              variant: GlassVariant.card,
              child: Column(
                children: [
                  _Row(
                    tokens: tokens,
                    title: 'Theme',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'System',
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
                  _divider(tokens),
                  _Row(
                    tokens: tokens,
                    title: 'Reduce transparency',
                    subtitle: 'Swaps glass for solid surfaces',
                    trailing: _StaticToggle(tokens: tokens, value: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel('ABOUT', tokens: tokens),
            const SizedBox(height: 8),
            GlassSurface(
              variant: GlassVariant.card,
              child: Column(
                children: [
                  _Row(
                    tokens: tokens,
                    title: 'How Moment stays local',
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tokens.secondary,
                    ),
                  ),
                  _divider(tokens),
                  _Row(
                    tokens: tokens,
                    title: 'Version',
                    trailing: Text(
                      '0.1.0',
                      style: TextStyle(fontSize: 15, color: tokens.secondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(MomentTokens tokens) =>
      Divider(height: 1, color: tokens.secondary.withValues(alpha: 0.15));
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

class _Row extends StatelessWidget {
  const _Row({
    required this.tokens,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final MomentTokens tokens;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13.5, color: tokens.secondary),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A non-interactive switch-shaped indicator, for toggles whose feature
/// doesn't exist yet: looks like the real thing, but can't be tapped.
class _StaticToggle extends StatelessWidget {
  const _StaticToggle({required this.tokens, required this.value});

  final MomentTokens tokens;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Switch(
        value: value,
        onChanged: (_) {},
        activeThumbColor: Colors.white,
        activeTrackColor: tokens.ink,
        inactiveTrackColor: tokens.switchOff,
      ),
    );
  }
}
