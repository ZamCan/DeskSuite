import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Quiet second-stage startup surface. The stationery symbols are a loading
/// treatment, not a decorative page; the workspace is revealed as soon as its
/// local repository is ready.
class WorkspaceLoadingView extends StatefulWidget {
  const WorkspaceLoadingView({super.key, this.showWelcome = false});

  final bool showWelcome;

  @override
  State<WorkspaceLoadingView> createState() => _WorkspaceLoadingViewState();
}

class _WorkspaceLoadingViewState extends State<WorkspaceLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, _) => CustomPaint(
                painter: _FallingStationeryPainter(
                  progress: _motion.value,
                  dark: dark,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 92),
                  if (widget.showWelcome) ...[
                    const SizedBox(height: 22),
                    Text(
                      'Welcome to DeskSuite',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallingStationeryPainter extends CustomPainter {
  const _FallingStationeryPainter({
    required this.progress,
    required this.dark,
  });

  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const count = 23;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = (dark ? const Color(0xffd7c7b4) : const Color(0xff887967))
          .withValues(alpha: dark ? .075 : .065);

    for (var i = 0; i < count; i++) {
      final seed = i * 37.17;
      final x = ((math.sin(seed * 1.73) + 1) * .5) * size.width;
      final travel = (progress * (size.height + 90) * (.62 + (i % 5) * .11));
      final y = ((seed * 19 + travel) % (size.height + 90)) - 45;
      final scale = .62 + (i % 4) * .15;
      final paint = Paint()
        ..color = base.color.withValues(
          alpha: base.color.a * (.55 + (i % 3) * .2),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(seed) * .28);
      canvas.scale(scale);
      switch (i % 6) {
        case 0:
          _document(canvas, paint);
          break;
        case 1:
          _folder(canvas, paint);
          break;
        case 2:
          _pencil(canvas, paint);
          break;
        case 3:
          _image(canvas, paint);
          break;
        case 4:
          _printer(canvas, paint);
          break;
        default:
          _scan(canvas, paint);
          break;
      }
      canvas.restore();
    }
  }

  void _document(Canvas c, Paint p) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -12, 16, 23),
        const Radius.circular(2),
      ),
      p,
    );
    c.drawLine(const Offset(-4, -4), const Offset(4, -4), p);
    c.drawLine(const Offset(-4, 0), const Offset(4, 0), p);
    c.drawLine(const Offset(-4, 4), const Offset(2, 4), p);
  }

  void _folder(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(-10, -5)
      ..lineTo(-3, -5)
      ..lineTo(0, -2)
      ..lineTo(10, -2)
      ..lineTo(8, 8)
      ..lineTo(-9, 8)
      ..close();
    c.drawPath(path, p);
  }

  void _pencil(Canvas c, Paint p) {
    c.save();
    c.rotate(-.55);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -11, 6, 19),
        const Radius.circular(1.5),
      ),
      p,
    );
    c.drawLine(const Offset(-3, 5), const Offset(0, 10), p);
    c.drawLine(const Offset(3, 5), const Offset(0, 10), p);
    c.restore();
  }

  void _image(Canvas c, Paint p) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -8, 22, 16),
        const Radius.circular(2),
      ),
      p,
    );
    c.drawCircle(const Offset(5, -3), 2, p);
    final hill = Path()
      ..moveTo(-8, 5)
      ..lineTo(-2, -1)
      ..lineTo(2, 3)
      ..lineTo(6, 0)
      ..lineTo(9, 5);
    c.drawPath(hill, p);
  }

  void _printer(Canvas c, Paint p) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -5, 20, 13),
        const Radius.circular(2),
      ),
      p,
    );
    c.drawRect(const Rect.fromLTWH(-6, -11, 12, 7), p);
    c.drawLine(const Offset(-5, 11), const Offset(5, 11), p);
  }

  void _scan(Canvas c, Paint p) {
    c.drawLine(const Offset(-9, -8), const Offset(-9, -3), p);
    c.drawLine(const Offset(-9, -8), const Offset(-4, -8), p);
    c.drawLine(const Offset(9, -8), const Offset(9, -3), p);
    c.drawLine(const Offset(9, -8), const Offset(4, -8), p);
    c.drawLine(const Offset(-9, 8), const Offset(-9, 3), p);
    c.drawLine(const Offset(-9, 8), const Offset(-4, 8), p);
    c.drawLine(const Offset(9, 8), const Offset(9, 3), p);
    c.drawLine(const Offset(9, 8), const Offset(4, 8), p);
    c.drawLine(const Offset(-6, 0), const Offset(6, 0), p);
  }

  @override
  bool shouldRepaint(covariant _FallingStationeryPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}
