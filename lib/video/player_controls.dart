import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../domain/log_type.dart';
import 'overlay_colours.dart';

/// The speed as shown on its chip: 1×, 1.25×, 2×.
String speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.toInt() : speed}×';

/// A small round control (44 pt): mute, loop, speed, fullscreen, back. Over
/// the picture ([overlay]) it is a dark film with white marks, so it reads
/// on any footage; elsewhere it is a glass chip. [selected] tints it with the
/// Video colour.
class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.label,
    required this.tokens,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.overlay = false,
    this.size = 44,
  });

  final String label;
  final MomentTokens tokens;
  final VoidCallback? onTap;
  final Widget child;
  final bool selected;
  final bool overlay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final video = tokens.colorFor(LogType.video);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: overlay
                ? overlayFilm
                : selected
                ? tokens.tintFor(LogType.video)
                : tokens.solidSurface.withValues(alpha: 0.6),
            border: Border.all(
              color: overlay
                  ? onOverlay.withValues(alpha: 0.3)
                  : selected
                  ? video
                  : tokens.ink.withValues(alpha: 0.12),
            ),
          ),
          child: IconTheme(
            data: IconThemeData(
              size: 20,
              color: overlay
                  ? onOverlay
                  : selected
                  ? video
                  : tokens.ink,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: overlay
                    ? onOverlay
                    : selected
                    ? video
                    : tokens.ink,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Back or forward 15 seconds: a glass circle with the amount under the icon.
class PlayerSkip extends StatelessWidget {
  const PlayerSkip({
    super.key,
    required this.icon,
    required this.label,
    required this.tokens,
    required this.onTap,
    this.overlay = false,
    this.size = 52,
  });

  final IconData icon;
  final String label;
  final MomentTokens tokens;
  final VoidCallback onTap;
  final bool overlay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = overlay ? onOverlay : tokens.ink;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: color),
        Text(
          '15',
          style: TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: overlay
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: overlayFilm,
                    border: Border.all(color: onOverlay.withValues(alpha: 0.3)),
                  ),
                  child: content,
                )
              : GlassSurface(
                  variant: GlassVariant.card,
                  borderRadius: size / 2,
                  child: content,
                ),
        ),
      ),
    );
  }
}

/// The big ink button: Play, Pause, or Replay once the clip has ended.
class PlayerPlayButton extends StatelessWidget {
  const PlayerPlayButton({
    super.key,
    required this.playing,
    required this.ended,
    required this.tokens,
    required this.onTap,
    this.size = 80,
  });

  final bool playing;
  final bool ended;
  final MomentTokens tokens;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = playing ? 'Pause' : (ended ? 'Replay' : 'Play');
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: tokens.ink, shape: BoxShape.circle),
          child: Icon(
            playing ? Icons.pause : (ended ? Icons.replay : Icons.play_arrow),
            color: tokens.onInk,
            size: size * 0.42,
          ),
        ),
      ),
    );
  }
}
