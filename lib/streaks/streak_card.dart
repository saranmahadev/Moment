import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import 'streak_model.dart';

/// What a streak card says on its two lines.
({String title, String subtitle}) streakCardText(StreakSummary summary) {
  final title = summary.current > 0
      ? '${summary.current}-day streak'
      : 'Start a streak';
  if (summary.longest == 0) {
    return (title: title, subtitle: 'Log anything today');
  }
  final longest =
      'Longest ${summary.longest} ${summary.longest == 1 ? 'day' : 'days'}';
  final used = summary.graceDaysUsed;
  return (
    title: title,
    subtitle: used > 0
        ? '$longest · $used grace ${used == 1 ? 'day' : 'days'} used'
        : longest,
  );
}

/// The streak at the top of Calendar; a tap opens the Streaks page.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.summary, this.onTap});

  final StreakSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final text = streakCardText(summary);

    return Semantics(
      container: true,
      button: true,
      label: '${text.title}. ${text.subtitle}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('streak-card'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: GlassSurface(
          variant: GlassVariant.card,
          borderRadius: 22,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tokens.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      size: 20,
                      color: tokens.onInk,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                        Text(
                          text.subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tokens.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: tokens.secondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
