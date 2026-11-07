import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';

/// The twelve quick-pick moods offered on the New Emoji screen, in grid
/// order. Labels for 😊, 😌, 😐, 😔 and 😤 match the mood row and the
/// section/detail screens; the rest are this screen's own reasonable
/// choices, since the mockups do not name them.
const _presetMoods = [
  ('😊', 'Happy'),
  ('😌', 'Calm'),
  ('🙂', 'Content'),
  ('😄', 'Joyful'),
  ('🥰', 'Loved'),
  ('😴', 'Tired'),
  ('😐', 'Neutral'),
  ('😔', 'Sad'),
  ('😢', 'Crying'),
  ('😤', 'Frustrated'),
  ('😰', 'Anxious'),
  ('🤒', 'Unwell'),
];

/// The New Emoji screen: pick a mood, set how strong it is, and save.
/// Matches design/mockups/png/06-Create-Emoji.png.
class CreateEmojiScreen extends StatefulWidget {
  const CreateEmojiScreen({
    super.key,
    required this.repository,
    DateTime Function()? now,
    required this.onSaved,
    required this.onClose,
    this.editing,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final DateTime Function() now;
  final ValueChanged<String> onSaved;
  final VoidCallback onClose;

  /// When set, this screen edits that log in place instead of creating a
  /// new one.
  final EmojiLog? editing;

  @override
  State<CreateEmojiScreen> createState() => _CreateEmojiScreenState();
}

class _CreateEmojiScreenState extends State<CreateEmojiScreen> {
  late int _selectedIndex = _indexFor(widget.editing?.emoji);
  late int _strength = widget.editing?.strength ?? 3;

  static int _indexFor(String? emoji) {
    if (emoji == null) return 0;
    final index = _presetMoods.indexWhere((mood) => mood.$1 == emoji);
    return index == -1 ? 0 : index;
  }

  Future<void> _save() async {
    final (emoji, label) = _presetMoods[_selectedIndex];

    final editing = widget.editing;
    if (editing != null) {
      await widget.repository.updateEmoji(
        editing.id,
        emoji: emoji,
        label: label,
        strength: _strength,
      );
      widget.onSaved(editing.id);
      return;
    }

    final id = await widget.repository.createEmoji(
      emoji: emoji,
      label: label,
      strength: _strength,
      createdAt: widget.now(),
    );
    widget.onSaved(id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final (emoji, label) = _presetMoods[_selectedIndex];
    final typeColor = tokens.colorFor(LogType.emoji);
    final typeTint = tokens.tintFor(LogType.emoji);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Close without saving',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: GlassSurface(
                          variant: GlassVariant.card,
                          borderRadius: 22,
                          child: Icon(Icons.close, size: 20, color: tokens.ink),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        height: 44,
                        child: GlassSurface(
                          variant: GlassVariant.card,
                          borderRadius: 22,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: typeTint,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    momentIconFor(LogType.emoji),
                                    size: 15,
                                    color: typeColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Emoji',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(
                        color: tokens.ink,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Log mood',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 150,
                height: 150,
                child: GlassSurface(
                  variant: GlassVariant.surface,
                  borderRadius: 75,
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 88)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 34,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'HOW STRONG?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.04,
                  color: tokens.secondary,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Light', style: TextStyle(color: tokens.secondary)),
                    const SizedBox(width: 10),
                    for (var i = 1; i <= 5; i++) ...[
                      _StrengthButton(
                        value: i,
                        isSelected: i == _strength,
                        tokens: tokens,
                        onTap: () => setState(() => _strength = i),
                      ),
                      if (i < 5) const SizedBox(width: 8),
                    ],
                    const SizedBox(width: 10),
                    Text('Strong', style: TextStyle(color: tokens.secondary)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassSurface(
                variant: GlassVariant.surface,
                borderRadius: 28,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                    children: [
                      for (var i = 0; i < _presetMoods.length; i++)
                        _MoodCell(
                          emoji: _presetMoods[i].$1,
                          label: _presetMoods[i].$2,
                          isSelected: i == _selectedIndex,
                          typeColor: typeColor,
                          typeTint: typeTint,
                          onTap: () => setState(() => _selectedIndex = i),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrengthButton extends StatelessWidget {
  const _StrengthButton({
    required this.value,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  final int value;
  final bool isSelected;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = 'Intensity $value of 5${isSelected ? ', selected' : ''}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: isSelected
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.ink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : GlassSurface(
                  variant: GlassVariant.card,
                  borderRadius: 22,
                  child: Center(
                    child: Text(
                      '$value',
                      style: TextStyle(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MoodCell extends StatelessWidget {
  const _MoodCell({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.typeColor,
    required this.typeTint,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool isSelected;
  final Color typeColor;
  final Color typeTint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label${isSelected ? ', selected' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? typeTint : Colors.transparent,
            border: Border.all(
              color: isSelected ? typeColor : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
