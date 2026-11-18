import 'package:flutter/material.dart';

import '../domain/log_type.dart';
import 'glass_surface.dart';
import 'tokens.dart';

/// New photo and New video before anything is chosen, after the mockup's
/// camera screen: a viewfinder frame in the type's colours, the library on
/// the left and a large shutter in the middle. Moment uses the phone's own
/// camera (no camera permission of its own), so the frame says the camera
/// opens rather than showing a live picture.
class CaptureFrame extends StatelessWidget {
  const CaptureFrame({
    super.key,
    required this.type,
    required this.captureLabel,
    required this.onCapture,
    required this.onChoose,
    this.message,
  });

  /// Shown in the frame instead of the hint, in the danger colour: what
  /// went wrong with the last pick.
  final String? message;

  final LogType type;

  /// "Take Photo" or "Record Video".
  final String captureLabel;
  final VoidCallback onCapture;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final marks = dark ? tokens.ink : tokens.solidSurface;
    final colour = tokens.colorFor(type);
    return Column(
      children: [
        Expanded(
          child: Container(
            key: const ValueKey('capture-frame'),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.tintFor(type),
                  colour.withValues(alpha: 0.28),
                  tokens.tintFor(LogType.text),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(painter: _CornerMarks(marks)),
                  ),
                ),
                Center(
                  child: message != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: tokens.danger,
                            ),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type == LogType.video
                                  ? Icons.videocam_outlined
                                  : Icons.photo_camera_outlined,
                              size: 30,
                              color: tokens.ink.withValues(alpha: 0.55),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Opens your camera',
                              style: TextStyle(
                                fontSize: 14,
                                color: tokens.ink.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Control(
                label: 'Choose from Library',
                onTap: onChoose,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 28,
                    child: Icon(
                      type == LogType.video
                          ? Icons.video_library_outlined
                          : Icons.photo_library_outlined,
                      color: tokens.ink,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _Control(
                label: captureLabel,
                onTap: onCapture,
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 41,
                    child: Center(
                      child: type == LogType.video
                          ? Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: tokens.danger,
                                borderRadius: BorderRadius.circular(9),
                              ),
                            )
                          : Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: tokens.ink,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

/// A round control with its caption under it, one button for a screen
/// reader.
class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(height: 82, child: Center(child: child)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: tokens.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The viewfinder's four corner marks.
class _CornerMarks extends CustomPainter {
  const _CornerMarks(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 28.0;
    const r = 10.0;
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * arm)
          ..lineTo(x, y + dy * r)
          ..quadraticBezierTo(x, y, x + dx * r, y)
          ..lineTo(x + dx * arm, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CornerMarks old) => old.colour != colour;
}
