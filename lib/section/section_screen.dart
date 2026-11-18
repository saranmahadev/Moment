import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/round_glass_button.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import '../home/feed_card.dart';
import '../library/filter_strip.dart';
import '../library/log_filter.dart';

/// One type's full list, newest first unless a filter says otherwise: Library opens this for whichever
/// type the user taps. Matches design/mockups/png/11-Section-Text.png.
class SectionScreen extends StatelessWidget {
  const SectionScreen({
    super.key,
    required this.type,
    required this.repository,
    this.onBack,
    this.onSearch,
    this.onOpenLog,
    this.filter = const LogFilter(),
    this.onClearFilter,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final LogType type;
  final LogRepository repository;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final ValueChanged<Log>? onOpenLog;

  /// The Library filter for this type, and how to clear it.
  final LogFilter filter;
  final VoidCallback? onClearFilter;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(type);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: StreamBuilder<List<Log>>(
              stream: repository.watchFeed(types: {type}),
              builder: (context, snapshot) {
                final logs = snapshot.data ?? const [];
                final shown = filter.apply(logs, today: filterToday(now()));
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Back to Library',
                          onTap: onBack,
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: onBack,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: GlassSurface(
                                variant: GlassVariant.card,
                                borderRadius: 22,
                                child: Icon(
                                  Icons.chevron_left,
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        RoundGlassButton(
                          icon: Icons.search,
                          label: 'Search',
                          onTap: onSearch,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
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
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              momentLabelFor(type),
                              style: TextStyle(
                                fontFamily: 'Newsreader',
                                fontWeight: FontWeight.w500,
                                fontSize: 34,
                                color: tokens.ink,
                              ),
                            ),
                            Text(
                              '${logs.length} ${logs.length == 1 ? 'log' : 'logs'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: tokens.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...filterNotice(
                      filter: filter,
                      total: logs.length,
                      shown: shown.length,
                      tokens: tokens,
                      onClear: onClearFilter,
                    ),
                    for (final log in shown)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: FeedCard(
                          key: ValueKey('section-card-${log.id}'),
                          log: log,
                          showFullDate: true,
                          onTap: () => onOpenLog?.call(log),
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
