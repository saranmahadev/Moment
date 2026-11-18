import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log_type.dart';
import 'coordinates.dart';
import 'location_provider.dart';
import 'location_widgets.dart';
import 'place_name_lookup.dart';
import 'map/map_source.dart';
import 'place_map.dart';
import 'stylised_map.dart';

final _whenFormat = DateFormat('EEE d MMM · HH:mm');

/// The New Location screen: pin where you are, or type coordinates, and
/// optionally name the place. Access is explained before the system is
/// asked, and every refused state says what to do instead. Matches
/// design/mockups/png/10-Create-Location.png.
///
/// [placeNames] is only given when "Look up place names" is on. Then each
/// new pin is looked up once and the name offered, never forced: a name
/// already typed is left alone. Without it nothing leaves the device.
class CreateLocationScreen extends StatefulWidget {
  const CreateLocationScreen({
    super.key,
    required this.repository,
    required this.provider,
    this.placeNames,
    this.mapSource,
    DateTime Function()? now,
    required this.onSaved,
    required this.onClose,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final LocationProvider provider;
  final PlaceNameLookup? placeNames;

  /// The bundled map to show the spot on. Without one, the plain tile.
  final MapSource? mapSource;
  final DateTime Function() now;
  final ValueChanged<String> onSaved;
  final VoidCallback onClose;

  @override
  State<CreateLocationScreen> createState() => _CreateLocationScreenState();
}

class _CreateLocationScreenState extends State<CreateLocationScreen> {
  /// Null until the first check comes back.
  LocationAccess? _access;

  /// The spot that Save would store: a measured fix, or typed coordinates
  /// (which carry no accuracy).
  LocationFix? _pin;
  bool _typed = false;
  bool _locating = false;
  bool _entering = false;
  bool _saving = false;
  final _nameController = TextEditingController();

  /// Where the online lookup for the current pin stands.
  _Lookup _lookup = _Lookup.none;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final access = await widget.provider.checkAccess();
    if (!mounted) return;
    setState(() => _access = access);
    if (access == LocationAccess.granted) await _locate();
  }

  Future<void> _allow() async {
    final access = await widget.provider.requestAccess();
    if (!mounted) return;
    setState(() => _access = access);
    if (access == LocationAccess.granted) await _locate();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final fix = await widget.provider.currentFix();
      if (!mounted) return;
      setState(() {
        _pin = fix;
        _typed = false;
        _entering = false;
      });
      unawaited(_suggestName(fix));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Offers a name for [pin] when place names are turned on. The answer is
  /// dropped if the pin has moved on or a name has been typed meanwhile.
  Future<void> _suggestName(LocationFix pin) async {
    final placeNames = widget.placeNames;
    if (placeNames == null) return;
    setState(() => _lookup = _Lookup.asking);
    final name = await placeNames.nameFor(
      latitude: pin.latitude,
      longitude: pin.longitude,
    );
    if (!mounted || !identical(_pin, pin)) return;
    setState(() {
      if (name == null) {
        _lookup = _Lookup.nothingFound;
      } else if (_nameController.text.trim().isEmpty) {
        _nameController.text = name;
        _lookup = _Lookup.suggested;
      } else {
        _lookup = _Lookup.none;
      }
    });
  }

  String get _nameFootnote => switch (_lookup) {
    _Lookup.asking => 'Looking up a name for this place…',
    _Lookup.suggested =>
      'Name suggested by OpenStreetMap. Change it if you like.',
    _Lookup.nothingFound => 'No name was found online. Type one if you like.',
    _Lookup.none =>
      widget.placeNames == null
          ? 'Place names are typed by you. Nothing is looked up online.'
          : 'Place names are on. This name is yours.',
  };

  Future<void> _recentre() =>
      _access == LocationAccess.granted ? _locate() : _allow();

  void _useTyped(double latitude, double longitude) {
    final pin = LocationFix(latitude: latitude, longitude: longitude);
    setState(() {
      _pin = pin;
      _typed = true;
      _entering = false;
    });
    unawaited(_suggestName(pin));
  }

  Future<void> _save() async {
    final pin = _pin;
    if (pin == null || _saving) return;
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final id = await widget.repository.createLocation(
      latitude: pin.latitude,
      longitude: pin.longitude,
      accuracyMeters: pin.accuracyMeters,
      name: name.isEmpty ? null : name,
      createdAt: widget.now(),
    );
    widget.onSaved(id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.location);

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          Positioned.fill(
            child: _pin != null && widget.mapSource != null
                ? PlaceMap(
                    source: widget.mapSource!,
                    latitude: _pin!.latitude,
                    longitude: _pin!.longitude,
                    pinAt: const Offset(0.5, 0.36),
                  )
                : StylisedMap(
                    pins: _pin == null ? const [] : const [Offset(0.5, 0.36)],
                    showHalo: _pin != null && !_typed,
                    pinSize: 48,
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.close,
                    label: 'Close without saving',
                    tokens: tokens,
                    onTap: widget.onClose,
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    child: GlassSurface(
                      variant: GlassVariant.card,
                      borderRadius: 22,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              momentIconFor(LogType.location),
                              size: 16,
                              color: color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: tokens.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _RoundButton(
                    icon: Icons.my_location,
                    label: 'Use current position',
                    tokens: tokens,
                    onTap: _locating ? null : _recentre,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: tokens.ground.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    22,
                    20,
                    20 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: _panel(tokens, color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(MomentTokens tokens, Color color) {
    if (_entering) {
      return CoordinatesEntry(
        tokens: tokens,
        onUse: _useTyped,
        onCancel: () => setState(() => _entering = false),
      );
    }

    final pin = _pin;
    if (pin != null) {
      final accuracy = pin.accuracyMeters;
      final how = accuracy == null
          ? 'Typed coordinates'
          : 'Accuracy ${formatAccuracy(accuracy)}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pin this spot',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 28,
                    color: tokens.ink,
                  ),
                ),
              ),
              if (!_typed)
                LocationPill(
                  label: 'Locked on',
                  icon: Icons.check,
                  tokens: tokens,
                ),
            ],
          ),
          Text(
            '$how · ${_whenFormat.format(widget.now())}',
            style: TextStyle(fontSize: 14, color: tokens.secondary),
          ),
          const SizedBox(height: 12),
          GlassSurface(
            variant: GlassVariant.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                key: const ValueKey('place-name'),
                controller: _nameController,
                style: TextStyle(fontSize: 15, color: tokens.ink),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: tokens.secondary,
                  ),
                  hintText: 'Name this place (optional)',
                  hintStyle: TextStyle(color: tokens.secondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _nameFootnote,
            style: TextStyle(fontSize: 13.5, color: tokens.secondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LocationPillButton(
                  label: 'Move pin',
                  icon: Icons.my_location,
                  tokens: tokens,
                  onTap: () => setState(() => _entering = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LocationPillButton(
                  label: 'Save location',
                  tokens: tokens,
                  primary: true,
                  onTap: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final access = _access;
    if (access == null || access == LocationAccess.granted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Finding where you are…',
          style: TextStyle(fontSize: 15, color: tokens.secondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pin this spot',
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontWeight: FontWeight.w500,
            fontSize: 28,
            color: tokens.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          locationAccessMessage(access),
          style: TextStyle(fontSize: 14.5, color: tokens.ink),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: LocationPillButton(
                label: 'Enter coordinates',
                tokens: tokens,
                onTap: () => setState(() => _entering = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: access == LocationAccess.denied
                  ? LocationPillButton(
                      label: 'Allow location',
                      tokens: tokens,
                      primary: true,
                      onTap: _allow,
                    )
                  : LocationPillButton(
                      label: 'Open Settings',
                      tokens: tokens,
                      primary: true,
                      onTap: widget.provider.openSettings,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _Lookup { none, asking, suggested, nothingFound }

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final MomentTokens tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: GlassSurface(
            variant: GlassVariant.card,
            borderRadius: 22,
            child: Icon(icon, size: 20, color: tokens.ink),
          ),
        ),
      ),
    );
  }
}
