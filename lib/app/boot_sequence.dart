import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand.dart';
import 'zamcan_mark.dart';

/// The branded start of the app.
///
/// The mark is drawn for the first time — the outline is traced, then filled —
/// while a scanning frame zooms in and out around it, as though the app were
/// looking at the page it is about to work on. The wordmark arrives last and
/// the screen hands over to the workspace.
///
/// Nothing here is decorative filler: it is the same mark, palette and type as
/// the sidebar and the launcher icon, and it is skipped to a static frame when
/// the device asks for reduced motion.
class BootSequence extends StatefulWidget {
  const BootSequence({
    super.key,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 2600),
  });

  /// Called once the animation has finished, or immediately when motion is
  /// reduced. The caller decides what to show next.
  final VoidCallback onComplete;

  /// Full length of the animation. Tests shorten it.
  final Duration duration;

  @override
  State<BootSequence> createState() => _BootSequenceState();
}

class _BootSequenceState extends State<BootSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `disableAnimations` comes from the platform's accessibility settings:
    // the same switch that turns off motion on a phone turns this off.
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduced) {
      _finish();
    } else if (!_controller.isAnimating && !_completed) {
      _controller.forward().whenComplete(_finish);
    }
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    // Let the frame with the finished mark paint before the caller swaps the
    // screen, so the hand-over is a fade rather than a flash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = ZamCanColors.of(context);
    final base = Theme.of(context).brightness == Brightness.dark
        ? ZamCanBrand.inkDark
        : ZamCanBrand.paper;
    return Semantics(
      label: '${ZamCanBrand.product} by ${ZamCanBrand.company}, starting',
      child: ColoredBox(
        key: const Key('boot-sequence'),
        color: base,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _reduced ? 1.0 : _controller.value;
              final draw = _phase(t, end: .58, curve: Curves.easeInOutCubic);
              final frame = _phase(t, start: .12, end: .88);
              final words = _phase(t, start: .52, end: .86);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 208,
                    height: 208,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (frame > 0 && frame < 1)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ScanFramePainter(
                                phase: frame * 2,
                                color: brand.accent.withValues(
                                  alpha: .55 * math.sin(frame * math.pi),
                                ),
                                lineColor: brand.accentSoft,
                              ),
                            ),
                          ),
                        ZamCanMark(
                          key: const Key('boot-logo'),
                          size: 116,
                          tile: false,
                          drawProgress: _reduced ? 1 : draw,
                          foreground: ZamCanBrand.ink,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Opacity(
                    opacity: words,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - words)),
                      child: Column(
                        children: [
                          Text(
                            ZamCanBrand.product,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? brand.ink
                                      : ZamCanBrand.ink,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BY ${ZamCanBrand.company.toUpperCase()}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  letterSpacing: 2.4,
                                  fontWeight: FontWeight.w700,
                                  color: brand.accentDeep,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            ZamCanBrand.tagline,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Progress of one step of the sequence: 0 before [start], 1 after [end].
  double _phase(
    double t, {
    double start = 0,
    required double end,
    Curve curve = Curves.easeOut,
  }) {
    if (t <= start) return 0;
    final local = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(local);
  }
}
