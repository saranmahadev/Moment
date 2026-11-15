import 'dart:io';

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../domain/log_type.dart';

/// "0:48", "1:05": a video's or clip's length as shown on tiles and pills.
String formatClipLength(Duration d) =>
    '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

/// A video's still frame filling its box, with a soft tint in the Video
/// colour wherever the image is missing or cannot be decoded.
class VideoPoster extends StatelessWidget {
  const VideoPoster({super.key, required this.path, required this.tokens});

  /// Null when there is no still frame yet.
  final String? path;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.tintFor(LogType.video),
            tokens.colorFor(LogType.video).withValues(alpha: 0.35),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        if (path != null)
          Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// The round play mark laid over a poster.
class PlayBadge extends StatelessWidget {
  const PlayBadge({super.key, required this.tokens, this.size = 44});

  final MomentTokens tokens;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.play_arrow, color: tokens.ink, size: size * 0.55),
    );
  }
}

/// The small length pill laid over a poster's corner.
class ClipLengthPill extends StatelessWidget {
  const ClipLengthPill({
    super.key,
    required this.duration,
    required this.tokens,
  });

  final Duration duration;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        formatClipLength(duration),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: tokens.ink,
        ),
      ),
    );
  }
}
