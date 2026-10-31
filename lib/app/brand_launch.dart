import 'package:flutter/material.dart';

import 'theme.dart';

/// Short brand reveal over a restrained stationery-pattern background.
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
      duration: const Duration(milliseconds: 1250),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _visible = false);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _visible = false;
    } else {
      _controller.forward();
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
                  label: 'DeskSuite',
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _LaunchArtwork(
                      progress: _controller.value,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class StationeryWallpaper extends StatelessWidget {
  const StationeryWallpaper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: const _StationeryPatternPainter(),
        child: child,
      );
}

class _LaunchArtwork extends StatelessWidget {
  const _LaunchArtwork({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final markOpacity = Curves.easeOut.transform(
      (progress / .42).clamp(0.0, 1.0).toDouble(),
    );
    final nameOpacity = Curves.easeOut.transform(
      ((progress - .28) / .42).clamp(0.0, 1.0).toDouble(),
    );
    return ColoredBox(
      color: const Color(0xfff3efe7),
      child: StationeryWallpaper(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  key: const Key('brand-launch-artwork'),
                  opacity: markOpacity,
                  child: const BrandMark(size: 112),
                ),
                const SizedBox(height: 18),
                Opacity(
                  key: const Key('brand-launch-name'),
                  opacity: nameOpacity,
                  child: const Text(
                    'DeskSuite',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xff292721),
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StationeryPatternPainter extends CustomPainter {
  const _StationeryPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const motifs = <IconData>[
      Icons.edit_outlined,
      Icons.description_outlined,
      Icons.folder_outlined,
      Icons.photo_outlined,
      Icons.document_scanner_outlined,
      Icons.picture_as_pdf_outlined,
      Icons.print_outlined,
      Icons.draw_outlined,
      Icons.image_outlined,
      Icons.content_cut_outlined,
    ];
    const color = Color(0xff8c7868);
    const cellW = 104.0;
    const cellH = 112.0;
    var index = 0;
    for (double y = 28; y < size.height + cellH; y += cellH) {
      for (double x = 24; x < size.width + cellW; x += cellW) {
        final icon = motifs[index % motifs.length];
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: 23,
              color: color.withValues(alpha: .075),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(x + ((index % 2) * 28), y + ((index % 3) * 12));
        canvas.rotate(((index % 5) - 2) * .10);
        painter.paint(canvas, Offset.zero);
        canvas.restore();
        index++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StationeryPatternPainter oldDelegate) => false;
}
