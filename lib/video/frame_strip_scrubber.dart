import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../domain/log_type.dart';
import 'overlay_colours.dart';

String _clock(Duration d) =>
    '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

/// The video player's scrubber: a strip of small frames along the clip, the
/// part already played clear and the rest dimmed, with a playhead. Tap to
/// jump. Drag to scrub: a preview of the nearest frame with its time floats
/// above the finger and [onScrubChanged] reports where it is (null when it
/// lifts), and the seek happens on release. One slider for screen readers.
class FrameStripScrubber extends StatefulWidget {
  const FrameStripScrubber({
    super.key,
    required this.frames,
    required this.duration,
    required this.position,
    required this.onSeekFraction,
    this.onScrubChanged,
    this.height = 48,
    this.onLight = false,
    this.debugScrubbing = false,
  });

  /// One entry per slice of the clip; null where the frame is not made yet.
  final List<File?> frames;
  final Duration duration;
  final Duration position;
  final ValueChanged<double> onSeekFraction;
  final ValueChanged<double?>? onScrubChanged;
  final double height;

  /// Over a picture (fullscreen) the strip uses white, not the theme's ink.
  final bool onLight;

  /// Draws the dragging state at the current position, for goldens.
  final bool debugScrubbing;

  @override
  State<FrameStripScrubber> createState() => _FrameStripScrubberState();
}

class _FrameStripScrubberState extends State<FrameStripScrubber> {
  double? _scrub;

  double get _playing => widget.duration.inMicroseconds == 0
      ? 0
      : (widget.position.inMicroseconds / widget.duration.inMicroseconds).clamp(
          0.0,
          1.0,
        );

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  void _setScrub(double? value) {
    setState(() => _scrub = value);
    widget.onScrubChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final scrub = widget.debugScrubbing ? _playing : _scrub;
    final shown = scrub ?? _playing;
    final frames = widget.frames;
    final dragging = scrub != null;
    final headColor = widget.onLight ? onOverlay : tokens.ink;
    final dark = tokens.ground.computeLuminance() < 0.5;
    final dim = (widget.onLight || dark ? overlayFilm : tokens.ground)
        .withValues(alpha: widget.onLight || dark ? 0.8 : 0.62);

    Widget frame(int i) {
      final file = i < frames.length ? frames[i] : null;
      return Expanded(
        child: file == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.colorFor(LogType.video).withValues(alpha: 0.4),
                      tokens.colorFor(LogType.video).withValues(alpha: 0.2),
                    ],
                  ),
                ),
              )
            : Image.file(
                file,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
      );
    }

    final slices = math.max(1, frames.length);
    final nearest = frames.isEmpty
        ? null
        // The slice of the clip the finger is over.
        : frames[(shown * frames.length).floor().clamp(0, frames.length - 1)];

    return Semantics(
      slider: true,
      label: 'Video position',
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
      // No LayoutBuilder: screens size themselves from intrinsic heights.
      child: Builder(
        builder: (context) {
          double widthOf() =>
              (context.findRenderObject() as RenderBox).size.width;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => widget.onSeekFraction(
              _fractionAt(d.localPosition.dx, widthOf()),
            ),
            onHorizontalDragStart: (d) =>
                _setScrub(_fractionAt(d.localPosition.dx, widthOf())),
            onHorizontalDragUpdate: (d) =>
                _setScrub(_fractionAt(d.localPosition.dx, widthOf())),
            onHorizontalDragEnd: (_) {
              final target = _scrub;
              _setScrub(null);
              if (target != null) widget.onSeekFraction(target);
            },
            onHorizontalDragCancel: () => _setScrub(null),
            child: SizedBox(
              height: widget.height + 100,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    height: widget.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Row(
                              spacing: 2,
                              children: [
                                for (var i = 0; i < slices; i++) frame(i),
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerRight,
                            widthFactor: 1 - shown,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(10),
                              ),
                              child: ColoredBox(color: dim),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment(shown * 2 - 1, 0),
                            child: FractionalTranslation(
                              translation: Offset(-shown, 0),
                              child: Container(
                                width: dragging ? 6 : 4,
                                height: widget.height + (dragging ? 20 : 12),
                                decoration: BoxDecoration(
                                  color: headColor,
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.ink.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dragging)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Align(
                        alignment: Alignment(scrub * 2 - 1, -1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (nearest != null)
                              Container(
                                width: 96,
                                height: 60,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: headColor,
                                    width: 2,
                                  ),
                                ),
                                child: Image(
                                  key: const ValueKey('scrub-preview'),
                                  image: FileImage(nearest),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.ink,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _clock(
                                  Duration(
                                    microseconds:
                                        (widget.duration.inMicroseconds * scrub)
                                            .round(),
                                  ),
                                ),
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
                          ],
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
