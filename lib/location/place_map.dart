import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import 'map/map_painter.dart';
import 'map/map_source.dart';
import 'map/map_tile.dart';
import 'map/map_window.dart';

/// A preview of the place a log was made: bundled Natural Earth data drawn
/// in the app's own colours (see [MapPainter]), with the pin on it. Nothing
/// is fetched. The data has no streets, so [MapZoom.city] (about 60 km
/// across) is as close as it goes, and the span is always shown.
class PlaceMap extends StatefulWidget {
  const PlaceMap({
    super.key,
    required this.source,
    required this.latitude,
    required this.longitude,
    this.zoom = MapZoom.area,
    this.zoomable = false,
    this.pinAt = const Offset(0.5, 0.5),
    this.pinSize = 48,
  });

  final MapSource source;
  final double latitude;
  final double longitude;
  final MapZoom zoom;

  /// Shows the Region, Area and City buttons.
  final bool zoomable;
  final Offset pinAt;
  final double pinSize;

  @override
  State<PlaceMap> createState() => _PlaceMapState();
}

class _PlaceMapState extends State<PlaceMap> {
  late MapZoom _zoom = widget.zoom;
  MapScene _scene = MapScene.empty;
  String? _loadedFor;

  @override
  void didUpdateWidget(PlaceMap old) {
    super.didUpdateWidget(old);
    if (old.zoom != widget.zoom) _zoom = widget.zoom;
  }

  void _ensureLoaded(MapWindow window) {
    final key =
        '${window.tileKeys().toList()..sort()}|${widget.source.hashCode}';
    if (key == _loadedFor) return;
    _loadedFor = key;
    widget.source.load(window).then((scene) {
      if (!mounted || _loadedFor != key) return;
      setState(() => _scene = scene);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 340,
          constraints.hasBoundedHeight ? constraints.maxHeight : 260,
        );
        final window = MapWindow(
          latitude: widget.latitude,
          longitude: widget.longitude,
          zoom: _zoom,
          aspect: size.width / size.height,
          pinAt: widget.pinAt,
        );
        _ensureLoaded(window);
        final visible = _scene.within(window.bounds);

        return Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label:
                  'Map of the area around '
                  '${widget.latitude.toStringAsFixed(4)}, '
                  '${widget.longitude.toStringAsFixed(4)}, '
                  '${window.kmAcross} km across',
              container: true,
              image: true,
              excludeSemantics: true,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: MapPainter(
                    scene: visible,
                    window: window,
                    tokens: tokens,
                    pinSize: widget.pinSize,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: _Chip(
                tokens: tokens,
                child: Text(
                  '${window.kmAcross} km across',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
              ),
            ),
            if (widget.zoomable)
              Positioned(
                right: 8,
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final zoom in MapZoom.values)
                      _ZoomButton(
                        zoom: zoom,
                        selected: zoom == _zoom,
                        tokens: tokens,
                        onTap: () => setState(() => _zoom = zoom),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.tokens, required this.child});

  final MomentTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) => GlassSurface(
    variant: GlassVariant.card,
    borderRadius: 14,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: child,
    ),
  );
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.zoom,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final MapZoom zoom;
  final bool selected;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Zoom to ${zoom.label}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 62,
          height: 44,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? tokens.ink : tokens.solidSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tokens.ink.withValues(alpha: selected ? 0 : 0.12),
                ),
              ),
              child: Text(
                zoom.label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? tokens.onInk : tokens.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
