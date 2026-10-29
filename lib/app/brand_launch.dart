import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand_motion.dart';
import 'theme.dart';

/// A short cold-start treatment above the already-initializing workspace.
/// It is removed when complete and is skipped when system animations are off.
class BrandLaunch extends StatefulWidget {
  const BrandLaunch({super.key, required this.child});
  final Widget child;

  @override
  State<BrandLaunch> createState() => _BrandLaunchState();
}

class _BrandLaunchState extends State<BrandLaunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _visible) {
      _controller.stop();
      _visible = false;
    }
    if (_started) return;
    _started = true;
    if (!reduceMotion) _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(excluding: _visible, child: widget.child),
      if (_visible)
        Positioned.fill(
          key: const Key('brand-launch-surface'),
          child: AbsorbPointer(
            child: Semantics(
              label: 'DeskSuite is starting',
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    _LaunchArtwork(progress: _controller.value),
              ),
            ),
          ),
        ),
    ],
  );
}

class _LaunchArtwork extends StatelessWidget {
  const _LaunchArtwork({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final fadeOut = 1 - ((progress - .9) / .1).clamp(0.0, 1.0);
    final reveal = brandArtworkReveal(progress);
    return Opacity(
      opacity: fadeOut,
      child: ColoredBox(
        color: const Color(0xfff6f3ed), // Warm paper launch surface.
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(
                216.0,
                math.min(
                  constraints.maxWidth * .52,
                  constraints.maxHeight * .44,
                ),
              );
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.max(1.0, constraints.maxWidth - 40),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: size,
                            height: size,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xffa84f36),
                                    borderRadius: BorderRadius.circular(
                                      size * .22,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xffd9b99f)
                                          .withValues(alpha: .3),
                                    ),
                                  ),
                                ),
                                CustomPaint(
                                  key: const Key('brand-launch-drawing'),
                                  painter: _DrawBrand(progress, reveal),
                                ),
                                Opacity(
                                  key: const Key('brand-launch-artwork'),
                                  opacity: reveal,
                                  child: BrandMark(size: size),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'DeskSuite',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xff292721),
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Documents · Design · Print · Business',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xffc4e8ff),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DrawBrand extends CustomPainter {
  const _DrawBrand(this.progress, this.reveal);
  final double progress;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.save();
    canvas.scale(side);
    final opacity = 1 - reveal;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final d = Path()
      ..moveTo(.26, .25)
      ..lineTo(.39, .25)
      ..cubicTo(.56, .25, .63, .35, .63, .5)
      ..cubicTo(.63, .65, .56, .75, .39, .75)
      ..lineTo(.26, .75)
      ..close();
    stroke
      ..color = const Color(0xfff4faff).withValues(alpha: opacity)
      ..strokeWidth = .055;
    _drawPartial(canvas, d, (progress / .48).clamp(0.0, 1.0), stroke);

    final s = Path()
      ..moveTo(.75, .3)
      ..cubicTo(.68, .23, .55, .25, .54, .35)
      ..cubicTo(.52, .45, .68, .44, .73, .51)
      ..cubicTo(.8, .6, .7, .73, .56, .67);
    stroke
      ..color = const Color(0xff50ddea).withValues(alpha: opacity)
      ..strokeWidth = .052;
    _drawPartial(canvas, s, ((progress - .15) / .48).clamp(0.0, 1.0), stroke);

    canvas.save();
    canvas.translate(.5, .5);
    final scale = brandScanFrameScale(progress);
    canvas.scale(scale);
    canvas.translate(-.5, -.5);
    final frame = Path()
      ..moveTo(.12, .25)
      ..lineTo(.12, .14)
      ..quadraticBezierTo(.12, .12, .14, .12)
      ..lineTo(.25, .12)
      ..moveTo(.75, .12)
      ..lineTo(.86, .12)
      ..quadraticBezierTo(.88, .12, .88, .14)
      ..lineTo(.88, .25)
      ..moveTo(.12, .75)
      ..lineTo(.12, .86)
      ..quadraticBezierTo(.12, .88, .14, .88)
      ..lineTo(.25, .88)
      ..moveTo(.75, .88)
      ..lineTo(.86, .88)
      ..quadraticBezierTo(.88, .88, .88, .86)
      ..lineTo(.88, .75);
    stroke
      ..color = const Color(0xff75eaf3).withValues(alpha: opacity)
      ..strokeWidth = .022;
    _drawPartial(canvas, frame, (progress / .4).clamp(0.0, 1.0), stroke);
    canvas.restore();
    canvas.restore();
  }

  void _drawPartial(Canvas canvas, Path path, double fraction, Paint paint) {
    final metrics = path.computeMetrics().toList(growable: false);
    final length = metrics.fold<double>(
      0,
      (sum, metric) => sum + metric.length,
    );
    var remaining = length * fraction;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final amount = math.min(remaining, metric.length);
      canvas.drawPath(metric.extractPath(0, amount), paint);
      remaining -= amount;
    }
  }

  @override
  bool shouldRepaint(covariant _DrawBrand oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.reveal != reveal;
}
