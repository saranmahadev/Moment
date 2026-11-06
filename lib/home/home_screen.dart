import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'feed_card.dart';
import 'feed_grouping.dart';
import 'mood_row.dart';
import 'type_filter_chips.dart';

final _weekdayFormat = DateFormat('EEEE');
final _dateFormat = DateFormat('d MMMM y');

/// Home: today's date, type filter chips, the one-tap mood row, and the
/// feed grouped by day. Matches design/mockups/Main.dc.html.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    DateTime Function()? now,
    this.onOpenLog,
    this.onSearchTap,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final DateTime Function() now;
  final ValueChanged<Log>? onOpenLog;
  final VoidCallback? onSearchTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LogType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final now = widget.now();

    return StreamBuilder<List<Log>>(
      stream: widget.repository.watchFeed(
        types: _selectedType == null ? null : {_selectedType!},
      ),
      builder: (context, snapshot) {
        final sections = groupFeedByDay(snapshot.data ?? const [], now: now);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 140),
          children: [
            _Header(now: now, tokens: tokens, onSearchTap: widget.onSearchTap),
            const SizedBox(height: 12),
            TypeFilterChips(
              availableTypes: builtLogTypes,
              selected: _selectedType,
              onSelected: (type) => setState(() => _selectedType = type),
            ),
            const SizedBox(height: 12),
            MoodRow(
              onMoodTapped: (emoji) =>
                  widget.repository.createEmoji(emoji: emoji, strength: 3),
            ),
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'Your day is unwritten.',
                    style: TextStyle(fontSize: 15, color: tokens.secondary),
                  ),
                ),
              )
            else
              for (final section in sections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(
                    section.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.96,
                      color: tokens.secondary,
                    ),
                  ),
                ),
                for (final log in section.logs)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FeedCard(
                      key: ValueKey('feed-card-${log.id}'),
                      log: log,
                      onTap: () => widget.onOpenLog?.call(log),
                    ),
                  ),
              ],
            if (sections.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Text(
                  'Older logs live in Library.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: tokens.secondary),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.tokens, this.onSearchTap});

  final DateTime now;
  final MomentTokens tokens;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _weekdayFormat.format(now),
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontWeight: FontWeight.w500,
                fontSize: 38,
                letterSpacing: -0.38,
                height: 1.15,
                color: tokens.ink,
              ),
            ),
            Text(
              _dateFormat.format(now),
              style: TextStyle(fontSize: 14.5, color: tokens.secondary),
            ),
          ],
        ),
        const Spacer(),
        Semantics(
          button: true,
          label: 'Search',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onSearchTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: GlassSurface(
                variant: GlassVariant.card,
                borderRadius: 22,
                child: Icon(Icons.search, color: tokens.ink, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
