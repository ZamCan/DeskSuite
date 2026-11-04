import 'package:flutter/material.dart';

import 'startup_view.dart';

/// The Android system splash supplies stage one (the app icon). This Flutter
/// surface is stage two and stays up only while the local workspace opens.
class BrandLaunch extends StatefulWidget {
  const BrandLaunch({
    super.key,
    required this.child,
    required this.showWelcome,
    required this.workspaceReady,
    required this.onWelcomeCompleted,
  });

  final Widget child;
  final Future<bool> showWelcome;
  final Future<void> workspaceReady;
  final Future<void> Function() onWelcomeCompleted;

  @override
  State<BrandLaunch> createState() => _BrandLaunchState();
}

class _BrandLaunchState extends State<BrandLaunch> {
  bool _visible = true;
  bool _showWelcome = false;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    final welcomeFuture = widget.showWelcome;
    final readyFuture = widget.workspaceReady;
    final welcome = await welcomeFuture;
    if (!mounted) return;
    setState(() => _showWelcome = welcome);

    // Keep the second stage perceptible without a fake progress indicator.
    // If initialization takes longer, the animated stationery continues;
    // if it is already ready, the minimum is only a brief visual handoff.
    await Future.wait<void>([
      readyFuture,
      Future<void>.delayed(const Duration(milliseconds: 420)),
    ]);
    if (!mounted) return;
    if (welcome) {
      await widget.onWelcomeCompleted();
    }
    if (!mounted) return;
    setState(() => _resolved = true);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_visible)
        Positioned.fill(
          key: const Key('brand-launch-surface'),
          child: AbsorbPointer(
            child: Semantics(
              label: _showWelcome
                  ? 'Welcome to DeskSuite'
                  : 'DeskSuite is opening',
              child: AnimatedOpacity(
                opacity: _resolved ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                onEnd: () {
                  if (_resolved && mounted) {
                    setState(() => _visible = false);
                  }
                },
                child: WorkspaceLoadingView(showWelcome: _showWelcome),
              ),
            ),
          ),
        ),
    ],
  );
}
