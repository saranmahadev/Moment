import 'package:flutter/material.dart';

import 'tokens.dart';

/// The soft, decorative gradient circles behind every screen, repeating
/// every 380 logical pixels of height and alternating sides, exactly as
/// `shell()` in design/generators/lib.py lays them out.
class OrbField extends StatelessWidget {
  const OrbField({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final gradients = tokens.orbs;
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
                opacity: tokens.orbOpacity,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradients[i % gradients.length],
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
