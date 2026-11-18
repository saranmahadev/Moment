import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../domain/log_type.dart';
import 'frame_strip_scrubber.dart';
import 'overlay_colours.dart';
import 'player_controls.dart';
import 'video_player_model.dart';
import 'video_playback_controller.dart';
import 'video_poster.dart' show formatClipLength;

const _hideAfter = Duration(seconds: 3);
const _jump = Duration(seconds: 10);

/// The video on the whole screen. Tap to show or hide the controls (they
/// fade after three seconds of playing), double-tap the left or right half
/// to jump 10 seconds, pinch to zoom. The page that opens it turns the
/// screen to suit the clip and puts it back (see [PlayerScreenControl]).
class FullscreenVideoPlayer extends StatefulWidget {
  const FullscreenVideoPlayer({
    super.key,
    required this.model,
    required this.playback,
    required this.title,
    required this.subtitle,
    required this.frames,
    required this.onClose,
  });

  final VideoPlayerModel model;
  final VideoPlaybackController playback;
  final String title;
  final String subtitle;
  final List<File?> frames;
  final VoidCallback onClose;

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  bool _controls = true;
  Timer? _hideTimer;
  Timer? _badgeTimer;
  int _badgeSide = 0; // -1 left, 1 right, 0 none
  Offset _lastTap = Offset.zero;

  VideoPlayerModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModel);
    _scheduleHide();
  }

  @override
  void dispose() {
    _model.removeListener(_onModel);
    _hideTimer?.cancel();
    _badgeTimer?.cancel();
    super.dispose();
  }

  void _onModel() {
    if (!mounted) return;
    setState(() {});
    // Paused: the controls stay. Playing: they go after a quiet spell.
    if (_model.playing && _controls && _hideTimer == null) _scheduleHide();
    if (!_model.playing) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (!_controls) setState(() => _controls = true);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_model.playing) return;
    _hideTimer = Timer(_hideAfter, () {
      _hideTimer = null;
      if (mounted && _model.playing) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  void _doubleTap(double width) {
    final side = _lastTap.dx < width / 2 ? -1 : 1;
    unawaited(_model.skip(_jump * side));
    _badgeTimer?.cancel();
    setState(() => _badgeSide = side);
    _badgeTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _badgeSide = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: videoBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(child: widget.playback.buildView()),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              onDoubleTapDown: (d) => _lastTap = d.localPosition,
              onDoubleTap: () => _doubleTap(width),
            ),
          ),
          if (_badgeSide != 0)
            Positioned(
              top: 0,
              bottom: 0,
              left: _badgeSide < 0 ? 0 : null,
              right: _badgeSide > 0 ? 0 : null,
              width: width / 2,
              child: IgnorePointer(child: _SkipBadge(side: _badgeSide)),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _controls
                ? _Controls(
                    key: const ValueKey('controls'),
                    model: _model,
                    tokens: tokens,
                    title: widget.title,
                    subtitle: widget.subtitle,
                    frames: widget.frames,
                    onClose: widget.onClose,
                    onActivity: _scheduleHide,
                  )
                : const SizedBox.expand(key: ValueKey('no-controls')),
          ),
          if (!_controls)
            Positioned(
              left: 20,
              bottom: 18,
              child: IgnorePointer(
                child: _TimeChip(
                  text:
                      '${formatClipLength(_model.position)} / '
                      '${formatClipLength(_model.duration)}',
                ),
              ),
            ),
          if (!_controls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: LinearProgressIndicator(
                  value: _model.fraction,
                  minHeight: 3,
                  backgroundColor: onOverlay.withValues(alpha: 0.2),
                  color: tokens.colorFor(LogType.video),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: overlayFilm,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: onOverlay,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _SkipBadge extends StatelessWidget {
  const _SkipBadge({required this.side});

  final int side;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onOverlay.withValues(alpha: 0.16),
        border: Border.all(color: onOverlay.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            side < 0 ? Icons.fast_rewind : Icons.fast_forward,
            color: onOverlay,
            size: 30,
          ),
          const Text(
            '10 s',
            style: TextStyle(
              color: onOverlay,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    super.key,
    required this.model,
    required this.tokens,
    required this.title,
    required this.subtitle,
    required this.frames,
    required this.onClose,
    required this.onActivity,
  });

  final VideoPlayerModel model;
  final MomentTokens tokens;
  final String title;
  final String subtitle;
  final List<File?> frames;
  final VoidCallback onClose;
  final VoidCallback onActivity;

  VoidCallback _then(Future<void> Function() action) => () {
    onActivity();
    unawaited(action());
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shade behind the controls so they read on bright footage.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 110,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [overlayFilm, overlayFilm.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 190,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [overlayFilm, overlayFilm.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(
              children: [
                Row(
                  spacing: 10,
                  children: [
                    PlayerChip(
                      label: 'Exit fullscreen',
                      tokens: tokens,
                      overlay: true,
                      onTap: onClose,
                      child: const Icon(Icons.chevron_left, size: 24),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                              color: onOverlay,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: onOverlay.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PlayerChip(
                      label: model.muted ? 'Unmute' : 'Mute',
                      tokens: tokens,
                      overlay: true,
                      onTap: _then(model.toggleMute),
                      child: Icon(
                        model.muted ? Icons.volume_off : Icons.volume_up,
                      ),
                    ),
                    PlayerChip(
                      label: model.loop ? 'Loop on' : 'Loop off',
                      tokens: tokens,
                      overlay: true,
                      onTap: _then(model.toggleLoop),
                      child: Icon(
                        Icons.repeat,
                        color: model.loop
                            ? tokens.colorFor(LogType.video)
                            : null,
                      ),
                    ),
                    PlayerChip(
                      label: 'Speed ${model.speed} times',
                      tokens: tokens,
                      overlay: true,
                      onTap: _then(model.nextSpeed),
                      child: Text(speedLabel(model.speed)),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 44,
                  children: [
                    PlayerSkip(
                      icon: Icons.replay,
                      label: 'Back 15 seconds',
                      tokens: tokens,
                      overlay: true,
                      size: 56,
                      onTap: _then(
                        () => model.skip(const Duration(seconds: -15)),
                      ),
                    ),
                    PlayerPlayButton(
                      playing: model.playing,
                      ended: model.ended,
                      tokens: tokens,
                      size: 88,
                      onTap: _then(model.togglePlay),
                    ),
                    PlayerSkip(
                      icon: Icons.refresh,
                      label: 'Forward 15 seconds',
                      tokens: tokens,
                      overlay: true,
                      size: 56,
                      onTap: _then(
                        () => model.skip(const Duration(seconds: 15)),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  spacing: 14,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        formatClipLength(model.position),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: onOverlay,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: FrameStripScrubber(
                        frames: frames,
                        duration: model.duration,
                        position: model.position,
                        height: 40,
                        onLight: true,
                        onSeekFraction: (f) {
                          onActivity();
                          unawaited(model.seekToFraction(f));
                        },
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        formatClipLength(model.duration),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: onOverlay.withValues(alpha: 0.85),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    PlayerChip(
                      label: 'Exit fullscreen',
                      tokens: tokens,
                      overlay: true,
                      onTap: onClose,
                      child: const Icon(Icons.fullscreen_exit),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
