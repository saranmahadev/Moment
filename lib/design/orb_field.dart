import 'package:flutter/material.dart';

/// The soft, decorative gradient circles behind every screen, repeating
/// every 380 logical pixels of height and alternating sides, exactly as
/// `shell()` in design/generators/lib.py lays them out.
class OrbField extends StatelessWidget {
  const OrbField({super.key});

  static const _gradients = [
    [Color(0xFFB7C3FF), Color(0xFF8B93F5)],
    [Color(0xFFFFD3BF), Color(0xFFFFAE9A)],
    [Color(0xFFBFEFDD), Color(0xFF8ADBC2)],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final orbs = <Widget>[];
        var i = 0;
        var y = 90.0;
        while (y < constraints.maxHeight) {
          final onLeft = i.isEven;
          orbs.add(
            Positioned(
              top: y,
              left: onLeft ? -70 : null,
              right: onLeft ? null : -60,
              child: Opacity(
                opacity: 0.8,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _gradients[i % _gradients.length],
                    ),
                  ),
                ),
              ),
            ),
          );
          i++;
          y += 380;
        }
        return IgnorePointer(child: Stack(children: orbs));
      },
    );
  }
}
