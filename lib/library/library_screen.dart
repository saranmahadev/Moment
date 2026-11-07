import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';

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
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final DateTime Function() now;
  final ValueChanged<LogType>? onOpenType;
  final VoidCallback? onOpenTrash;

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
              childAspectRatio: 0.78,
              children: [
                for (final type in builtLogTypes)
                  _TypeTile(
                    type: type,
                    repository: repository,
                    today: today,
                    tokens: tokens,
                    onTap: () => onOpenType?.call(type),
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
  });

  final LogType type;
  final LogRepository repository;
  final DateTime today;
  final MomentTokens tokens;
  final VoidCallback onTap;

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
                    style: TextStyle(fontSize: 13, color: tokens.secondary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
