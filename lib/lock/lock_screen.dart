import 'dart:async';

import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import 'app_lock_controller.dart';
import 'biometric_authenticator.dart';

/// The PIN and Face ID entry screen. Matches
/// design/mockups/png/01-Lock.png.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.controller,
    required this.biometrics,
    this.onUnlocked,
  });

  final AppLockController controller;
  final BiometricAuthenticator biometrics;
  final VoidCallback? onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const _pinLength = 4;
  static const _errorClearDelay = Duration(milliseconds: 500);

  String _entered = '';
  bool _showError = false;

  void _onDigit(String digit) {
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _showError = false;
    });
    if (_entered.length == _pinLength) {
      _submit();
    }
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _showError = false;
    });
  }

  Future<void> _submit() async {
    final ok = await widget.controller.verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked?.call();
      return;
    }
    setState(() => _showError = true);
    await Future<void>.delayed(_errorClearDelay);
    if (!mounted) return;
    setState(() {
      _entered = '';
      _showError = false;
    });
  }

  Future<void> _onFaceId() async {
    if (await widget.biometrics.authenticate()) {
      widget.controller.unlock();
      widget.onUnlocked?.call();
    }
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
            child: Column(
              children: [
                const SizedBox(height: 56),
                _LockIcon(tokens: tokens),
                const SizedBox(height: 10),
                Text(
                  'Moment',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontWeight: FontWeight.w500,
                    fontSize: 38,
                    letterSpacing: -0.38,
                    height: 1.15,
                    color: tokens.ink,
                  ),
                ),
                Text(
                  'Everything stays on this device',
                  style: TextStyle(fontSize: 14.5, color: tokens.secondary),
                ),
                const SizedBox(height: 20),
                _PinDots(
                  entered: _entered.length,
                  length: _pinLength,
                  tokens: tokens,
                  error: _showError,
                ),
                if (_showError) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Incorrect PIN',
                    style: TextStyle(fontSize: 13, color: tokens.danger),
                  ),
                ],
                const Spacer(),
                _Keypad(
                  tokens: tokens,
                  onDigit: _onDigit,
                  onDelete: _onDelete,
                  onFaceId: _onFaceId,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'No account · No cloud · No tracking',
                    style: TextStyle(fontSize: 13, color: tokens.secondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockIcon extends StatelessWidget {
  const _LockIcon({required this.tokens});

  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: GlassSurface(
        variant: GlassVariant.surface,
        child: Icon(Icons.lock_outline_rounded, size: 26, color: tokens.ink),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.entered,
    required this.length,
    required this.tokens,
    required this.error,
  });

  final int entered;
  final int length;
  final MomentTokens tokens;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? tokens.danger : tokens.ink;
    return Semantics(
      label: '$entered of $length digits entered',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < entered ? color : null,
                  border: i < entered
                      ? null
                      : Border.all(color: tokens.secondary, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.tokens,
    required this.onDigit,
    required this.onDelete,
    required this.onFaceId,
  });

  final MomentTokens tokens;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onFaceId;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> cells) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: cells),
    );
    Widget gap() => const SizedBox(width: 20);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([_digit('1'), gap(), _digit('2'), gap(), _digit('3')]),
        row([_digit('4'), gap(), _digit('5'), gap(), _digit('6')]),
        row([_digit('7'), gap(), _digit('8'), gap(), _digit('9')]),
        row([_faceId(), gap(), _digit('0'), gap(), _delete()]),
      ],
    );
  }

  Widget _digit(String value) {
    return SizedBox(
      width: 76,
      height: 76,
      child: GestureDetector(
        key: ValueKey('digit-$value'),
        onTap: () => onDigit(value),
        child: Semantics(
          button: true,
          label: value,
          child: GlassSurface(
            variant: GlassVariant.card,
            borderRadius: 38,
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: tokens.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _faceId() {
    return SizedBox(
      width: 76,
      height: 76,
      child: GestureDetector(
        key: const ValueKey('face-id'),
        onTap: onFaceId,
        child: Semantics(
          button: true,
          label: 'Unlock with Face ID',
          child: Icon(
            Icons.face_retouching_natural,
            size: 30,
            color: tokens.ink,
          ),
        ),
      ),
    );
  }

  Widget _delete() {
    return SizedBox(
      width: 76,
      height: 76,
      child: GestureDetector(
        key: const ValueKey('delete'),
        onTap: onDelete,
        child: Semantics(
          button: true,
          label: 'Delete last digit',
          child: Icon(
            Icons.backspace_outlined,
            size: 28,
            color: tokens.secondary,
          ),
        ),
      ),
    );
  }
}
