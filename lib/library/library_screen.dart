import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/text_growth.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'log_filter.dart';

final _lastDateFormat = DateFormat('d MMM');

/// Library: one tile per type that has been built so far, each showing its
/// count and when it was last logged, plus a Trash row. Matches
/// design/mockups/png/04-Library-one-section-per-type.png.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.repository,
    DateTime Function()? now,
    this.onOpenType,
    this.onOpenTrash,
    this.filters = const {},
    this.onFilter,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final DateTime Function() now;
  final ValueChanged<LogType>? onOpenType;
  final VoidCallback? onOpenTrash;

  /// The filter in force for each type (none: no entry), and what to do
  /// when a card's filter button is pressed.
  final Map<LogType, LogFilter> filters;
  final ValueChanged<LogType>? onFilter;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final today = DateTime.utc(now().year, now().month, now().day);

    return Scaffold(
      // Transparent: this screen is always a tab inside AppShell, which
      // already paints tokens.ground and the shared OrbField behind it.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 38,
                    color: tokens.ink,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 22,
                    child: Icon(Icons.search, color: tokens.ink),
                  ),
                ),
              ],
            ),
            Text(
              'Everything you have logged, one section per type.',
              style: TextStyle(fontSize: 14.5, color: tokens.secondary),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Taller tiles when the system text size is larger.
              childAspectRatio: 0.78 / textGrowth(context),
              children: [
                for (final type in builtLogTypes)
                  _TypeTile(
                    type: type,
                    repository: repository,
                    today: today,
                    tokens: tokens,
                    onTap: () => onOpenType?.call(type),
                    filter: filters[type] ?? const LogFilter(),
                    onFilter: () => onFilter?.call(type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _TrashRow(
              repository: repository,
              tokens: tokens,
              onTap: onOpenTrash,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.repository,
    required this.today,
    required this.tokens,
    required this.onTap,
    required this.filter,
    required this.onFilter,
  });

  final LogType type;
  final LogRepository repository;
  final DateTime today;
  final MomentTokens tokens;
  final VoidCallback onTap;
  final LogFilter filter;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Log>>(
      stream: repository.watchFeed(types: {type}),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const [];
        final count = logs.length;
        final lastLabel = logs.isEmpty
            ? 'No logs yet'
            : '$count ${count == 1 ? 'log' : 'logs'} · Last: '
                  '${logs.first.localDay == today ? 'Today' : _lastDateFormat.format(logs.first.localMoment)}';

        return GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
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
                          child: Icon(
                            momentIconFor(type),
                            color: tokens.colorFor(type),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          momentLabelFor(type),
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 26,
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _FilterButton(
                  type: type,
                  filter: filter,
                  tokens: tokens,
                  onTap: onFilter,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The filter button on a card: 44 pt, with the number of choices in force.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.type,
    required this.filter,
    required this.tokens,
    required this.onTap,
  });

  final LogType type;
  final LogFilter filter;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = filter.activeCount;
    final name = momentLabelFor(type);
    return Semantics(
      button: true,
      label: active == 0 ? 'Filter $name' : 'Filter $name, $active active',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune,
                size: 20,
                color: active == 0 ? tokens.secondary : tokens.colorFor(type),
              ),
              if (active > 0)
                Positioned(
                  top: 6,
                  right: 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: tokens.ink,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$active',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tokens.onInk,
                      ),
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

class _TrashRow extends StatelessWidget {
  const _TrashRow({required this.repository, required this.tokens, this.onTap});

  final LogRepository repository;
  final MomentTokens tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Log>>(
      stream: repository.watchTrash(),
      builder: (context, snapshot) {
        final count = (snapshot.data ?? const []).length;
        return GestureDetector(
          onTap: onTap,
          child: GlassSurface(
            variant: GlassVariant.card,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: tokens.ink),
                  const SizedBox(width: 12),
                  Text(
                    'Trash',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$count ${count == 1 ? 'log' : 'logs'}',
                    style: TextStyle(fontSize: 14, color: tokens.secondary),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 20, color: tokens.secondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
