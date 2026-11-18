import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../audio/player_waveform.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import '../video/video_poster.dart' show formatClipLength;

final _when = DateFormat('EEE d MMM · HH:mm');

/// One recording in the Audio section, as in the mockup: a play mark,
/// the title and when, a small waveform and the length. The whole row
/// opens the player.
class AudioRow extends StatelessWidget {
  const AudioRow({super.key, required this.log, this.onTap});

  final AudioLog log;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final title = log.title ?? 'Audio';
    final when = _when.format(log.localMoment);
    final length = formatClipLength(log.duration);
    final colour = tokens.colorFor(LogType.audio);
    return Semantics(
      container: true,
      button: true,
      label: '$title, $when, $length',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassSurface(
          variant: GlassVariant.card,
          borderRadius: 22,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tokens.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: tokens.onInk),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        when,
                        style: TextStyle(fontSize: 13, color: tokens.secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 64,
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final peak in resamplePeaks(log.peaks, 8))
                        Container(
                          width: 3,
                          height: 4 + 20 * peak,
                          decoration: BoxDecoration(
                            color: colour.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 36,
                  child: Text(
                    length,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.secondary,
                    ),
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
