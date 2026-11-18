import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calendar/calendar_model.dart';
import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/round_glass_button.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import '../home/type_filter_chips.dart';
import '../settings/app_settings.dart';
import 'highlight.dart';

final _when = DateFormat('EEE d MMM · HH:mm');

/// Search across every log, matching design/mockups/png/24-Search.png:
/// results follow the typing, grouped by type with the matched words
/// highlighted. It runs on SQLite's full-text index on this device;
/// nothing is sent anywhere. With the field empty, recent searches are
/// offered.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.onOpenLog,
    required this.onBack,
    this.initialQuery = '',
  });

  /// What the field holds, and is searched for, when the screen opens.
  final String initialQuery;

  final LogRepository repository;
  final AppSettings settings;
  final ValueChanged<Log> onOpenLog;
  final VoidCallback onBack;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  LogType? _type;
  List<Log> _results = const [];

  /// What [_results] answers: the text and filter they were found for.
  String _answered = '';

  /// Counts searches, so an answer that arrives after a newer question was
  /// asked is dropped.
  int _asked = 0;

  String get _query => _controller.text.trim();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_search);
    if (widget.initialQuery.isNotEmpty) _controller.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query;
    final asked = ++_asked;
    final results = query.isEmpty
        ? const <Log>[]
        : await widget.repository.search(query, type: _type);
    if (!mounted || asked != _asked) return;
    setState(() {
      _results = results;
      _answered = query;
    });
  }

  void _open(Log log) {
    widget.settings.addRecentSearch(_query);
    widget.onOpenLog(log);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      RoundGlassButton(
                        icon: Icons.chevron_left,
                        label: 'Back',
                        onTap: widget.onBack,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _field(tokens)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TypeFilterChips(
                    availableTypes: builtLogTypes,
                    selected: _type,
                    onSelected: (type) {
                      setState(() => _type = type);
                      _search();
                    },
                  ),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: widget.settings,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: _body(tokens),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(MomentTokens tokens) {
    return SizedBox(
      height: 48,
      child: GlassSurface(
        variant: GlassVariant.card,
        borderRadius: 24,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search, size: 20, color: tokens.ink),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.settings.addRecentSearch,
                style: TextStyle(fontSize: 16, color: tokens.ink),
                cursorColor: tokens.ink,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  // Fills the pill, so the whole height takes a tap.
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  hintText: 'Search your logs',
                  hintStyle: TextStyle(color: tokens.secondary),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _controller.text.isEmpty
                  ? const SizedBox(width: 14)
                  : Semantics(
                      button: true,
                      label: 'Clear search',
                      onTap: _controller.clear,
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: _controller.clear,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 46,
                          height: 48,
                          child: Icon(Icons.close, size: 18, color: tokens.ink),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(MomentTokens tokens) {
    if (_query.isEmpty) {
      final recent = widget.settings.recentSearches;
      return [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: _GroupLabel('RECENT', tokens: tokens)),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: widget.settings.clearRecentSearches,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          for (final query in recent)
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => _controller.text = query,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18, color: tokens.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, color: tokens.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ];
    }

    // Still waiting for the answer to what is typed now: keep showing the
    // last one rather than flashing "nothing".
    if (_results.isEmpty && _answered == _query) {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Nothing matches “$_query”.',
            style: TextStyle(fontSize: 15, color: tokens.ink),
          ),
        ),
      ];
    }

    return [
      for (final type in LogType.values)
        if (_results.any((log) => log.type == type)) ...[
          Row(
            children: [
              Icon(momentIconFor(type), size: 16, color: tokens.colorFor(type)),
              const SizedBox(width: 6),
              _GroupLabel(
                '${momentLabelFor(type).toUpperCase()} · '
                '${_results.where((log) => log.type == type).length}',
                tokens: tokens,
                color: tokens.colorFor(type),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final log in _results.where((log) => log.type == type)) ...[
            _ResultRow(
              log: log,
              query: _answered,
              tokens: tokens,
              onTap: () => _open(log),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ],
    ];
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {required this.tokens, this.color});

  final String text;
  final MomentTokens tokens;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color ?? tokens.secondary,
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.log,
    required this.query,
    required this.tokens,
    required this.onTap,
  });

  final Log log;
  final String query;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = tokens.colorFor(log.type);

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: GlassSurface(
          variant: GlassVariant.card,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tokens.tintFor(log.type),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(momentIconFor(log.type), size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            for (final (part, hit) in highlightParts(
                              summaryOf(log),
                              query,
                            ))
                              TextSpan(
                                text: part,
                                style: hit
                                    ? TextStyle(
                                        backgroundColor: tokens.highlight,
                                      )
                                    : null,
                              ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.3,
                          color: tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _when.format(log.localMoment),
                        style: TextStyle(fontSize: 13, color: tokens.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
