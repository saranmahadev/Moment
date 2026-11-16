import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'coordinates.dart';
import 'location_widgets.dart';
import 'stylised_map.dart';

final _whenFormat = DateFormat('EEE d MMM · HH:mm');

/// Locations, as a map tile with a pin per place and a list below: Library
/// opens this when the Location tile is tapped. Matches
/// design/mockups/png/16-Section-Locations.png.
class LocationSectionScreen extends StatelessWidget {
  const LocationSectionScreen({
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
    final color = tokens.colorFor(LogType.location);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: StreamBuilder<List<Log>>(
              stream: repository.watchFeed(types: {LogType.location}),
              builder: (context, snapshot) {
                final logs = (snapshot.data ?? const <Log>[])
                    .cast<LocationLog>();
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
                            key: const ValueKey('location-section-back'),
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
                            color: tokens.tintFor(LogType.location),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            momentIconFor(LogType.location),
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              momentLabelFor(LogType.location),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SizedBox(
                        height: 210,
                        child: StylisedMap(
                          pins: projectPins([
                            for (final log in logs)
                              (log.latitude, log.longitude),
                          ]),
                          pinSize: 30,
                        ),
                      ),
                    ),
                    for (final log in logs)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _LocationRow(
                          key: ValueKey('location-row-${log.id}'),
                          log: log,
                          tokens: tokens,
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

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    super.key,
    required this.log,
    required this.tokens,
    required this.onTap,
  });

  final LocationLog log;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accuracy = log.accuracyMeters;
    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        variant: GlassVariant.card,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.tintFor(LogType.location),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  momentIconFor(LogType.location),
                  size: 20,
                  color: tokens.colorFor(LogType.location),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.name ??
                          formatCoordinates(log.latitude, log.longitude),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      _whenFormat.format(log.localMoment),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: tokens.secondary),
                    ),
                  ],
                ),
              ),
              if (accuracy != null) ...[
                const SizedBox(width: 8),
                LocationPill(label: formatAccuracy(accuracy), tokens: tokens),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
