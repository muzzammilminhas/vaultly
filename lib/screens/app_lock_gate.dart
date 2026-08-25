import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vault_providers.dart';
import 'lock_screen.dart';

/// Gates [child] behind [LockScreen] on first build and again every time the
/// app resumes from being fully backgrounded — unless a system dialog the
/// app itself opened (camera permission, photo picker, share sheet) is the
/// reason for the pause, tracked via [lockSuppressionProvider].
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  bool _locked = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    if (ref.read(lockSuppressionProvider) > 0) return;
    if (!_locked) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    return _locked ? LockScreen(onUnlocked: () => setState(() => _locked = false)) : widget.child;
  }
}
