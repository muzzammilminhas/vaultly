import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vault_providers.dart';

enum _Mode { checking, setupCreate, setupConfirm, unlock }

/// First-run PIN setup, or PIN/biometric unlock on subsequent launches.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  static const _pinLength = 4;

  _Mode _mode = _Mode.checking;
  String _entered = '';
  String? _firstPin;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = ref.read(authServiceProvider);
    final hasPin = await auth.hasPin();
    final biometricAvailable = hasPin && await auth.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _mode = hasPin ? _Mode.unlock : _Mode.setupCreate;
      _biometricAvailable = biometricAvailable;
    });
    if (biometricAvailable && !_biometricAttempted) {
      _biometricAttempted = true;
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    ref.read(lockSuppressionProvider.notifier).state++;
    try {
      final ok = await ref.read(authServiceProvider).authenticateWithBiometrics();
      if (ok && mounted) widget.onUnlocked();
    } finally {
      ref.read(lockSuppressionProvider.notifier).state--;
    }
  }

  void _onDigit(String digit) {
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == _pinLength) _submit();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    final auth = ref.read(authServiceProvider);
    switch (_mode) {
      case _Mode.setupCreate:
        setState(() {
          _firstPin = _entered;
          _entered = '';
          _mode = _Mode.setupConfirm;
        });
      case _Mode.setupConfirm:
        if (_entered == _firstPin) {
          await auth.setPin(_entered);
          widget.onUnlocked();
        } else {
          setState(() {
            _error = "PINs didn't match — try again";
            _entered = '';
            _firstPin = null;
            _mode = _Mode.setupCreate;
          });
        }
      case _Mode.unlock:
        final ok = await auth.verifyPin(_entered);
        if (ok) {
          widget.onUnlocked();
        } else {
          setState(() {
            _error = 'Incorrect PIN';
            _entered = '';
          });
        }
      case _Mode.checking:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _Mode.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final title = switch (_mode) {
      _Mode.setupCreate => 'Create a PIN',
      _Mode.setupConfirm => 'Confirm your PIN',
      _Mode.unlock => 'Enter your PIN',
      _Mode.checking => '',
    };
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(Icons.lock_outline, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _entered.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? colorScheme.primary : Colors.transparent,
                    border: Border.all(color: colorScheme.primary),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 24,
              child: _error == null
                  ? null
                  : Text(_error!, style: TextStyle(color: colorScheme.error)),
            ),
            const Spacer(flex: 3),
            _Keypad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              showBiometric: _mode == _Mode.unlock && _biometricAvailable,
              onBiometric: _tryBiometric,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.showBiometric,
    required this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool showBiometric;
  final VoidCallback onBiometric;

  Widget _key(BuildContext context, {VoidCallback? onTap, String? label, IconData? icon}) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            shape: const CircleBorder(),
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 26)
                    : Text(label ?? '', style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(children: [for (final d in row) _key(context, label: d, onTap: () => onDigit(d))]),
          Row(
            children: [
              showBiometric
                  ? _key(context, icon: Icons.fingerprint, onTap: onBiometric)
                  : const Spacer(),
              _key(context, label: '0', onTap: () => onDigit('0')),
              _key(context, icon: Icons.backspace_outlined, onTap: onBackspace),
            ],
          ),
        ],
      ),
    );
  }
}
