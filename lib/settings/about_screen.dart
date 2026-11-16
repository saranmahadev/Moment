import 'package:flutter/material.dart';

import '../app/app_info.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/round_glass_button.dart';
import '../design/tokens.dart';

const _points = [
  (
    Icons.phone_iphone_outlined,
    'Everything stays on this device',
    'Your logs, photos, recordings, videos and places are kept in '
        'Moment’s own private storage. There is no cloud copy and no '
        'server that could hold one.',
  ),
  (
    Icons.lock_outline,
    'Encrypted where it is stored',
    'The journal database is encrypted with a key made on this device '
        'and kept in its secure key store. The app lock adds a PIN, with '
        'Face ID or fingerprint if you like.',
  ),
  (
    Icons.person_off_outlined,
    'No account, no analytics, no ads',
    'Moment does not know who you are and measures nothing about how '
        'you use it. Search, the calendar and reminders all run on this '
        'device.',
  ),
  (
    Icons.public_outlined,
    'One switch can use the internet',
    '“Look up place names” is off unless you turn it on in Privacy and '
        'backup. While it is on, the coordinates of a new pin are sent to '
        'OpenStreetMap to suggest a name. Nothing else in the app can '
        'open a connection.',
  ),
  (
    Icons.save_alt_outlined,
    'Backups are yours to keep',
    'A backup is one file, encrypted with a passphrase only you know. '
        'You choose where it goes. Lose the passphrase and nobody, '
        'including us, can open it.',
  ),
];

/// "How Moment stays local": what the app does with your data, in plain
/// words, including the one thing that can use the internet.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.onBack});

  final VoidCallback onBack;

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: RoundGlassButton(
                    icon: Icons.chevron_left,
                    label: 'Back',
                    onTap: onBack,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'How Moment stays local',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 32,
                    height: 1.15,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 16),
                for (final (icon, title, body) in _points) ...[
                  GlassSurface(
                    variant: GlassVariant.card,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 22, color: tokens.ink),
                          const SizedBox(width: 12),
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
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
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
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Moment $appVersion',
                    style: TextStyle(fontSize: 13.5, color: tokens.secondary),
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
