import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log_type.dart';

String _labelFor(LogType type) => switch (type) {
  LogType.text => 'Text',
  LogType.emoji => 'Emoji',
  LogType.photo => 'Photo',
  LogType.video => 'Video',
  LogType.audio => 'Audio',
  LogType.location => 'Location',
};

String _blurbFor(LogType type) => switch (type) {
  LogType.text => 'Write what is on your mind',
  LogType.emoji => 'Log how you feel',
  LogType.photo => 'Take or choose a photo',
  LogType.video => 'Record or choose a video',
  LogType.audio => 'Record a voice note',
  LogType.location => 'Pin where you are',
};

/// The "Add to your log" sheet: one card per type that has been built so
/// far. Matches design/mockups/png/03-Add-pick-a-type.png.
class AddSheet extends StatelessWidget {
  const AddSheet({
    super.key,
    required this.onTypeSelected,
    required this.onClose,
  });

  final ValueChanged<LogType> onTypeSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.ink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add to your log',
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontWeight: FontWeight.w500,
                        fontSize: 30,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      'Each type is its own log. Pick one.',
                      style: TextStyle(fontSize: 14, color: tokens.secondary),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Close',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onClose,
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
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: [
              for (final type in builtLogTypes)
                _TypeCard(
                  type: type,
                  tokens: tokens,
                  onTap: () => onTypeSelected(type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.tokens,
    required this.onTap,
  });

  final LogType type;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = tokens.colorFor(type);
    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        variant: GlassVariant.card,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.tintFor(type),
                  shape: BoxShape.circle,
                ),
                child: Icon(momentIconFor(type), color: color),
              ),
              const SizedBox(height: 12),
              Text(
                _labelFor(type),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _blurbFor(type),
                style: TextStyle(fontSize: 13, color: tokens.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
