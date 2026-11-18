import 'dart:io';

import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../data/media_store.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import 'video_picker.dart';
import 'video_poster.dart';
import 'video_probe.dart';

/// The New Video screen: record or choose a video, caption it, save.
/// Simplifies design/mockups/png/08-Create-Video.png's custom viewfinder
/// to the system camera and gallery; Phase 5 is where pixel fidelity
/// against the mockups gets enforced.
class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({
    super.key,
    required this.repository,
    required this.mediaStore,
    required this.picker,
    required this.probe,
    DateTime Function()? now,
    required this.onSaved,
    required this.onClose,
    this.editing,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final MediaStore mediaStore;
  final VideoPicker picker;
  final VideoProbe probe;
  final DateTime Function() now;
  final ValueChanged<String> onSaved;
  final VoidCallback onClose;

  /// When set, this screen edits that log's caption in place instead of
  /// picking and creating a new video log.
  final VideoLog? editing;

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  File? _pickedFile;
  bool _saving = false;
  String? _error;
  late final _captionController = TextEditingController(
    text: widget.editing?.caption ?? '',
  );

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<File?> Function() pick) async {
    final file = await pick();
    if (file == null || !mounted) return;
    setState(() {
      _pickedFile = file;
      _error = null;
    });
  }

  String? _captionOrNull() {
    final text = _captionController.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (_saving) return;

    final editing = widget.editing;
    if (editing != null) {
      setState(() => _saving = true);
      await widget.repository.updateVideo(
        editing.id,
        caption: _captionOrNull(),
      );
      if (!mounted) return;
      widget.onSaved(editing.id);
      return;
    }

    final file = _pickedFile;
    if (file == null) return;

    setState(() => _saving = true);
    final ImportedVideo imported;
    try {
      imported = await widget.mediaStore.importVideo(file, probe: widget.probe);
    } on ArgumentError {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pickedFile = null;
        _error = 'This video could not be read.';
      });
      return;
    }
    final String id;
    try {
      id = await widget.repository.createVideo(
        path: imported.path,
        posterPath: imported.posterPath,
        duration: imported.duration,
        caption: _captionOrNull(),
        createdAt: widget.now(),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    widget.onSaved(id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final editing = widget.editing;
    final hasVideo = editing != null || _pickedFile != null;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  _Header(
                    tokens: tokens,
                    canSave: hasVideo,
                    saving: _saving,
                    onClose: widget.onClose,
                    onSave: _save,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: hasVideo
                        ? _Preview(
                            posterPath: editing?.posterPath,
                            captionController: _captionController,
                            tokens: tokens,
                          )
                        : _PickerChoices(
                            tokens: tokens,
                            error: _error,
                            onRecord: () =>
                                _pick(widget.picker.recordWithCamera),
                            onChooseFromLibrary: () =>
                                _pick(widget.picker.pickFromGallery),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.tokens,
    required this.canSave,
    required this.saving,
    required this.onClose,
    required this.onSave,
  });

  final MomentTokens tokens;
  final bool canSave;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Close without saving',
          onTap: onClose,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onClose,
            child: SizedBox(
              width: 44,
              height: 44,
              child: GlassSurface(
                variant: GlassVariant.card,
                borderRadius: 22,
                child: Icon(Icons.close, size: 20, color: tokens.ink),
              ),
            ),
          ),
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
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: tokens.tintFor(LogType.video),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      momentIconFor(LogType.video),
                      size: 15,
                      color: tokens.colorFor(LogType.video),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Video',
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
        if (canSave)
          GestureDetector(
            onTap: saving ? null : onSave,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: tokens.ink,
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.onInk,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: tokens.onInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          )
        else
          const SizedBox(width: 44),
      ],
    );
  }
}

class _PickerChoices extends StatelessWidget {
  const _PickerChoices({
    required this.tokens,
    required this.error,
    required this.onRecord,
    required this.onChooseFromLibrary,
  });

  final MomentTokens tokens;
  final String? error;
  final VoidCallback onRecord;
  final VoidCallback onChooseFromLibrary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: tokens.danger),
            ),
            const SizedBox(height: 16),
          ],
          _ChoiceButton(
            icon: Icons.videocam_outlined,
            label: 'Record Video',
            tokens: tokens,
            onTap: onRecord,
          ),
          const SizedBox(height: 14),
          _ChoiceButton(
            icon: Icons.video_library_outlined,
            label: 'Choose from Library',
            tokens: tokens,
            onTap: onChooseFromLibrary,
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: GlassSurface(
          variant: GlassVariant.card,
          borderRadius: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: tokens.ink),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.posterPath,
    required this.captionController,
    required this.tokens,
  });

  /// The stored poster when editing; null for a video picked but not yet
  /// imported, which has no still frame to show.
  final String? posterPath;
  final TextEditingController captionController;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPoster(path: posterPath, tokens: tokens),
                if (posterPath == null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          size: 36,
                          color: tokens.ink,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Video selected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GlassSurface(
          variant: GlassVariant.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              enableIMEPersonalizedLearning: false,
              controller: captionController,
              style: TextStyle(fontSize: 15, color: tokens.ink),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Add a caption',
                hintStyle: TextStyle(color: tokens.secondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
