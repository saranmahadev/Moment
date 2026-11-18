import 'dart:async';
import 'dart:io';

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
import 'frame_strip_scrubber.dart';
import 'fullscreen_video_player.dart';
import 'overlay_colours.dart';
import 'player_controls.dart';
import 'player_screen_control.dart';
import 'video_frames.dart';
import 'video_picker.dart';
import 'video_playback_controller.dart';
import 'video_player_model.dart';
import 'video_poster.dart';
import 'video_probe.dart';

final _dateTimeFormat = DateFormat('EEEE d MMMM · HH:mm');

const _skipAmount = Duration(seconds: 15);

/// A single video log, full screen, as a small video player: the picture
/// with mute and fullscreen on it, a strip of frames to scrub along, play,
/// 15-second skips, loop and speed. Matches the approved player design.
class VideoDetailScreen extends StatefulWidget {
  const VideoDetailScreen({
    super.key,
    required this.log,
    required this.repository,
    required this.mediaStore,
    required this.picker,
    required this.probe,
    required this.playback,
    this.frames,
    PlayerScreenControl? screen,
    DateTime Function()? now,
    this.onBack,
  }) : screen = screen ?? _NoScreenControl.instance,
       now = now ?? DateTime.now;

  final VideoLog log;
  final LogRepository repository;
  final MediaStore mediaStore;
  final VideoPicker picker;
  final VideoProbe probe;
  final VideoPlaybackController playback;

  /// Makes the frames for the scrubber; without it the strip is plain.
  final VideoFrameStrip? frames;

  /// Fullscreen and keeping the screen awake; does nothing without one.
  final PlayerScreenControl screen;
  final DateTime Function() now;
  final VoidCallback? onBack;

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _NoScreenControl implements PlayerScreenControl {
  const _NoScreenControl();
  static const instance = _NoScreenControl();

  @override
  Future<void> enterFullscreen({required bool landscape}) async {}

  @override
  Future<void> exitFullscreen() async {}

  @override
  Future<void> keepAwake(bool on) async {}
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late final VideoPlayerModel _model = VideoPlayerModel(
    playback: widget.playback,
    duration: widget.log.duration,
  );
  List<File?> _frames = const [];
  StreamSubscription<List<File?>>? _framesSubscription;
  double? _scrub;
  bool _wasPlaying = false;

  VideoLog get _log => widget.log;

  @override
  void initState() {
    super.initState();
    unawaited(widget.playback.load(_log.path));
    _model.addListener(_onModel);
    _framesSubscription = widget.frames?.framesFor(_log).listen((frames) {
      if (mounted) setState(() => _frames = frames);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _framesSubscription?.cancel();
    _model.removeListener(_onModel);
    _model.dispose();
    if (_wasPlaying) unawaited(widget.screen.keepAwake(false));
    widget.playback.dispose();
    super.dispose();
  }

  void _onModel() {
    if (!mounted) return;
    setState(() {});
    if (_model.playing != _wasPlaying) {
      _wasPlaying = _model.playing;
      unawaited(widget.screen.keepAwake(_wasPlaying));
    }
  }

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

  Future<void> _fullscreen() async {
    final navigator = Navigator.of(context);
    await widget.screen.enterFullscreen(
      landscape: widget.playback.aspectRatio >= 1,
    );
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenVideoPlayer(
          model: _model,
          playback: widget.playback,
          title: _log.caption ?? 'Video',
          subtitle: _dateTimeFormat.format(_log.localMoment),
          frames: _frames,
          onClose: () => navigator.pop(),
        ),
      ),
    );
    await widget.screen.exitFullscreen();
  }

  /// The frame under the finger while scrubbing, if it has been made.
  File? get _scrubFrame {
    final at = _scrub;
    if (at == null || _frames.isEmpty) return null;
    return _frames[(at * _frames.length).floor().clamp(0, _frames.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.video);
    final scrubFrame = _scrubFrame;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 36,
                  ),
                  child: IntrinsicHeight(
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
                        const SizedBox(height: 14),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 200),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Semantics(
                                    button: true,
                                    label: 'Video. Tap to play or pause',
                                    onTap: _model.togglePlay,
                                    excludeSemantics: true,
                                    child: GestureDetector(
                                      onTap: _model.togglePlay,
                                      child: ColoredBox(
                                        color: videoBlack,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            if (_model.started)
                                              widget.playback.buildView()
                                            else
                                              VideoPoster(
                                                path: _log.posterPath,
                                                tokens: tokens,
                                              ),
                                            if (scrubFrame != null)
                                              Image.file(
                                                scrubFrame,
                                                fit: BoxFit.cover,
                                                gaplessPlayback: true,
                                                errorBuilder: (_, _, _) =>
                                                    const SizedBox.shrink(),
                                              ),
                                            if (!_model.started &&
                                                !_model.playing)
                                              Center(
                                                child: PlayBadge(
                                                  tokens: tokens,
                                                  size: 64,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 14,
                                    top: 14,
                                    child: _TypeBadge(
                                      tokens: tokens,
                                      color: color,
                                    ),
                                  ),
                                  Positioned(
                                    right: 14,
                                    top: 14,
                                    child: PlayerChip(
                                      label: _model.muted ? 'Unmute' : 'Mute',
                                      tokens: tokens,
                                      overlay: true,
                                      onTap: _model.toggleMute,
                                      child: Icon(
                                        _model.muted
                                            ? Icons.volume_off
                                            : Icons.volume_up,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 14,
                                    bottom: 12,
                                    child: IgnorePointer(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: overlayFilm,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Text(
                                          '${formatClipLength(_model.position)}'
                                          ' / '
                                          '${formatClipLength(_log.duration)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: onOverlay,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 14,
                                    bottom: 6,
                                    child: PlayerChip(
                                      label: 'Fullscreen',
                                      tokens: tokens,
                                      overlay: true,
                                      onTap: _fullscreen,
                                      child: const Icon(Icons.fullscreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _log.caption ?? 'Video',
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontWeight: FontWeight.w500,
                            fontSize: 32,
                            height: 1.1,
                            letterSpacing: -0.3,
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateTimeFormat.format(_log.localMoment),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: tokens.secondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassSurface(
                          variant: GlassVariant.card,
                          borderRadius: 28,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: Column(
                              children: [
                                FrameStripScrubber(
                                  frames: _frames,
                                  duration: _log.duration,
                                  position: _model.position,
                                  onScrubChanged: (f) =>
                                      setState(() => _scrub = f),
                                  onSeekFraction: _model.seekToFraction,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      formatClipLength(_model.position),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.ink,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      formatClipLength(_log.duration),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PlayerChip(
                              label: _model.loop ? 'Loop on' : 'Loop off',
                              tokens: tokens,
                              selected: _model.loop,
                              onTap: _model.toggleLoop,
                              child: const Icon(Icons.repeat),
                            ),
                            PlayerSkip(
                              icon: Icons.replay,
                              label: 'Back 15 seconds',
                              tokens: tokens,
                              onTap: () => _model.skip(-_skipAmount),
                            ),
                            PlayerPlayButton(
                              playing: _model.playing,
                              ended: _model.ended,
                              tokens: tokens,
                              onTap: _model.togglePlay,
                            ),
                            PlayerSkip(
                              icon: Icons.refresh,
                              label: 'Forward 15 seconds',
                              tokens: tokens,
                              onTap: () => _model.skip(_skipAmount),
                            ),
                            PlayerChip(
                              label: 'Speed ${_model.speed} times',
                              tokens: tokens,
                              selected: _model.speed != 1.0,
                              onTap: _model.nextSpeed,
                              child: Text(
                                speedLabel(_model.speed),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.tokens, required this.color});

  final MomentTokens tokens;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassSurface(
    variant: GlassVariant.card,
    borderRadius: 20,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tokens.tintFor(LogType.video),
              shape: BoxShape.circle,
            ),
            child: Icon(momentIconFor(LogType.video), size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            'Video',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
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
      onTap: onTap,
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
