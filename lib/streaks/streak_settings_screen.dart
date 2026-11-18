import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/round_glass_button.dart';
import '../design/tokens.dart';
import '../settings/app_settings.dart';
import 'streak_model.dart';

/// What the grace choice is called in a list: "1 grace day a week".
String graceLabel(int days) => switch (days) {
  0 => 'No grace days',
  1 => '1 grace day a week',
  _ => '$days grace days a week',
};

/// Streak settings: whether streaks are shown, and how many missed days a
/// week they forgive. A change is saved at once.
class StreakSettingsScreen extends StatelessWidget {
  const StreakSettingsScreen({
    super.key,
    required this.settings,
    required this.onBack,
  });

  final AppSettings settings;
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
                        onTap: onBack,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          container: true,
                          header: true,
                          child: Text(
                            'Streaks',
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
                  const SizedBox(height: 16),
                  GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 26,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Show streaks',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    color: tokens.ink,
                                  ),
                                ),
                                Text(
                                  'Home chip, Calendar card and the Streaks '
                                  'page',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            label: 'Show streaks',
                            child: Switch(
                              key: const ValueKey('streaks-show-switch'),
                              value: settings.showStreaks,
                              onChanged: settings.setShowStreaks,
                              activeThumbColor: tokens.onInk,
                              activeTrackColor: tokens.ink,
                              inactiveTrackColor: tokens.switchOff,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _label('GRACE DAYS', tokens),
                  GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 26,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Missed days forgiven each week',
                            style: TextStyle(fontSize: 16.5, color: tokens.ink),
                          ),
                          const SizedBox(height: 12),
                          _GraceChoice(settings: settings, tokens: tokens),
                          const SizedBox(height: 16),
                          _GracePreview(
                            grace: settings.graceDays,
                            tokens: tokens,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            settings.graceDays == 0
                                ? 'With no grace days, one missed day ends '
                                      'the streak.'
                                : 'A streak survives ${settings.graceDays} '
                                      'missed ${settings.graceDays == 1 ? 'day' : 'days'} '
                                      'in any 7 days. Forgiven days show as '
                                      'outlined squares and count in the total.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: tokens.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _label('HOW A DAY IS COUNTED', tokens),
                  GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 26,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Text(
                        'A day runs from midnight to midnight, in the time '
                        'zone you were in when you made the log. Any log '
                        'type counts. Logs in Trash do not.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: tokens.secondary,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
                    child: Text(
                      'The evening reminder never mentions streaks.\n'
                      'Streaks are worked out on this phone. Nothing is '
                      'stored or sent.',
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

/// 0, 1, 2 and 3 as one row of big buttons.
class _GraceChoice extends StatelessWidget {
  const _GraceChoice({required this.settings, required this.tokens});

  final AppSettings settings;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var n = 0; n <= maxGraceDays; n++)
              Expanded(
                child: Semantics(
                  key: ValueKey('grace-$n'),
                  container: true,
                  button: true,
                  selected: settings.graceDays == n,
                  label: graceLabel(n),
                  onTap: () => settings.setGraceDays(n),
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => settings.setGraceDays(n),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: settings.graceDays == n ? tokens.ink : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: settings.graceDays == n
                              ? tokens.onInk
                              : tokens.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fourteen days in a row, with days 4, 12 and 13 missed, drawn the way
/// the streak rules treat them for the chosen grace days: a square for a
/// day logged, an outline for one forgiven, a faint blank for one that
/// ended a streak.
class _GracePreview extends StatelessWidget {
  const _GracePreview({required this.grace, required this.tokens});

  final int grace;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.utc(2026, 1, 14);
    const missed = {4, 12, 13};
    final logged = {
      for (var day = 1; day <= 14; day++)
        if (!missed.contains(day)) DateTime.utc(2026, 1, day),
    };
    final summary = streakOf(logged, today, grace: grace);

    return ExcludeSemantics(
      child: Row(
        key: const ValueKey('grace-preview'),
        children: [
          for (var day = 1; day <= 14; day++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: logged.contains(DateTime.utc(2026, 1, day))
                          ? tokens.streakRamp[2]
                          : null,
                      borderRadius: BorderRadius.circular(4),
                      border:
                          summary.graceDays.contains(DateTime.utc(2026, 1, day))
                          ? Border.all(
                              color: tokens.secondary.withValues(alpha: 0.8),
                            )
                          : null,
                    ),
                    child:
                        logged.contains(DateTime.utc(2026, 1, day)) ||
                            summary.graceDays.contains(
                              DateTime.utc(2026, 1, day),
                            )
                        ? null
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: tokens.ink.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
