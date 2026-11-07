import 'dart:io';

import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';

/// Photos, as a grid: Library opens this when the Photo tile is tapped.
/// Matches design/mockups/png/13-Section-Photos.png (month grouping is a
/// cosmetic layer for the Phase 5 fidelity pass, not built here).
class PhotoSectionScreen extends StatelessWidget {
  const PhotoSectionScreen({
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
    final color = tokens.colorFor(LogType.photo);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: StreamBuilder<List<Log>>(
              stream: repository.watchFeed(types: {LogType.photo}),
              builder: (context, snapshot) {
                final logs = snapshot.data ?? const [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Back to Library',
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: const ValueKey('photo-section-back'),
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
                            color: tokens.tintFor(LogType.photo),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            momentIconFor(LogType.photo),
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              momentLabelFor(LogType.photo),
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
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index] as PhotoLog;
                        return GestureDetector(
                          key: ValueKey('photo-tile-${log.id}'),
                          onTap: () => onOpenLog?.call(log),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(log.thumbnailPath),
                              fit: BoxFit.cover,
                            ),
                          ),
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
