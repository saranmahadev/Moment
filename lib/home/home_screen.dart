import '../emoji/moods.dart';
import '../settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import '../streaks/streak_builder.dart';
import '../streaks/streak_chip.dart';
import '../streaks/streak_model.dart';
import 'feed_card.dart';
import 'feed_grouping.dart';
import 'mood_row.dart';
import 'type_filter_chips.dart';

final _weekdayFormat = DateFormat('EEEE');
final _dateFormat = DateFormat('d MMMM y');

/// Home: today's date, type filter chips, the one-tap mood row, and the
/// feed grouped by day. Matches design/mockups/Main.dc.html.
/// A tap on the Home row logs the emoji at full strength; the New Emoji
/// screen is where a lighter feeling is chosen.
const quickEmojiStrength = 5;

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    this.settings,
    DateTime Function()? now,
    this.onOpenLog,
    this.onSearchTap,
    this.onOpenStreaks,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;

  /// Where the quick emoji row comes from; the default five without it.
  final AppSettings? settings;
  final DateTime Function() now;
  final ValueChanged<Log>? onOpenLog;
  final VoidCallback? onSearchTap;

  /// Opens the Streaks page; the streak chip beside Search calls it.
  final VoidCallback? onOpenStreaks;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// How many logs one page of the feed holds; more load as you scroll.
  static const _page = 60;

  LogType? _selectedType;
  int _limit = _page;
  bool _loadingMore = false;

  Stream<List<Log>>? _feed;
  (LogType?, int)? _feedFor;

  /// One query per filter and page size, not one per build.
  Stream<List<Log>> get _stream {
    final key = (_selectedType, _limit);
    if (_feed == null || _feedFor != key) {
      _feedFor = key;
      _feed = widget.repository.watchFeed(
        types: _selectedType == null ? null : {_selectedType!},
        limit: _limit,
      );
    }
    return _feed!;
  }

  void _select(LogType? type) => setState(() {
    _selectedType = type;
    _limit = _page;
  });

  /// Asks for the next page once the end of this one is being built.
  void _loadMore() {
    if (_loadingMore) return;
    _loadingMore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _limit += _page;
        _loadingMore = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final now = widget.now();

    return StreamBuilder<List<Log>>(
      stream: _stream,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const <Log>[];
        // A full page means there may be more beyond it.
        final more = logs.length >= _limit;
        final sections = groupFeedByDay(logs, now: now);

        final items = <Widget>[
          StreakBuilder(
            repository: widget.repository,
            settings: widget.settings,
            now: widget.now,
            builder: (context, streak) => _Header(
              now: now,
              tokens: tokens,
              onSearchTap: widget.onSearchTap,
              streak: streak,
              onStreakTap: widget.onOpenStreaks,
            ),
          ),
          const SizedBox(height: 12),
          TypeFilterChips(
            availableTypes: builtLogTypes,
            selected: _selectedType,
            onSelected: _select,
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: widget.settings ?? const _NoSettings(),
            builder: (context, _) => MoodRow(
              emoji: widget.settings?.quickEmoji ?? defaultQuickEmoji,
              onMoodTapped: (emoji) => widget.repository.createEmoji(
                emoji: emoji,
                label: moodLabel(emoji),
                strength: quickEmojiStrength,
              ),
            ),
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
        ];

        // Built lazily: only the cards on screen exist.
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 140),
          itemCount: items.length,
          itemBuilder: (context, index) {
            if (more && index >= items.length - 8) _loadMore();
            return items[index];
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.now,
    required this.tokens,
    this.onSearchTap,
    this.streak,
    this.onStreakTap,
  });

  final DateTime now;
  final MomentTokens tokens;
  final VoidCallback? onSearchTap;
  final StreakSummary? streak;
  final VoidCallback? onStreakTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Takes what the chip and Search leave, and the weekday shrinks to
        // fit it rather than overflow.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
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
              ),
              Text(
                _dateFormat.format(now),
                style: TextStyle(fontSize: 14.5, color: tokens.secondary),
              ),
            ],
          ),
        ),
        if (streak != null && streak!.current > 0) ...[
          StreakChip(summary: streak!, onTap: onStreakTap),
          const SizedBox(width: 8),
        ],
        Semantics(
          button: true,
          label: 'Search',
          onTap: onSearchTap,
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

/// Stands in for the settings when a screen is shown without them: it
/// never changes.
class _NoSettings implements Listenable {
  const _NoSettings();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
