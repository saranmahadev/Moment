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
        'server that could hold one. Place maps are drawn from Natural '
        'Earth data inside the app, so nothing is fetched to show them.',
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

  /// Flutter's licence page: every package Moment is built with, plus the
  /// typefaces and map data (see registerAppLicences).
  static void _showLicences(BuildContext context) => showLicensePage(
    context: context,
    applicationName: 'Moment',
    applicationVersion: appVersion,
    applicationLegalese:
        'Free software under the GNU General Public License v3.0.',
  );

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
                GlassSurface(
                  variant: GlassVariant.card,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.code, size: 22, color: tokens.ink),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Free and open source',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Moment is free software under the GNU General '
                          'Public License (GPL-3.0): you can read, change '
                          'and share it. The source, the changelog and the '
                          'way to report a problem are at '
                          'github.com/saranmahadev/Moment.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: tokens.secondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          container: true,
                          button: true,
                          label: 'Open-source licences',
                          onTap: () => _showLicences(context),
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showLicences(context),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Open-source licences',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.ink,
                                      ),
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
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
