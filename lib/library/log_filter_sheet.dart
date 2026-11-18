import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log_type.dart';
import 'log_filter.dart';

/// Opens the filter popup for [type] and returns what was applied, or null
/// when it was dismissed.
Future<LogFilter?> showLogFilterSheet(
  BuildContext context, {
  required LogType type,
  required LogFilter initial,
}) {
  final tokens =
      Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
  return showModalBottomSheet<LogFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.ground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => LogFilterSheet(
      type: type,
      initial: initial,
      onApply: (filter) => Navigator.of(sheetContext).pop(filter),
    ),
  );
}

String _namedLabel(LogType type) => switch (type) {
  LogType.audio => 'Only with a title',
  LogType.location => 'Only with a name',
  _ => 'Only with a caption',
};

/// What can be filtered by, for [type]: when and order for every type,
/// strengths for emoji, and a caption, title or name where the type has one.
/// Applying hands back the whole filter; Reset applies the empty one.
class LogFilterSheet extends StatefulWidget {
  const LogFilterSheet({
    super.key,
    required this.type,
    required this.initial,
    required this.onApply,
  });

  final LogType type;
  final LogFilter initial;
  final ValueChanged<LogFilter> onApply;

  @override
  State<LogFilterSheet> createState() => _LogFilterSheetState();
}

class _LogFilterSheetState extends State<LogFilterSheet> {
  late LogFilter _filter = widget.initial;

  bool get _hasName => const {
    LogType.photo,
    LogType.video,
    LogType.audio,
    LogType.location,
  }.contains(widget.type);

  void _toggleStrength(int value) {
    final next = {..._filter.strengths};
    next.contains(value) ? next.remove(value) : next.add(value);
    setState(() => _filter = _filter.copyWith(strengths: next));
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: tokens.secondary,
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              Text(
                'Filter ${momentLabelFor(widget.type)}',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 28,
                  color: tokens.ink,
                ),
              ),
              label('WHEN'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final window in FilterWindow.values)
                    _Choice(
                      text: window.label,
                      selected: _filter.window == window,
                      tokens: tokens,
                      onTap: () => setState(
                        () => _filter = _filter.copyWith(window: window),
                      ),
                    ),
                ],
              ),
              label('ORDER'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Choice(
                    text: 'Newest first',
                    selected: !_filter.oldestFirst,
                    tokens: tokens,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(oldestFirst: false),
                    ),
                  ),
                  _Choice(
                    text: 'Oldest first',
                    selected: _filter.oldestFirst,
                    tokens: tokens,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(oldestFirst: true),
                    ),
                  ),
                ],
              ),
              if (widget.type == LogType.emoji) ...[
                label('STRENGTH'),
                Row(
                  spacing: 8,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      _Choice(
                        text: '$i',
                        semanticLabel: 'Strength $i',
                        selected: _filter.strengths.contains(i),
                        tokens: tokens,
                        round: true,
                        onTap: () => _toggleStrength(i),
                      ),
                  ],
                ),
              ],
              if (_hasName) ...[
                label('ONLY'),
                _Choice(
                  text: _namedLabel(widget.type),
                  selected: _filter.onlyNamed,
                  tokens: tokens,
                  onTap: () => setState(
                    () => _filter = _filter.copyWith(
                      onlyNamed: !_filter.onlyNamed,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Reset',
                    onTap: () => widget.onApply(const LogFilter()),
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onApply(const LogFilter()),
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Apply',
                    onTap: () => widget.onApply(_filter),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => widget.onApply(_filter),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: tokens.ink,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tokens.onInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip you can choose: ink when chosen, glass when not.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.text,
    required this.selected,
    required this.tokens,
    required this.onTap,
    this.semanticLabel,
    this.round = false,
  });

  final String text;
  final String? semanticLabel;
  final bool selected;
  final MomentTokens tokens;
  final VoidCallback onTap;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? text,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          width: round ? 44 : null,
          padding: round ? null : const EdgeInsets.symmetric(horizontal: 16),
          // Round chips are boxes of their own; the others hug their text.
          alignment: round ? Alignment.center : null,
          decoration: BoxDecoration(
            color: selected
                ? tokens.ink
                : tokens.solidSurface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? tokens.ink : tokens.ink.withValues(alpha: 0.14),
            ),
          ),
          child: Center(
            widthFactor: round ? null : 1,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? tokens.onInk : tokens.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
