import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../emoji/moods.dart';

/// The one-tap mood row on Home: "How are you?" and five emoji buttons,
/// each of which logs an emoji entry immediately. Matches the mood card in
/// design/mockups/Main.dc.html.
class MoodRow extends StatelessWidget {
  const MoodRow({
    super.key,
    required this.onMoodTapped,
    this.emoji = defaultQuickEmoji,
  });

  /// The five emoji offered, as chosen in Settings.
  final List<String> emoji;

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
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        child: Row(
          children: [
            // The question takes whatever the five emoji leave.
            Expanded(
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
            for (final emoji in emoji)
              Semantics(
                button: true,
                label: 'Log mood ${(moodLabel(emoji) ?? emoji).toLowerCase()}',
                onTap: () => onMoodTapped(emoji),
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
