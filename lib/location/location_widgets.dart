import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import 'coordinates.dart';
import 'location_provider.dart';

/// What to tell the user when the device's position cannot be read.
String locationAccessMessage(LocationAccess access) => switch (access) {
  LocationAccess.granted => '',
  LocationAccess.denied =>
    'Moment uses your location only to pin this spot. '
        'It stays on this device.',
  LocationAccess.deniedForever =>
    'Location access is turned off for Moment. Turn it on in '
        'Settings, or enter coordinates instead.',
  LocationAccess.serviceOff =>
    'Location is turned off on this device. Turn it on, or enter '
        'coordinates instead.',
};

/// A pill-shaped button: dark and filled when [primary], glass otherwise.
class LocationPillButton extends StatelessWidget {
  const LocationPillButton({
    super.key,
    required this.label,
    required this.tokens,
    required this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final MomentTokens tokens;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : tokens.ink;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: primary
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.ink,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Center(child: content),
              )
            : GlassSurface(
                variant: GlassVariant.card,
                borderRadius: 26,
                child: Center(child: content),
              ),
      ),
    );
  }
}

/// A field for typing "latitude, longitude", with Cancel and Use buttons.
/// Calls [onUse] only with a pair that names a place on Earth.
class CoordinatesEntry extends StatefulWidget {
  const CoordinatesEntry({
    super.key,
    required this.tokens,
    required this.onUse,
    required this.onCancel,
  });

  final MomentTokens tokens;
  final void Function(double latitude, double longitude) onUse;
  final VoidCallback onCancel;

  @override
  State<CoordinatesEntry> createState() => _CoordinatesEntryState();
}

class _CoordinatesEntryState extends State<CoordinatesEntry> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _use() {
    final parsed = parseCoordinates(_controller.text);
    if (parsed == null) {
      setState(() => _invalid = true);
      return;
    }
    widget.onUse(parsed.$1, parsed.$2);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassSurface(
          variant: GlassVariant.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              key: const ValueKey('coordinates-field'),
              controller: _controller,
              keyboardType: TextInputType.text,
              autocorrect: false,
              onSubmitted: (_) => _use(),
              style: TextStyle(fontSize: 15, color: tokens.ink),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Latitude, longitude',
                hintStyle: TextStyle(color: tokens.secondary),
              ),
            ),
          ),
        ),
        if (_invalid) ...[
          const SizedBox(height: 8),
          Text(
            'Enter a latitude and longitude, like 12.9716, 77.5946',
            style: TextStyle(fontSize: 13.5, color: tokens.danger),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LocationPillButton(
                label: 'Cancel',
                tokens: tokens,
                onTap: widget.onCancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: LocationPillButton(
                label: 'Use these coordinates',
                tokens: tokens,
                primary: true,
                onTap: _use,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The small rounded label used for accuracy and "stored on this device".
class LocationPill extends StatelessWidget {
  const LocationPill({
    super.key,
    required this.label,
    required this.tokens,
    this.icon,
  });

  final String label;
  final MomentTokens tokens;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: tokens.ink),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
