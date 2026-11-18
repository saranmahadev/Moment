import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'coordinates.dart';
import 'location_provider.dart';
import 'location_widgets.dart';
import 'map/map_source.dart';
import 'place_map.dart';
import 'stylised_map.dart';

final _dateFormat = DateFormat('EEEE d MMMM');
final _timeFormat = DateFormat('HH:mm');

/// A single location log, full screen: the pin on the offline map tile,
/// its name and coordinates, with Copy coordinates and Move pin. Matches
/// design/mockups/png/22-Detail-Location.png.
class LocationDetailScreen extends StatefulWidget {
  const LocationDetailScreen({
    super.key,
    required this.log,
    required this.repository,
    required this.provider,
    this.mapSource,
    DateTime Function()? now,
    this.onBack,
  }) : now = now ?? DateTime.now;

  final LocationLog log;
  final LogRepository repository;
  final LocationProvider provider;

  /// The bundled map to show the place on. Without one, the plain tile.
  final MapSource? mapSource;
  final DateTime Function() now;
  final VoidCallback? onBack;

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  late LocationLog _log = widget.log;
  bool _editing = false;
  bool _moving = false;
  String? _moveMessage;
  late final _nameController = TextEditingController(text: _log.name ?? '');
  late final _noteController = TextEditingController(text: _log.note ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final fresh = await widget.repository.getById(_log.id) as LocationLog;
    if (!mounted) return;
    setState(() => _log = fresh);
  }

  Future<void> _delete() async {
    await widget.repository.softDelete(_log.id);
    widget.onBack?.call();
  }

  Future<void> _saveEdits() async {
    final name = _nameController.text.trim();
    final note = _noteController.text.trim();
    await widget.repository.updateLocation(
      _log.id,
      name: name.isEmpty ? null : name,
      note: note.isEmpty ? null : note,
    );
    await _reload();
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: coordinatesForCopying(_log.latitude, _log.longitude)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Coordinates copied')));
  }

  Future<void> _moveToCurrentPosition() async {
    var access = await widget.provider.checkAccess();
    if (access == LocationAccess.denied) {
      access = await widget.provider.requestAccess();
    }
    if (access != LocationAccess.granted) {
      if (mounted) setState(() => _moveMessage = locationAccessMessage(access));
      return;
    }
    final fix = await widget.provider.currentFix();
    await _moveTo(fix.latitude, fix.longitude, fix.accuracyMeters);
  }

  Future<void> _moveTo(
    double latitude,
    double longitude, [
    double? accuracyMeters,
  ]) async {
    await widget.repository.moveLocation(
      _log.id,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
    );
    await _reload();
    if (mounted) {
      setState(() {
        _moving = false;
        _moveMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final color = tokens.colorFor(LogType.location);
    final accuracy = _log.accuracyMeters;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.chevron_left,
                        label: 'Back',
                        tokens: tokens,
                        onTap: widget.onBack,
                      ),
                      const Spacer(),
                      if (_editing)
                        _RoundIconButton(
                          icon: Icons.check,
                          label: 'Save',
                          tokens: tokens,
                          onTap: _saveEdits,
                        )
                      else
                        _RoundIconButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          tokens: tokens,
                          onTap: () => setState(() => _editing = true),
                        ),
                      const SizedBox(width: 10),
                      _RoundIconButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        tokens: tokens,
                        onTap: _delete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tokens.tintFor(LogType.location),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          momentIconFor(LogType.location),
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${_dateFormat.format(_log.localMoment)} · '
                          '${_timeFormat.format(_log.localMoment)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: tokens.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SizedBox(
                      height: 250,
                      child: widget.mapSource == null
                          ? const StylisedMap(
                              pins: [Offset(0.5, 0.55)],
                              pinSize: 48,
                            )
                          : PlaceMap(
                              source: widget.mapSource!,
                              latitude: _log.latitude,
                              longitude: _log.longitude,
                              zoomable: true,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_editing)
                    GlassSurface(
                      variant: GlassVariant.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Column(
                          children: [
                            TextField(
                              enableIMEPersonalizedLearning: false,
                              key: const ValueKey('place-name'),
                              controller: _nameController,
                              style: TextStyle(
                                fontFamily: 'Newsreader',
                                fontSize: 24,
                                color: tokens.ink,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Name this place',
                                hintStyle: TextStyle(color: tokens.secondary),
                              ),
                            ),
                            TextField(
                              enableIMEPersonalizedLearning: false,
                              key: const ValueKey('place-note'),
                              controller: _noteController,
                              maxLines: null,
                              style: TextStyle(fontSize: 15, color: tokens.ink),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Add a note',
                                hintStyle: TextStyle(color: tokens.secondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      _log.name ?? 'Pinned place',
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 30,
                        color: tokens.ink,
                      ),
                    ),
                    if (_log.note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _log.note!,
                        style: TextStyle(fontSize: 15, color: tokens.ink),
                      ),
                    ],
                  ],
                  const SizedBox(height: 6),
                  Text(
                    formatCoordinates(_log.latitude, _log.longitude),
                    style: TextStyle(fontSize: 14.5, color: tokens.secondary),
                  ),
                  const SizedBox(height: 12),
                  if (accuracy != null) ...[
                    LocationPill(
                      label: 'Accuracy ${formatAccuracy(accuracy)}',
                      icon: Icons.my_location,
                      tokens: tokens,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  if (_moving)
                    _movePanel(tokens)
                  else
                    Row(
                      children: [
                        Expanded(
                          child: LocationPillButton(
                            label: 'Copy coordinates',
                            icon: Icons.copy_outlined,
                            tokens: tokens,
                            onTap: _copy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LocationPillButton(
                            label: 'Move pin',
                            icon: Icons.my_location,
                            tokens: tokens,
                            onTap: () => setState(() => _moving = true),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _movePanel(MomentTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LocationPillButton(
          label: 'Use current position',
          icon: Icons.my_location,
          tokens: tokens,
          onTap: _moveToCurrentPosition,
        ),
        if (_moveMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _moveMessage!,
            style: TextStyle(fontSize: 13.5, color: tokens.danger),
          ),
        ],
        const SizedBox(height: 12),
        CoordinatesEntry(
          tokens: tokens,
          onUse: _moveTo,
          onCancel: () => setState(() {
            _moving = false;
            _moveMessage = null;
          }),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.tokens,
    this.onTap,
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
