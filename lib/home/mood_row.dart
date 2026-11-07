import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';

const _moods = [
  ('😊', 'happy'),
  ('😌', 'calm'),
  ('😐', 'neutral'),
  ('😔', 'sad'),
  ('😤', 'frustrated'),
];

/// The one-tap mood row on Home: "How are you?" and five emoji buttons,
/// each of which logs an emoji entry immediately. Matches the mood card in
/// design/mockups/Main.dc.html.
class MoodRow extends StatelessWidget {
  const MoodRow({super.key, required this.onMoodTapped});

  /// Called with the tapped emoji, e.g. `'😌'`.
  final ValueChanged<String> onMoodTapped;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return GlassSurface(
      variant: GlassVariant.card,
      borderRadius: 28,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
        child: Row(
          children: [
            Flexible(
              child: Text(
                'How are you?',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
            ),
            const Spacer(),
            for (final (emoji, name) in _moods)
              Semantics(
                button: true,
                label: 'Log mood $name',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onMoodTapped(emoji),
                  child: SizedBox(
                    width: 44,
                    height: 48,
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
