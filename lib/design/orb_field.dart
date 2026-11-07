import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The soft, decorative gradient circles behind every screen, repeating
/// every 380 logical pixels of height and alternating sides, exactly as
/// `shell()` in design/generators/lib.py lays them out.
///
/// Each orb drifts and squishes gently and continuously, at its own slow
/// speed and phase, unless the device has the "reduce motion" accessibility
/// setting on (`MediaQuery.disableAnimations`), in which case they hold
/// still at their base position and shape.
class OrbField extends StatefulWidget {
  const OrbField({super.key});

  @override
  State<OrbField> createState() => _OrbFieldState();
}

class _OrbFieldState extends State<OrbField>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(seconds: 14);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _animating) {
      _animating = false;
      _controller.stop();
    } else if (!reduceMotion && !_animating) {
      _animating = true;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

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
              child: _Orb(
                index: i,
                controller: _controller,
                reduceMotion: reduceMotion,
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

class _Orb extends StatelessWidget {
  const _Orb({
    required this.index,
    required this.controller,
    required this.reduceMotion,
  });

  static const _gradients = [
    [Color(0xFFB7C3FF), Color(0xFF8B93F5)],
    [Color(0xFFFFD3BF), Color(0xFFFFAE9A)],
    [Color(0xFFBFEFDD), Color(0xFF8ADBC2)],
  ];

  final int index;
  final AnimationController controller;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final circle = Opacity(
      opacity: 0.8,
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradients[index % _gradients.length],
          ),
        ),
      ),
    );

    if (reduceMotion) return circle;

    return AnimatedBuilder(
      animation: controller,
      child: circle,
      builder: (context, child) {
        // Each orb drifts and squishes at its own speed and phase, out of
        // step with the others, so the whole field feels organic rather
        // than mechanically synchronised.
        final t = controller.value * 2 * math.pi;
        final driftPhase = t * (1 + index * 0.37);
        final dx = math.sin(driftPhase) * 16;
        final dy = math.sin(driftPhase * 0.8 + 1.1) * 12;
        final squish = math.sin(t * (1.3 + index * 0.21)) * 0.06;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scaleX: 1 + squish,
            scaleY: 1 - squish,
            child: child,
          ),
        );
      },
    );
  }
}
