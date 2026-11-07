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

final _dateTimeFormat = DateFormat('EEEE d MMMM');

const _skipAmount = Duration(seconds: 15);

String _formatPosition(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}

/// A single audio log, full screen: playback with scrubbing, skip ±15s,
/// and an editable title and note. Matches
/// design/mockups/png/21-Detail-Audio.png.
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
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  late final _titleController = TextEditingController(text: _log.title ?? '');
  late final _noteController = TextEditingController(text: _log.note ?? '');

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
    _titleController.dispose();
    _noteController.dispose();
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
        : (target > _log.duration ? _log.duration : target);
    await widget.playback.seek(clamped);
  }

  Future<void> _seekToFraction(double fraction) async {
    final micros = (_log.duration.inMicroseconds * fraction).round();
    await widget.playback.seek(Duration(microseconds: micros));
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
    final note = _noteController.text.trim();
    await widget.repository.updateAudio(
      _log.id,
      title: title.isEmpty ? null : title,
      note: note.isEmpty ? null : note,
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
    final color = tokens.colorFor(LogType.audio);
    final fraction = _log.duration.inMicroseconds == 0
        ? 0.0
        : (_position.inMicroseconds / _log.duration.inMicroseconds).clamp(
            0.0,
            1.0,
          );

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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tokens.tintFor(LogType.audio),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          momentIconFor(LogType.audio),
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _dateTimeFormat.format(_log.localMoment),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: tokens.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _editing
                      ? TextField(
                          controller: _titleController,
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 28,
                            color: tokens.ink,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Voice note',
                            hintStyle: TextStyle(color: tokens.secondary),
                          ),
                        )
                      : Text(
                          _log.title ?? 'Audio',
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 28,
                            color: tokens.ink,
                          ),
                        ),
                  const SizedBox(height: 16),
                  _Waveform(
                    peaks: _log.peaks,
                    color: color,
                    tokens: tokens,
                    fraction: fraction,
                    onSeekFraction: _seekToFraction,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatPosition(_position),
                        style: TextStyle(fontSize: 13, color: tokens.ink),
                      ),
                      const Spacer(),
                      Text(
                        _formatPosition(_log.duration),
                        style: TextStyle(fontSize: 13, color: tokens.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SkipButton(
                        icon: Icons.replay_outlined,
                        label: 'Back 15 seconds',
                        tokens: tokens,
                        onTap: () => _skip(-_skipAmount),
                      ),
                      const SizedBox(width: 24),
                      _PlayPauseButton(
                        playing: _playing,
                        tokens: tokens,
                        onTap: _togglePlay,
                      ),
                      const SizedBox(width: 24),
                      _SkipButton(
                        icon: Icons.forward_outlined,
                        label: 'Forward 15 seconds',
                        tokens: tokens,
                        onTap: () => _skip(_skipAmount),
                      ),
                    ],
                  ),
                  if (_editing || _log.note != null) ...[
                    const SizedBox(height: 24),
                    GlassSurface(
                      variant: GlassVariant.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _editing
                            ? TextField(
                                controller: _noteController,
                                maxLines: null,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: tokens.ink,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Add a note',
                                  hintStyle: TextStyle(color: tokens.secondary),
                                ),
                              )
                            : Text(
                                _log.note!,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: tokens.ink,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.peaks,
    required this.color,
    required this.tokens,
    required this.fraction,
    required this.onSeekFraction,
  });

  final List<double> peaks;
  final Color color;
  final MomentTokens tokens;
  final double fraction;
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      variant: GlassVariant.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapUp: (details) {
                if (constraints.maxWidth <= 0) return;
                final tapped = (details.localPosition.dx / constraints.maxWidth)
                    .clamp(0.0, 1.0);
                onSeekFraction(tapped);
              },
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: peaks.isEmpty
                    ? null
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < peaks.length; i++)
                            Container(
                              width: 3,
                              height: 8 + peaks[i] * 48,
                              decoration: BoxDecoration(
                                color: (i / peaks.length) <= fraction
                                    ? color
                                    : tokens.ink.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
              ),
            );
          },
        ),
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
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: GlassSurface(
                variant: GlassVariant.card,
                borderRadius: 24,
                child: Icon(icon, size: 20, color: tokens.ink),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '15 s',
              style: TextStyle(fontSize: 12, color: tokens.secondary),
            ),
          ],
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
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: tokens.ink, shape: BoxShape.circle),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
