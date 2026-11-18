import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'audio_playback_controller.dart';
import 'player_waveform.dart';

final _dateTimeFormat = DateFormat('EEEE d MMMM · HH:mm');

const _skipAmount = Duration(seconds: 15);
const _speeds = [1.0, 1.25, 1.5, 2.0, 0.75];

String _speedLabel(double s) => '${s == s.roundToDouble() ? s.toInt() : s}×';

String _formatPosition(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}

/// A single audio log, full screen, as a small music player: artwork, a
/// waveform you can drag, play and pause, skip ±15s, loop and speed. The
/// title is editable; there is no text under the player because nothing is
/// transcribed. Matches the approved player design (light and dark).
class AudioDetailScreen extends StatefulWidget {
  const AudioDetailScreen({
    super.key,
    required this.log,
    required this.repository,
    required this.playback,
    DateTime Function()? now,
    this.onBack,
  }) : now = now ?? DateTime.now;

  final AudioLog log;
  final LogRepository repository;
  final AudioPlaybackController playback;
  final DateTime Function() now;
  final VoidCallback? onBack;

  @override
  State<AudioDetailScreen> createState() => _AudioDetailScreenState();
}

class _AudioDetailScreenState extends State<AudioDetailScreen> {
  late AudioLog _log = widget.log;
  bool _editing = false;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loop = false;
  int _speedIndex = 0;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  /// The length the player found in the file. The saved length is what the
  /// timer counted while recording, which can run a little long, and then
  /// the end of the clip would stop short of a full waveform.
  late Duration _duration = _log.duration;
  late final _titleController = TextEditingController(text: _log.title ?? '');

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
    _durationSubscription = widget.playback.durationStream.listen((d) {
      if (!mounted || d == null || d == Duration.zero) return;
      setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _durationSubscription?.cancel();
    _titleController.dispose();
    widget.playback.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await widget.playback.pause();
    } else {
      await widget.playback.play();
    }
  }

  Future<void> _skip(Duration delta) async {
    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    await widget.playback.seek(clamped);
  }

  Future<void> _seekToFraction(double fraction) async {
    final micros = (_duration.inMicroseconds * fraction).round();
    await widget.playback.seek(Duration(microseconds: micros));
  }

  Future<void> _toggleLoop() async {
    setState(() => _loop = !_loop);
    await widget.playback.setLoop(_loop);
  }

  Future<void> _nextSpeed() async {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);
    await widget.playback.setSpeed(_speeds[_speedIndex]);
  }

  Future<void> _delete() async {
    await widget.repository.softDelete(_log.id);
    widget.onBack?.call();
  }

  void _startEditing() {
    setState(() => _editing = true);
  }

  Future<void> _saveEdits() async {
    final title = _titleController.text.trim();
    await widget.repository.updateAudio(
      _log.id,
      title: title.isEmpty ? null : title,
      note: _log.note,
    );
    final updated = await widget.repository.getById(_log.id) as AudioLog;
    if (!mounted) return;
    setState(() {
      _log = updated;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final speed = _speeds[_speedIndex];

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
                            if (_editing)
                              _RoundIconButton(
                                icon: Icons.check,
                                label: 'Save',
                                tokens: tokens,
                                onTap: _saveEdits,
                              )
                            else
                              _RoundIconButton(
                                icon: Icons.edit_outlined,
                                label: 'Edit',
                                tokens: tokens,
                                onTap: _startEditing,
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
                            child: _Artwork(tokens: tokens),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _editing
                            ? TextField(
                                enableIMEPersonalizedLearning: false,
                                controller: _titleController,
                                style: TextStyle(
                                  fontFamily: 'Newsreader',
                                  fontSize: 32,
                                  height: 1.1,
                                  color: tokens.ink,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: 'Voice note',
                                  hintStyle: TextStyle(color: tokens.secondary),
                                ),
                              )
                            : Text(
                                _log.title ?? 'Audio',
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
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Column(
                              children: [
                                PlayerWaveform(
                                  peaks: _log.peaks,
                                  duration: _duration,
                                  position: _position,
                                  onSeekFraction: _seekToFraction,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      _formatPosition(_position),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.ink,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatPosition(_duration),
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
                            _ChipButton(
                              label: _loop ? 'Loop on' : 'Loop off',
                              selected: _loop,
                              tokens: tokens,
                              onTap: _toggleLoop,
                              child: Icon(
                                Icons.repeat,
                                size: 20,
                                color: _loop
                                    ? tokens.colorFor(LogType.audio)
                                    : tokens.ink,
                              ),
                            ),
                            _SkipButton(
                              icon: Icons.replay,
                              label: 'Back 15 seconds',
                              tokens: tokens,
                              onTap: () => _skip(-_skipAmount),
                            ),
                            _PlayPauseButton(
                              playing: _playing,
                              tokens: tokens,
                              onTap: _togglePlay,
                            ),
                            _SkipButton(
                              icon: Icons.refresh,
                              label: 'Forward 15 seconds',
                              tokens: tokens,
                              onTap: () => _skip(_skipAmount),
                            ),
                            _ChipButton(
                              label: 'Speed $speed times',
                              selected: speed != 1.0,
                              tokens: tokens,
                              onTap: _nextSpeed,
                              child: Text(
                                _speedLabel(speed),
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: speed != 1.0
                                      ? tokens.colorFor(LogType.audio)
                                      : tokens.ink,
                                ),
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

/// The artwork card: orbs in the Audio colour, rings and an ink dot, with
/// the type badge. It is the same for every recording.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.tokens});

  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final dark = tokens.ground.computeLuminance() < 0.5;
    final a = dark ? 0.30 : 0.50;
    final audio = tokens.colorFor(LogType.audio);
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              audio.withValues(alpha: a),
              tokens.colorFor(LogType.text).withValues(alpha: a * 0.45),
              tokens.colorFor(LogType.photo).withValues(alpha: a * 0.4),
            ],
          ),
          border: Border.all(color: tokens.ink.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            Center(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(300, 300),
                  painter: _RingsPainter(tokens: tokens),
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: GlassSurface(
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
                          color: tokens.tintFor(LogType.audio),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          momentIconFor(LogType.audio),
                          size: 15,
                          color: tokens.colorFor(LogType.audio),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Audio',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.colorFor(LogType.audio),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.tokens});

  final MomentTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final line = tokens.solidSurface;
    Paint ring(double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line.withValues(alpha: alpha);
    canvas.drawCircle(c, 150, ring(0.55));
    canvas.drawCircle(c, 108, ring(0.65));
    canvas.drawCircle(c, 68, Paint()..color = line.withValues(alpha: 0.55));
    canvas.drawCircle(c, 68, ring(0.9));
    canvas.drawCircle(c, 9, Paint()..color = tokens.ink);
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.tokens != tokens;
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

/// A 44 pt glass chip: Loop and Speed.
class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final MomentTokens tokens;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? tokens.tintFor(LogType.audio)
                : tokens.solidSurface.withValues(alpha: 0.6),
            border: Border.all(
              color: selected
                  ? tokens.colorFor(LogType.audio)
                  : tokens.ink.withValues(alpha: 0.12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final MomentTokens tokens;
  final VoidCallback onTap;

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
          width: 52,
          height: 52,
          child: GlassSurface(
            variant: GlassVariant.card,
            borderRadius: 26,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: tokens.ink),
                Text(
                  '15',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
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

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.playing,
    required this.tokens,
    required this.onTap,
  });

  final bool playing;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: tokens.ink, shape: BoxShape.circle),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: tokens.onInk,
            size: 34,
          ),
        ),
      ),
    );
  }
}
