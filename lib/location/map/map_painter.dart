import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../domain/log_type.dart';
import 'map_tile.dart';
import 'map_window.dart';

/// Draws a [MapScene] in Moment's own colours, from the theme's tokens, so
/// it follows light, dark and Reduce Transparency with everything else. The
/// pin is the app's mark: an ink dot in a pane of glass with a green halo.
class MapPainter extends CustomPainter {
  MapPainter({
    required this.scene,
    required this.window,
    required this.tokens,
    this.pinSize = 48,
    this.showPin = true,
  });

  final MapScene scene;
  final MapWindow window;
  final MomentTokens tokens;
  final double pinSize;
  final bool showPin;

  Color get _blue => tokens.colorFor(LogType.text);
  Color get _green => tokens.colorFor(LogType.location);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final water = Color.alphaBlend(
      _blue.withValues(alpha: 0.16),
      tokens.ground,
    );
    canvas.drawRect(Offset.zero & size, Paint()..color = water);

    Offset at(Offset p) => window.project(p.dx, p.dy, size);
    Path ring(List<Offset> points) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final o = at(points[i]);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      return path..close();
    }

    Path polygon(MapPolygon p) {
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final r in p.rings) {
        path.addPath(ring(r), Offset.zero);
      }
      return path;
    }

    Path line(MapLine l) {
      final path = Path();
      for (var i = 0; i < l.points.length; i++) {
        final o = at(l.points[i]);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      return path;
    }

    final fill = Paint()..style = PaintingStyle.fill;
    for (final p in scene.land) {
      canvas.drawPath(polygon(p), fill..color = tokens.solidSurface);
    }
    for (final p in scene.lakes) {
      canvas.drawPath(polygon(p), fill..color = water);
    }
    for (final p in scene.urban) {
      final path = polygon(p);
      canvas.drawPath(path, fill..color = _green.withValues(alpha: 0.22));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = _green.withValues(alpha: 0.35),
      );
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final l in scene.states) {
      canvas.drawPath(
        _dashed(line(l), 4, 3),
        stroke
          ..strokeWidth = 1
          ..color = tokens.ink.withValues(alpha: 0.22),
      );
    }
    for (final l in scene.rivers) {
      canvas.drawPath(
        line(l),
        stroke
          ..strokeWidth = 1.6
          ..color = _blue.withValues(alpha: 0.45),
      );
    }
    for (final l in scene.rail) {
      canvas.drawPath(
        _dashed(line(l), 3, 2),
        stroke
          ..strokeWidth = 0.9
          ..color = tokens.ink.withValues(alpha: 0.30),
      );
    }
    for (final r in scene.roads) {
      canvas.drawPath(
        line(r),
        stroke
          ..strokeWidth = r.major ? 1.6 : 1.1
          ..color = tokens.ink.withValues(alpha: r.major ? 0.55 : 0.38),
      );
    }

    final pin = window.project(window.longitude, window.latitude, size);
    final taken = <Rect>[Rect.fromCircle(center: pin, radius: pinSize * 0.5)];
    _labels(canvas, size, taken);

    if (showPin) {
      final k = pinSize / 48;
      canvas.drawCircle(
        pin,
        22 * k,
        Paint()..color = _green.withValues(alpha: 0.20),
      );
      canvas.drawCircle(pin, 11 * k, Paint()..color = tokens.solidSurface);
      canvas.drawCircle(
        pin,
        11 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _green,
      );
      canvas.drawCircle(pin, 4.5 * k, Paint()..color = tokens.ink);
    }
  }

  /// Place names, most important first, skipping any that would overlap one
  /// already drawn or the pin.
  void _labels(Canvas canvas, Size size, List<Rect> taken) {
    final limit = switch (window.zoom) {
      MapZoom.region => 5,
      MapZoom.area => 8,
      MapZoom.city => 10,
    };
    final places = scene.places.where((p) => p.rank <= limit).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    for (final place in places) {
      final o = window.project(place.longitude, place.latitude, size);
      final text = TextPainter(
        text: TextSpan(
          text: place.name,
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontStyle: FontStyle.italic,
            fontSize: 11,
            color: tokens.secondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Rect.fromLTWH(
        o.dx + 5,
        o.dy - text.height / 2,
        text.width,
        text.height,
      );
      if (!(Offset.zero & size).contains(box.topLeft) ||
          !(Offset.zero & size).contains(box.bottomRight) ||
          taken.any((t) => t.overlaps(box.inflate(2)))) {
        continue;
      }
      canvas.drawCircle(o, 2.2, Paint()..color = tokens.secondary);
      text.paint(canvas, box.topLeft);
      taken
        ..add(box)
        ..add(Rect.fromCircle(center: o, radius: 3));
    }
  }

  Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        out.addPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          Offset.zero,
        );
        d += dash + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(MapPainter old) =>
      old.scene != scene ||
      old.tokens != tokens ||
      old.pinSize != pinSize ||
      old.showPin != showPin ||
      old.window.latitude != window.latitude ||
      old.window.longitude != window.longitude ||
      old.window.zoom != window.zoom ||
      old.window.aspect != window.aspect ||
      old.window.pinAt != window.pinAt;
}
