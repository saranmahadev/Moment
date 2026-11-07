import 'dart:async';

import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import 'app_lock_controller.dart';

enum _Stage { enter, confirm }

/// Sets a new app-lock PIN: enter 4 digits, then enter them again to
/// confirm. Does not reuse LockScreen's private keypad, so that widget's
/// golden test stays untouched by changes here.
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({
    super.key,
    required this.controller,
    required this.onDone,
    required this.onCancel,
  });

  final AppLockController controller;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  static const _pinLength = 4;
  static const _mismatchClearDelay = Duration(milliseconds: 600);

  _Stage _stage = _Stage.enter;
  String _firstPin = '';
  String _entered = '';
  bool _showMismatch = false;

  void _onDigit(String digit) {
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _showMismatch = false;
    });
    if (_entered.length == _pinLength) {
      _onStageComplete();
    }
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _showMismatch = false;
    });
  }

  Future<void> _onStageComplete() async {
    if (_stage == _Stage.enter) {
      setState(() {
        _firstPin = _entered;
        _entered = '';
        _stage = _Stage.confirm;
      });
      return;
    }

    if (_entered == _firstPin) {
      await widget.controller.setPin(_firstPin);
      if (!mounted) return;
      widget.onDone();
      return;
    }

    setState(() => _showMismatch = true);
    await Future<void>.delayed(_mismatchClearDelay);
    if (!mounted) return;
    setState(() {
      _firstPin = '';
      _entered = '';
      _stage = _Stage.enter;
      _showMismatch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    final title = _stage == _Stage.enter ? 'Choose a PIN' : 'Confirm your PIN';

    return Scaffold(
      backgroundColor: tokens.ground,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Semantics(
                  button: true,
                  label: 'Cancel',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: widget.onCancel,
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 15, color: tokens.secondary),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontWeight: FontWeight.w500,
                fontSize: 28,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 20),
            _PinDots(
              entered: _entered.length,
              length: _pinLength,
              tokens: tokens,
              error: _showMismatch,
            ),
            if (_showMismatch) ...[
              const SizedBox(height: 8),
              Text(
                "PINs don't match",
                style: TextStyle(fontSize: 13, color: tokens.danger),
              ),
            ],
            const Spacer(),
            _Keypad(tokens: tokens, onDigit: _onDigit, onDelete: _onDelete),
            const Spacer(),
          ],
        ),
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
  });

  final MomentTokens tokens;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

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
        row([const SizedBox(width: 76), gap(), _digit('0'), gap(), _delete()]),
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
          excludeSemantics: true,
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
          excludeSemantics: true,
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
