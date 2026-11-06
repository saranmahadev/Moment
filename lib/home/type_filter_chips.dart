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

/// Home's "All" plus one chip per type that has been built so far.
/// Matches the filter row in design/mockups/Main.dc.html.
class TypeFilterChips extends StatelessWidget {
  const TypeFilterChips({
    super.key,
    required this.availableTypes,
    required this.selected,
    required this.onSelected,
  });

  final List<LogType> availableTypes;

  /// `null` means "All".
  final LogType? selected;
  final ValueChanged<LogType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'All',
            icon: Icons.grid_view_rounded,
            iconColor: null,
            isSelected: selected == null,
            tokens: tokens,
            onTap: () => onSelected(null),
          ),
          for (final type in availableTypes) ...[
            const SizedBox(width: 8),
            _Chip(
              label: _labelFor(type),
              icon: momentIconFor(type),
              iconColor: tokens.colorFor(type),
              isSelected: selected == type,
              tokens: tokens,
              onTap: () => onSelected(type),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool isSelected;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : iconColor ?? tokens.ink,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : tokens.ink,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        key: ValueKey('type-chip-$label'),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: isSelected
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.ink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: content,
                )
              : GlassSurface(
                  variant: GlassVariant.card,
                  borderRadius: 22,
                  child: content,
                ),
        ),
      ),
    );
  }
}
