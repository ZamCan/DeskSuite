import 'package:flutter/material.dart';

import 'startup_view.dart';

/// Android owns the initial system splash. Flutter then reveals the DeskSuite
/// wordmark and logo while the local workspace initializes.
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

    // Run initialization concurrently with the short wordmark/logo handoff.
    // Never show a fake progress indicator or delay after readiness and motion.
    await Future.wait<void>([
      readyFuture,
      Future<void>.delayed(const Duration(milliseconds: 1050)),
    ]);
    if (!mounted) return;
    if (welcome) {
      // A preference-write failure must never hold the user outside the app.
      try {
        await widget.onWelcomeCompleted();
      } catch (_) {
        // The next opening may show the short welcome again.
      }
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
