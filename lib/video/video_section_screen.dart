import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'video_poster.dart';

final _dayFormat = DateFormat('EEE d MMM');

/// Videos, as a two-column grid of posters: Library opens this when the
/// Video tile is tapped. Matches design/mockups/png/14-Section-Videos.png
/// (month headings are a cosmetic layer for the Phase 5 fidelity pass).
class VideoSectionScreen extends StatelessWidget {
  const VideoSectionScreen({
    super.key,
    required this.repository,
    this.onBack,
    this.onOpenLog,
  });

  final LogRepository repository;
  final VoidCallback? onBack;
  final ValueChanged<Log>? onOpenLog;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.video);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: StreamBuilder<List<Log>>(
              stream: repository.watchFeed(types: {LogType.video}),
              builder: (context, snapshot) {
                final logs = snapshot.data ?? const [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          onTap: onBack,
                          label: 'Back to Library',
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: const ValueKey('video-section-back'),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.tintFor(LogType.video),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            momentIconFor(LogType.video),
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              momentLabelFor(LogType.video),
                              style: TextStyle(
                                fontFamily: 'Newsreader',
                                fontWeight: FontWeight.w500,
                                fontSize: 34,
                                color: tokens.ink,
                              ),
                            ),
                            Text(
                              '${logs.length} '
                              '${logs.length == 1 ? 'log' : 'logs'}',
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
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.25,
                          ),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index] as VideoLog;
                        return _VideoTile(
                          key: ValueKey('video-tile-${log.id}'),
                          log: log,
                          tokens: tokens,
                          onTap: () => onOpenLog?.call(log),
                        );
                      },
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

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    super.key,
    required this.log,
    required this.tokens,
    required this.onTap,
  });

  final VideoLog log;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPoster(path: log.posterPath, tokens: tokens),
                  Center(child: PlayBadge(tokens: tokens, size: 38)),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: ClipLengthPill(
                      duration: log.duration,
                      tokens: tokens,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _dayFormat.format(log.localMoment),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: tokens.ink),
          ),
        ],
      ),
    );
  }
}
