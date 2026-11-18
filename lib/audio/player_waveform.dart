import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../domain/log_type.dart';

const _barCount = 56;

/// [peaks] (0 to 1, any length) as exactly [count] bars. A recording with no
/// peaks is a quiet flat line.
List<double> resamplePeaks(List<double> peaks, int count) {
  if (peaks.isEmpty) return List.filled(count, 0.08);
  double at(int i) => peaks[i.clamp(0, peaks.length - 1)].clamp(0.0, 1.0);
  return [
    for (var i = 0; i < count; i++)
      () {
        final position = peaks.length == 1
            ? 0.0
            : i * (peaks.length - 1) / (count - 1);
        final low = position.floor();
        final t = position - low;
        // A bar covers a stretch of the recording: take the loudest of the
        // peaks it spans, so a short loud sound is not smoothed away.
        final span = math.max(1, (peaks.length / count).ceil());
        var loudest = 0.0;
        for (var k = 0; k < span; k++) {
          loudest = math.max(
            loudest,
            at(low - span ~/ 2 + k) * (1 - t) + at(low - span ~/ 2 + k + 1) * t,
          );
        }
        return loudest.clamp(0.0, 1.0);
      }(),
  ];
}

String _clock(Duration d) =>
    '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

/// The player's waveform: fine rounded bars, played ones filled in the Audio
/// colour with a soft glow at the playhead, and the bars near it lifted.
/// Tap to jump; drag to scrub, with the time under the finger shown above it.
/// The seek happens when the finger lifts, so scrubbing never stutters the
/// audio. For screen readers it is one slider.
class PlayerWaveform extends StatefulWidget {
  const PlayerWaveform({
    super.key,
    required this.peaks,
    required this.duration,
    required this.position,
    required this.onSeekFraction,
    this.debugScrubbing = false,
  });

  final List<double> peaks;
  final Duration duration;
  final Duration position;
  final ValueChanged<double> onSeekFraction;

  /// Draws the dragging state at the current position, for goldens.
  final bool debugScrubbing;

  @override
  State<PlayerWaveform> createState() => _PlayerWaveformState();
}

class _PlayerWaveformState extends State<PlayerWaveform> {
  /// Where the finger is, as a fraction; null when not dragging.
  double? _scrub;

  double get _playing => widget.duration.inMicroseconds == 0
      ? 0
      : (widget.position.inMicroseconds / widget.duration.inMicroseconds).clamp(
          0.0,
          1.0,
        );

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  Duration _timeAt(double fraction) => Duration(
    microseconds: (widget.duration.inMicroseconds * fraction).round(),
  );

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final scrub = widget.debugScrubbing ? _playing : _scrub;
    final shown = scrub ?? _playing;
    final peaks = resamplePeaks(widget.peaks, _barCount);

    return Semantics(
      slider: true,
      label: 'Playback position',
      value: '${_clock(widget.position)} of ${_clock(widget.duration)}',
      increasedValue: _clock(widget.position + const Duration(seconds: 15)),
      decreasedValue: _clock(
        widget.position > const Duration(seconds: 15)
            ? widget.position - const Duration(seconds: 15)
            : Duration.zero,
      ),
      onIncrease: () => widget.onSeekFraction(
        (_playing + 15 / math.max(1, widget.duration.inSeconds)).clamp(
          0.0,
          1.0,
        ),
      ),
      onDecrease: () => widget.onSeekFraction(
        (_playing - 15 / math.max(1, widget.duration.inSeconds)).clamp(
          0.0,
          1.0,
        ),
      ),
      excludeSemantics: true,
      // No LayoutBuilder: the screen sizes itself from this widget's
      // intrinsic height. The width is read from the render box on touch.
      child: Builder(
        builder: (context) {
          double widthOf() =>
              (context.findRenderObject() as RenderBox).size.width;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => widget.onSeekFraction(
              _fractionAt(d.localPosition.dx, widthOf()),
            ),
            onHorizontalDragStart: (d) => setState(
              () => _scrub = _fractionAt(d.localPosition.dx, widthOf()),
            ),
            onHorizontalDragUpdate: (d) => setState(
              () => _scrub = _fractionAt(d.localPosition.dx, widthOf()),
            ),
            onHorizontalDragEnd: (_) {
              final target = _scrub;
              setState(() => _scrub = null);
              if (target != null) widget.onSeekFraction(target);
            },
            onHorizontalDragCancel: () => setState(() => _scrub = null),
            child: SizedBox(
              height: 136,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 92,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _WavePainter(
                          bars: peaks,
                          fraction: shown,
                          color: tokens.colorFor(LogType.audio),
                          unplayed: tokens.ink.withValues(alpha: 0.2),
                          lift: scrub == null ? 0.35 : 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (scrub != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Align(
                        // Slides from the left edge to the right edge with
                        // the finger, so it stays inside the card.
                        alignment: Alignment(scrub * 2 - 1, -1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.ink,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _clock(_timeAt(scrub)),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.onInk,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.bars,
    required this.fraction,
    required this.color,
    required this.unplayed,
    required this.lift,
  });

  final List<double> bars;
  final double fraction;
  final Color color;
  final Color unplayed;
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    final playhead = fraction * (n - 1);
    final slot = size.width / n;
    final barWidth = math.min(3.4, slot * 0.62);
    final centre = size.height / 2;

    for (var i = 0; i < n; i++) {
      final near = 1 + lift * math.exp(-math.pow(i - playhead, 2) / 7);
      final height = ((8 + 56 * bars[i]) * near).clamp(8.0, size.height);
      final x = slot * (i + 0.5);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, centre),
          width: barWidth,
          height: height,
        ),
        const Radius.circular(2),
      );
      final played = i <= playhead.round();
      if (played && i == playhead.round()) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = color.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
      canvas.drawRRect(rect, Paint()..color = played ? color : unplayed);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.unplayed != unplayed ||
      old.lift != lift ||
      old.bars != bars;
}
