import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../lock/app_lock_controller.dart';
import '../lock/create_pin_screen.dart';

/// Privacy and backup: currently only the Security section (App lock),
/// matching design/mockups/png/26-Privacy-and-backup.png. Backup, Export,
/// Place names and Storage are Phase 2+.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key, required this.controller, this.onBack});

  final AppLockController controller;
  final VoidCallback? onBack;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _appLockOn = false;

  @override
  void initState() {
    super.initState();
    _loadAppLockState();
  }

  Future<void> _loadAppLockState() async {
    final hasPin = await widget.controller.hasPin();
    if (!mounted) return;
    setState(() => _appLockOn = hasPin);
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
      body: SafeArea(
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
          ],
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
