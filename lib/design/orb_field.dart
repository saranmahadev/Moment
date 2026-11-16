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
          final pair = gradients[i % gradients.length];
          orbs.add(
            Positioned(
              top: y,
              left: onLeft ? -70 : null,
              right: onLeft ? null : -60,
              // Transparency lives in the colours: an Opacity widget would
              // paint each orb into its own offscreen layer.
              // A little larger than the mockup's 240, since the outer part
              // now fades away.
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Soft at the edge. Cards used to blur the orbs behind
                  // them live, which made scrolling stutter; an orb that
                  // fades out by itself gives the same calm look for free.
                  gradient: RadialGradient(
                    colors: [
                      pair.first.withValues(alpha: tokens.orbOpacity),
                      pair.last.withValues(alpha: tokens.orbOpacity * 0.85),
                      pair.last.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.6, 1],
                  ),
                ),
              ),
            ),
          );
          i++;
          y += 380;
        }
        // Its own layer: the orbs never change, so content scrolling over
        // them does not make them repaint.
        return IgnorePointer(
          child: RepaintBoundary(child: Stack(children: orbs)),
        );
      },
    );
  }
}
