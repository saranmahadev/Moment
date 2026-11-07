import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../data/media_store.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'create_photo_screen.dart';
import 'photo_picker.dart';

final _dateTimeFormat = DateFormat('EEEE d MMMM');
final _timeFormat = DateFormat('HH:mm');

/// A single photo log, full screen. Matches
/// design/mockups/png/19-Detail-Photo.png.
class PhotoDetailScreen extends StatelessWidget {
  const PhotoDetailScreen({
    super.key,
    required this.log,
    required this.repository,
    required this.mediaStore,
    required this.picker,
    DateTime Function()? now,
    this.onBack,
  }) : now = now ?? DateTime.now;

  final PhotoLog log;
  final LogRepository repository;
  final MediaStore mediaStore;
  final PhotoPicker picker;
  final DateTime Function() now;
  final VoidCallback? onBack;

  Future<void> _delete() async {
    await repository.softDelete(log.id);
    onBack?.call();
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatePhotoScreen(
          repository: repository,
          mediaStore: mediaStore,
          picker: picker,
          now: now,
          editing: log,
          onSaved: (_) {
            Navigator.of(context).pop();
            onBack?.call();
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.chevron_left,
                        label: 'Back',
                        tokens: tokens,
                        onTap: onBack,
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        tokens: tokens,
                        onTap: () => _edit(context),
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
                          color: tokens.tintFor(LogType.photo),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          momentIconFor(LogType.photo),
                          size: 16,
                          color: tokens.colorFor(LogType.photo),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${_dateTimeFormat.format(log.localMoment)} · '
                          '${_timeFormat.format(log.localMoment)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: tokens.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.file(File(log.path), fit: BoxFit.cover),
                    ),
                  ),
                  if (log.caption != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      log.caption!,
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 20,
                        color: tokens.ink,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  GlassSurface(
                    variant: GlassVariant.card,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: tokens.ink,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Original quality',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: tokens.ink,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.lock_outline, size: 16, color: tokens.ink),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Stored on this device',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: tokens.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
