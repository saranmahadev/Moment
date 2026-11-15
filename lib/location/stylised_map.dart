import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../domain/log_type.dart';

/// The offline map tile from the mockups: a soft green-to-blue wash with a
/// white grid, and pins at fractional positions (0 to 1 across and down,
/// the pin's tip on the spot). No map tiles are ever fetched.
class StylisedMap extends StatelessWidget {
  const StylisedMap({
    super.key,
    required this.pins,
    this.showHalo = false,
    this.pinSize = 40,
  });

  final List<Offset> pins;

  /// Draws the accuracy halo around the first pin, as on the New Location
  /// screen.
  final bool showHalo;
  final double pinSize;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.location);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        const haloSize = 120.0;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFCDEBD3), Color(0xFFBFE0EC)],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            if (showHalo && pins.isNotEmpty)
              Positioned(
                key: const ValueKey('map-halo'),
                left: pins.first.dx * width - haloSize / 2,
                top: pins.first.dy * height - haloSize / 2,
                width: haloSize,
                height: haloSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.16),
                    border: Border.all(color: color.withValues(alpha: 0.45)),
                  ),
                ),
              ),
            for (final pin in pins)
              Positioned(
                left: pin.dx * width - pinSize / 2,
                top: pin.dy * height - pinSize,
                child: Icon(
                  Icons.location_on_outlined,
                  size: pinSize,
                  color: color,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  static const _cell = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var x = _cell; x < size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = _cell; y < size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
