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
import 'photo_picker.dart';

/// The New Photo screen: pick from the camera or gallery, caption, save.
/// Simplifies design/mockups/png/07-Create-Photo.png's custom camera
/// viewfinder to image_picker's native camera/gallery pickers; Phase 5 is
/// where pixel fidelity against the mockups gets enforced.
class CreatePhotoScreen extends StatefulWidget {
  const CreatePhotoScreen({
    super.key,
    required this.repository,
    required this.mediaStore,
    required this.picker,
    DateTime Function()? now,
    required this.onSaved,
    required this.onClose,
    this.editing,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final MediaStore mediaStore;
  final PhotoPicker picker;
  final DateTime Function() now;
  final ValueChanged<String> onSaved;
  final VoidCallback onClose;

  /// When set, this screen edits that log's caption in place instead of
  /// picking and creating a new photo log.
  final PhotoLog? editing;

  @override
  State<CreatePhotoScreen> createState() => _CreatePhotoScreenState();
}

class _CreatePhotoScreenState extends State<CreatePhotoScreen> {
  File? _pickedFile;
  bool _saving = false;
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
    setState(() => _pickedFile = file);
  }

  Future<void> _save() async {
    if (_saving) return;

    final editing = widget.editing;
    if (editing != null) {
      setState(() => _saving = true);
      await widget.repository.updateCaption(
        editing.id,
        caption: _captionNullable(),
      );
      widget.onSaved(editing.id);
      return;
    }

    final file = _pickedFile;
    if (file == null) return;

    setState(() => _saving = true);
    final imported = await widget.mediaStore.importPhoto(file);
    final id = await widget.repository.createPhoto(
      path: imported.path,
      thumbnailPath: imported.thumbnailPath,
      caption: _captionNullable(),
      createdAt: widget.now(),
    );
    widget.onSaved(id);
  }

  String? _captionNullable() {
    final text = _captionController.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final editing = widget.editing;
    final imagePath = editing?.path ?? _pickedFile?.path;

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
                    canSave: imagePath != null,
                    saving: _saving,
                    onClose: widget.onClose,
                    onSave: _save,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: imagePath == null
                        ? _PickerChoices(
                            tokens: tokens,
                            onTakePhoto: () =>
                                _pick(widget.picker.pickFromCamera),
                            onChooseFromLibrary: () =>
                                _pick(widget.picker.pickFromGallery),
                          )
                        : _Preview(
                            imagePath: imagePath,
                            captionController: _captionController,
                            tokens: tokens,
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
                      color: tokens.tintFor(LogType.photo),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      momentIconFor(LogType.photo),
                      size: 15,
                      color: tokens.colorFor(LogType.photo),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Photo',
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
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
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
    required this.onTakePhoto,
    required this.onChooseFromLibrary,
  });

  final MomentTokens tokens;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseFromLibrary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChoiceButton(
            icon: Icons.photo_camera_outlined,
            label: 'Take Photo',
            tokens: tokens,
            onTap: onTakePhoto,
          ),
          const SizedBox(height: 14),
          _ChoiceButton(
            icon: Icons.photo_library_outlined,
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
    required this.imagePath,
    required this.captionController,
    required this.tokens,
  });

  final String imagePath;
  final TextEditingController captionController;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.file(File(imagePath), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 14),
        GlassSurface(
          variant: GlassVariant.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
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
