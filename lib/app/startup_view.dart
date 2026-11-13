import 'package:flutter/material.dart';

import 'theme.dart';

/// Minimal brand handoff. The Android system splash remains platform-owned;
/// this surface animates only while the local workspace becomes available.
class WorkspaceLoadingView extends StatefulWidget {
  const WorkspaceLoadingView({super.key, this.showWelcome = false});

  /// Retained for API compatibility. Startup no longer displays welcome copy.
  final bool showWelcome;

  @override
  State<WorkspaceLoadingView> createState() => _WorkspaceLoadingViewState();
}

class _WorkspaceLoadingViewState extends State<WorkspaceLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Semantics(
            label: 'DeskSuite is opening',
            child: ExcludeSemantics(child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = reducedMotion ? 1.0 : _controller.value;
              final wordIn = Curves.easeOutCubic.transform(
                (progress / .42).clamp(0.0, 1.0),
              );
              final logoIn = Curves.easeOutCubic.transform(
                ((progress - .36) / .56).clamp(0.0, 1.0),
              );
              final wordOpacity = (1 - ((progress - .38) / .28))
                  .clamp(0.0, 1.0);
              return SizedBox(
                height: 140,
                width: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: reducedMotion ? 0 : wordIn * wordOpacity,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - wordIn)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'DeskSuite',
                            key: const Key('startup-wordmark'),
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.9,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: reducedMotion ? 1 : logoIn,
                      child: Transform.scale(
                        scale: reducedMotion ? 1 : .82 + .18 * logoIn,
                        child: const BrandMark(size: 92),
                      ),
                    ),
                  ],
                ),
              );
            },
          )),
          ),
        ),
      ),
    );
  }
}
