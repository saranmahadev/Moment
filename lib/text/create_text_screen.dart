import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';

final _dateTimeFormat = DateFormat('EEE d MMM');
final _timeFormat = DateFormat('HH:mm');

/// The New Text screen: write, optionally backdate, and save. Matches
/// design/mockups/png/05-Create-Text.png.
class CreateTextScreen extends StatefulWidget {
  const CreateTextScreen({
    super.key,
    required this.repository,
    DateTime Function()? now,
    required this.onSaved,
    required this.onClose,
    this.editing,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final DateTime Function() now;
  final ValueChanged<String> onSaved;
  final VoidCallback onClose;

  /// When set, this screen edits that log in place instead of creating a
  /// new one.
  final TextLog? editing;

  @override
  State<CreateTextScreen> createState() => _CreateTextScreenState();
}

class _CreateTextScreenState extends State<CreateTextScreen> {
  late DateTime _createdAt = widget.editing?.createdAt ?? widget.now();
  late final _controller = TextEditingController(
    text: widget.editing?.body ?? '',
  );
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _wordCount = _wordsIn(_controller.text);
    _controller.addListener(_updateWordCount);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static int _wordsIn(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  void _updateWordCount() {
    final count = _wordsIn(_controller.text);
    if (count != _wordCount) setState(() => _wordCount = count);
  }

  Future<void> _save() async {
    final body = _controller.text;
    if (body.trim().isEmpty) return;

    final editing = widget.editing;
    if (editing != null) {
      await widget.repository.updateText(editing.id, body: body);
      if (_createdAt != editing.createdAt) {
        await widget.repository.setCreatedAt(editing.id, _createdAt);
      }
      widget.onSaved(editing.id);
      return;
    }

    final id = await widget.repository.createText(
      body: body,
      createdAt: _createdAt,
    );
    widget.onSaved(id);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: widget.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay.fromDateTime(_createdAt),
    );
    if (time == null) return;

    setState(() {
      _createdAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
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
                children: [
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Close without saving',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: widget.onClose,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: GlassSurface(
                              variant: GlassVariant.card,
                              borderRadius: 22,
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: tokens.ink,
                              ),
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
                                    color: tokens.tintFor(LogType.text),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.text_fields_rounded,
                                    size: 15,
                                    color: tokens.colorFor(LogType.text),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Text',
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
                      GestureDetector(
                        onTap: _save,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: SizedBox(
                        height: 40,
                        child: GlassSurface(
                          variant: GlassVariant.card,
                          borderRadius: 20,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: tokens.ink,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_dateTimeFormat.format(_createdAt)} · '
                                  '${_timeFormat.format(_createdAt)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: tokens.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GlassSurface(
                      variant: GlassVariant.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: TextStyle(
                                  fontFamily: 'Newsreader',
                                  fontSize: 23,
                                  height: 1.45,
                                  color: tokens.ink,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                            Text(
                              '$_wordCount words',
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.secondary,
                              ),
                            ),
                          ],
                        ),
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
