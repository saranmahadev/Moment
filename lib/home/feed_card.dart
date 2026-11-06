import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';

final _timeFormat = DateFormat('HH:mm');

/// One entry in the Home feed (or a type's section list): a type badge,
/// label and time, then whatever that type shows. Matches the card style
/// in design/mockups/Main.dc.html.
class FeedCard extends StatelessWidget {
  const FeedCard({super.key, required this.log, this.onTap});

  final Log log;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

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
              _Header(log: log, tokens: tokens),
              const SizedBox(height: 10),
              _Body(log: log, tokens: tokens),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.log, required this.tokens});

  final Log log;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = tokens.colorFor(log.type);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tokens.tintFor(log.type),
            shape: BoxShape.circle,
          ),
          child: Icon(momentIconFor(log.type), size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          switch (log.type) {
            LogType.text => 'Text',
            LogType.emoji => 'Emoji',
            LogType.photo => 'Photo',
            LogType.video => 'Video',
            LogType.audio => 'Audio',
            LogType.location => 'Location',
          },
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const Spacer(),
        Text(
          _timeFormat.format(log.localMoment),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.secondary,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.log, required this.tokens});

  final Log log;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final log = this.log;
    return switch (log) {
      TextLog() => _TextBody(log: log, tokens: tokens),
      EmojiLog() => _EmojiBody(log: log, tokens: tokens),
    };
  }
}

class _TextBody extends StatelessWidget {
  const _TextBody({required this.log, required this.tokens});

  final TextLog log;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final wordCount = log.body
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          log.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 19,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$wordCount words',
          style: TextStyle(fontSize: 12.5, color: tokens.secondary),
        ),
      ],
    );
  }
}

class _EmojiBody extends StatelessWidget {
  const _EmojiBody({required this.log, required this.tokens});

  final EmojiLog log;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = tokens.colorFor(LogType.emoji);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.tintFor(LogType.emoji),
            shape: BoxShape.circle,
          ),
          child: Text(log.emoji, style: const TextStyle(fontSize: 34)),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (log.label != null)
              Text(
                log.label!,
                style: const TextStyle(fontFamily: 'Newsreader', fontSize: 24),
              ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Intensity ${log.strength} of 5',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= log.strength
                              ? color
                              : tokens.ink.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
