import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/round_glass_button.dart';
import '../design/tokens.dart';
import '../settings/app_settings.dart';
import 'widget_bridge.dart';

/// What the Widgets row in Settings says the widget shows.
String widgetShowsLabel(AppSettings settings) =>
    settings.widgetShowsStreak ? 'Streak and Quick add' : 'Quick add only';

/// Settings, Widgets: what the home screen widget may show, and a way to
/// add it. A change is saved at once and reaches the widget straight away.
class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({
    super.key,
    required this.settings,
    required this.bridge,
    required this.onBack,
  });

  final AppSettings settings;
  final WidgetBridge bridge;
  final VoidCallback onBack;

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  bool _pinRefused = false;

  Future<void> _add() async {
    final ok = await widget.bridge.requestPin();
    if (mounted) setState(() => _pinRefused = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final settings = widget.settings;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      RoundGlassButton(
                        icon: Icons.chevron_left,
                        label: 'Back',
                        onTap: widget.onBack,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          container: true,
                          header: true,
                          child: Text(
                            'Widgets',
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontWeight: FontWeight.w500,
                              fontSize: 34,
                              color: tokens.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _label('WHAT THE WIDGET SHOWS', tokens),
                  GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 26,
                    child: Column(
                      children: [
                        _Choice(
                          key: const ValueKey('widget-option-streak'),
                          tokens: tokens,
                          title: 'Streak and Quick add',
                          detail:
                              'Your streak and this week, with a button for '
                              'each log type. No words, photos or places '
                              'from your journal.',
                          badge: 'Default',
                          selected: settings.widgetShowsStreak,
                          onTap: () => settings.setWidgetShowsStreak(true),
                        ),
                        Divider(
                          height: 1,
                          color: tokens.secondary.withValues(alpha: 0.15),
                        ),
                        _Choice(
                          key: const ValueKey('widget-option-quick'),
                          tokens: tokens,
                          title: 'Quick add only',
                          detail:
                              'Buttons for each log type. Nothing from your '
                              'journal.',
                          selected: !settings.widgetShowsStreak,
                          onTap: () => settings.setWidgetShowsStreak(false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 26,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline, size: 20, color: tokens.ink),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The widget stays visible while Moment is '
                              'locked. It shows only what you choose above, '
                              'and tapping it asks for your PIN or Face ID '
                              'first.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: tokens.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _label('ADD', tokens),
                  Semantics(
                    container: true,
                    button: true,
                    label: 'Add the widget to home screen',
                    onTap: _add,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('widget-add'),
                      onTap: _add,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.ink,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 20, color: tokens.onInk),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Add the widget to home screen',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.onInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                    child: Text(
                      _pinRefused
                          ? 'Your launcher did not offer it. Touch and hold '
                                'the home screen, choose Widgets, then Moment.'
                          : 'Or touch and hold the home screen, choose '
                                'Widgets, then Moment. It comes in three '
                                'sizes and you can resize it.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: tokens.secondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
                    child: Text(
                      'What the widget shows is kept on this phone, outside '
                      'your journal. Nothing is sent anywhere.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: tokens.secondary,
                      ),
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

  Widget _label(String text, MomentTokens tokens) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: tokens.secondary,
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.tokens,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final MomentTokens tokens;
  final String title;
  final String detail;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: title,
      hint: detail,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? tokens.ink : tokens.secondary,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tokens.ink,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: tokens.ink,
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.ink,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                badge!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: tokens.onInk,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 13,
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
      ),
    );
  }
}
