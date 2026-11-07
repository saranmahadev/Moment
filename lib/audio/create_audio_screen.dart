import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../data/media_store.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log_type.dart';
import 'audio_recorder_controller.dart';

String _formatElapsed(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// The New Audio screen: records a voice note with a live waveform, then
/// saves it with an optional title. Matches
/// design/mockups/png/09-Create-Audio.png.
class CreateAudioScreen extends StatefulWidget {
  const CreateAudioScreen({
    super.key,
    required this.repository,
    required this.mediaStore,
    required this.recorder,
    DateTime Function()? now,
    required this.onSaved,
    required this.onClose,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final MediaStore mediaStore;
  final AudioRecorderController recorder;
  final DateTime Function() now;
  final ValueChanged<String> onSaved;
  final VoidCallback onClose;

  @override
  State<CreateAudioScreen> createState() => _CreateAudioScreenState();
}

class _CreateAudioScreenState extends State<CreateAudioScreen> {
  final List<double> _peaks = [];
  Duration _elapsed = Duration.zero;
  bool _paused = false;
  bool _saving = false;
  StreamSubscription<double>? _subscription;
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subscription = widget.recorder.amplitudeStream.listen(_onAmplitude);
    unawaited(_startRecording());
  }

  Future<void> _startRecording() async {
    final granted = await widget.recorder.hasPermission();
    if (!granted) return;
    await widget.recorder.start();
  }

  void _onAmplitude(double value) {
    if (!mounted) return;
    setState(() {
      _peaks.add(value);
      _elapsed += audioSampleInterval;
    });
  }

  Future<void> _togglePause() async {
    if (_paused) {
      await widget.recorder.resume();
    } else {
      await widget.recorder.pause();
    }
    if (!mounted) return;
    setState(() => _paused = !_paused);
  }

  Future<void> _discard() async {
    await _subscription?.cancel();
    await widget.recorder.cancel();
    widget.onClose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    await _subscription?.cancel();
    final path = await widget.recorder.stop();
    if (path == null) {
      widget.onClose();
      return;
    }

    final imported = await widget.mediaStore.importAudio(File(path));
    final id = await widget.repository.createAudio(
      path: imported.path,
      duration: _elapsed,
      peaks: List.unmodifiable(_peaks),
      title: _titleNullable(),
      createdAt: widget.now(),
    );
    widget.onSaved(id);
  }

  String? _titleNullable() {
    final text = _titleController.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _titleController.dispose();
    widget.recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.audio);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Close without saving',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: _discard,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: GlassSurface(
                              variant: GlassVariant.card,
                              borderRadius: 22,
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: tokens.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 44,
                        child: GlassSurface(
                          variant: GlassVariant.card,
                          borderRadius: 22,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  momentIconFor(LogType.audio),
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Audio',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GlassSurface(
                    variant: GlassVariant.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: _titleController,
                        style: TextStyle(fontSize: 15, color: tokens.ink),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: tokens.secondary,
                          ),
                          hintText: 'Voice note',
                          hintStyle: TextStyle(color: tokens.secondary),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatElapsed(_elapsed),
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontWeight: FontWeight.w500,
                      fontSize: 52,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Waveform(peaks: _peaks, color: color),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        icon: Icons.delete_outline,
                        label: 'Discard',
                        tokens: tokens,
                        onTap: _discard,
                      ),
                      _PauseResumeButton(
                        paused: _paused,
                        tokens: tokens,
                        onTap: _togglePause,
                      ),
                      _RoundAction(
                        icon: Icons.check,
                        label: 'Save',
                        tokens: tokens,
                        iconColor: color,
                        onTap: _saving ? null : _save,
                      ),
                    ],
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

class _Waveform extends StatelessWidget {
  const _Waveform({required this.peaks, required this.color});

  final List<double> peaks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        reverse: true,
        scrollDirection: Axis.horizontal,
        itemCount: peaks.length,
        itemBuilder: (context, index) {
          final peak = peaks[peaks.length - 1 - index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 3,
              height: 8 + peak * 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.tokens,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final MomentTokens tokens;
  final Color? iconColor;
  final VoidCallback? onTap;

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
              width: 56,
              height: 56,
              child: GlassSurface(
                variant: GlassVariant.card,
                borderRadius: 28,
                child: Icon(icon, size: 22, color: iconColor ?? tokens.ink),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: tokens.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PauseResumeButton extends StatelessWidget {
  const _PauseResumeButton({
    required this.paused,
    required this.tokens,
    required this.onTap,
  });

  final bool paused;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = paused ? 'Resume' : 'Pause';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.ink,
                shape: BoxShape.circle,
              ),
              child: Icon(
                paused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: tokens.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
