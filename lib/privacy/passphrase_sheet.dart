import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';

const _minimumLength = 8;

/// Asks for a backup passphrase. With [confirm], it is asked twice and must
/// be at least [_minimumLength] characters (choosing one for a new backup);
/// without, once (opening an existing backup). Resolves to the passphrase,
/// or null when dismissed.
Future<String?> showPassphraseSheet(
  BuildContext context, {
  required String title,
  required bool confirm,
}) {
  final tokens =
      Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.ground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _PassphraseSheet(title: title, confirm: confirm),
  );
}

class _PassphraseSheet extends StatefulWidget {
  const _PassphraseSheet({required this.title, required this.confirm});

  final String title;
  final bool confirm;

  @override
  State<_PassphraseSheet> createState() => _PassphraseSheetState();
}

class _PassphraseSheetState extends State<_PassphraseSheet> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    final passphrase = _first.text;
    if (widget.confirm) {
      if (passphrase.length < _minimumLength) {
        setState(() => _error = 'Use at least $_minimumLength characters.');
        return;
      }
      if (passphrase != _second.text) {
        setState(() => _error = 'Passphrases do not match.');
        return;
      }
    } else if (passphrase.isEmpty) {
      setState(() => _error = 'Enter the passphrase.');
      return;
    }
    Navigator.of(context).pop(passphrase);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontWeight: FontWeight.w500,
                  fontSize: 28,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.confirm
                    ? 'The backup can only be opened with this passphrase. '
                          'Moment cannot recover it for you.'
                    : 'The passphrase this backup was made with.',
                style: TextStyle(fontSize: 14, color: tokens.secondary),
              ),
              const SizedBox(height: 16),
              _Field(
                key: const ValueKey('passphrase'),
                controller: _first,
                hint: 'Passphrase',
                tokens: tokens,
                onSubmitted: widget.confirm ? null : _submit,
              ),
              if (widget.confirm) ...[
                const SizedBox(height: 10),
                _Field(
                  key: const ValueKey('passphrase-confirm'),
                  controller: _second,
                  hint: 'Passphrase again',
                  tokens: tokens,
                  onSubmitted: _submit,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 13.5, color: tokens.danger),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        height: 48,
                        child: GlassSurface(
                          variant: GlassVariant.card,
                          borderRadius: 24,
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: tokens.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _submit,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: tokens.ink,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    required this.tokens,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final MomentTokens tokens;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      variant: GlassVariant.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          style: TextStyle(fontSize: 15, color: tokens.ink),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(color: tokens.secondary),
          ),
        ),
      ),
    );
  }
}
