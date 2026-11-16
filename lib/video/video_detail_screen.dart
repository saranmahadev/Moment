import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../data/media_store.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'create_video_screen.dart';
import 'video_picker.dart';
import 'video_playback_controller.dart';
import 'video_poster.dart';
import 'video_probe.dart';

final _dateFormat = DateFormat('EEEE d MMMM');
final _timeFormat = DateFormat('HH:mm');

const _skipAmount = Duration(seconds: 15);

/// A single video log, full screen: the poster until it is played, then
/// the video, with a scrubber and 15-second skips. Matches
/// design/mockups/png/20-Detail-Video.png.
class VideoDetailScreen extends StatefulWidget {
  const VideoDetailScreen({
    super.key,
    required this.log,
    required this.repository,
    required this.mediaStore,
    required this.picker,
    required this.probe,
    required this.playback,
    DateTime Function()? now,
    this.onBack,
  }) : now = now ?? DateTime.now;

  final VideoLog log;
  final LogRepository repository;
  final MediaStore mediaStore;
  final VideoPicker picker;
  final VideoProbe probe;
  final VideoPlaybackController playback;
  final DateTime Function() now;
  final VoidCallback? onBack;

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _started = false;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;

  VideoLog get _log => widget.log;

  @override
  void initState() {
    super.initState();
    unawaited(widget.playback.load(_log.path));
    _positionSubscription = widget.playback.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _playingSubscription = widget.playback.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _playing = playing);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    widget.playback.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await widget.playback.pause();
    } else {
      setState(() => _started = true);
      await widget.playback.play();
    }
  }

  Duration _clamp(Duration target) => target < Duration.zero
      ? Duration.zero
      : (target > _log.duration ? _log.duration : target);

  Future<void> _skip(Duration delta) =>
      widget.playback.seek(_clamp(_position + delta));

  Future<void> _seekToFraction(double fraction) => widget.playback.seek(
    _clamp(
      Duration(microseconds: (_log.duration.inMicroseconds * fraction).round()),
    ),
  );

  Future<void> _delete() async {
    await widget.repository.softDelete(_log.id);
    widget.onBack?.call();
  }

  void _edit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateVideoScreen(
          repository: widget.repository,
          mediaStore: widget.mediaStore,
          picker: widget.picker,
          probe: widget.probe,
          now: widget.now,
          editing: _log,
          onSaved: (_) {
            Navigator.of(context).pop();
            widget.onBack?.call();
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.video);
    final total = _log.duration.inMicroseconds;
    final fraction = total == 0
        ? 0.0
        : (_position.inMicroseconds / total).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.chevron_left,
                        label: 'Back',
                        tokens: tokens,
                        onTap: widget.onBack,
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        tokens: tokens,
                        onTap: _edit,
                      ),
                      const SizedBox(width: 10),
                      _RoundIconButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        tokens: tokens,
                        onTap: _delete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tokens.tintFor(LogType.video),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          momentIconFor(LogType.video),
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${_dateFormat.format(_log.localMoment)} · '
                          '${_timeFormat.format(_log.localMoment)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: tokens.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_started)
                              ColoredBox(
                                color: Colors.black,
                                child: widget.playback.buildView(),
                              )
                            else
                              VideoPoster(
                                path: _log.posterPath,
                                tokens: tokens,
                              ),
                            if (!_playing)
                              Center(
                                child: PlayBadge(tokens: tokens, size: 64),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassSurface(
                    variant: GlassVariant.card,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                      child: Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: color,
                              inactiveTrackColor: tokens.ink.withValues(
                                alpha: 0.15,
                              ),
                              thumbColor: Colors.white,
                              trackHeight: 4,
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Slider(
                                value: fraction,
                                onChanged: _seekToFraction,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Text(
                                  formatClipLength(_position),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.ink,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formatClipLength(_log.duration),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _RoundControl(
                                icon: Icons.skip_previous_outlined,
                                label: 'Back 15 seconds',
                                tokens: tokens,
                                onTap: () => _skip(-_skipAmount),
                              ),
                              const SizedBox(width: 20),
                              _RoundControl(
                                icon: _playing
                                    ? Icons.pause
                                    : Icons.play_arrow_outlined,
                                label: _playing ? 'Pause' : 'Play',
                                tokens: tokens,
                                size: 64,
                                onTap: _togglePlay,
                              ),
                              const SizedBox(width: 20),
                              _RoundControl(
                                icon: Icons.skip_next_outlined,
                                label: 'Forward 15 seconds',
                                tokens: tokens,
                                onTap: () => _skip(_skipAmount),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassSurface(
                    variant: GlassVariant.card,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_log.caption != null) ...[
                            Text(
                              _log.caption!,
                              style: TextStyle(
                                fontFamily: 'Newsreader',
                                fontSize: 22,
                                color: tokens.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: tokens.ink,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Stored on this device',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: tokens.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.tokens,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final MomentTokens tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: GlassSurface(
            variant: GlassVariant.card,
            borderRadius: 22,
            child: Icon(icon, size: 20, color: tokens.ink),
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.tokens,
    required this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final String label;
  final MomentTokens tokens;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tokens.scrim.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: size * 0.45, color: tokens.ink),
        ),
      ),
    );
  }
}
