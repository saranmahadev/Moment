import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/round_glass_button.dart';
import '../design/text_growth.dart';
import '../design/tokens.dart';
import '../domain/log_type.dart';
import '../emoji/moods.dart';
import 'app_settings.dart';

/// Chooses the five emoji on Home's quick row: tap a slot, then the emoji
/// to put there. A change is saved at once.
class QuickEmojiScreen extends StatefulWidget {
  const QuickEmojiScreen({
    super.key,
    required this.settings,
    required this.onBack,
  });

  final AppSettings settings;
  final VoidCallback onBack;

  @override
  State<QuickEmojiScreen> createState() => _QuickEmojiScreenState();
}

class _QuickEmojiScreenState extends State<QuickEmojiScreen> {
  int _slot = 0;

  void _choose(String emoji) {
    final row = widget.settings.quickEmoji;
    final already = row.indexOf(emoji);
    if (already == _slot) return;
    // An emoji already in the row changes places with the selected slot,
    // so the row never shows the same one twice.
    if (already != -1) row[already] = row[_slot];
    row[_slot] = emoji;
    widget.settings.setQuickEmoji(row);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.emoji);
    final tint = tokens.tintFor(LogType.emoji);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.settings,
              builder: (context, _) {
                final row = widget.settings.quickEmoji;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Row(
                      children: [
                        RoundGlassButton(
                          icon: Icons.chevron_left,
                          label: 'Back',
                          onTap: widget.onBack,
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            onTap: () => widget.settings.setQuickEmoji(
                              defaultQuickEmoji,
                            ),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                              child: Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Quick emoji row',
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontWeight: FontWeight.w500,
                        fontSize: 32,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a slot, then the emoji to put there.',
                      style: TextStyle(fontSize: 14.5, color: tokens.secondary),
                    ),
                    const SizedBox(height: 16),
                    GlassSurface(
                      variant: GlassVariant.card,
                      borderRadius: 28,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < row.length; i++)
                              _Cell(
                                key: ValueKey('quick-slot-$i'),
                                emoji: row[i],
                                label:
                                    'Slot ${i + 1}, '
                                    '${moodLabel(row[i]) ?? row[i]}'
                                    '${i == _slot ? ', selected' : ''}',
                                selected: i == _slot,
                                color: color,
                                tint: tint,
                                size: 56,
                                onTap: () => setState(() => _slot = i),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassSurface(
                      variant: GlassVariant.card,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: 8,
                          children: [
                            for (final (emoji, label) in moodPalette)
                              _Cell(
                                key: ValueKey('quick-choice-$emoji'),
                                emoji: emoji,
                                label: row.contains(emoji)
                                    ? '$label, in the row'
                                    : label,
                                selected: row[_slot] == emoji,
                                color: color,
                                tint: tint,
                                size: 76,
                                caption: label,
                                captionColor: tokens.secondary,
                                onTap: () => _choose(emoji),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.color,
    required this.tint,
    required this.size,
    required this.onTap,
    this.caption,
    this.captionColor,
  });

  final String emoji;
  final String label;
  final bool selected;
  final Color color;
  final Color tint;
  final double size;
  final VoidCallback onTap;
  final String? caption;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height:
              (caption == null ? size : size + 6) +
              extraTextHeight(context, 28) +
              (caption == null ? 0 : extraTextHeight(context, 11.5)),
          decoration: BoxDecoration(
            color: selected ? tint : null,
            borderRadius: BorderRadius.circular(18),
            border: selected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: captionColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
