import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand.dart';

/// The ZamCan mark: an interlocking D and S drawn on an ink tile.
///
/// [drawProgress] drives the "drawn for the first time" animation: the outline
/// is traced and the fill follows it. At 1 the tile is the finished logo and
/// costs a single paint.
class ZamCanMark extends StatelessWidget {
  const ZamCanMark({
    super.key,
    this.size = 38,
    this.tile = true,
    this.drawProgress = 1,
    this.background,
    this.foreground,
  });

  final double size;

  /// Whether to draw the rounded ink tile behind the mark.
  final bool tile;

  /// 0 = nothing drawn, 1 = finished mark.
  final double drawProgress;

  /// Overrides the tile colour (the boot screen keeps it flat on its own field).
  final Color? background;

  /// Overrides the D colour; the S always keeps the accent.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final brand = ZamCanColors.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tile ? (background ?? brand.tile) : Colors.transparent,
          borderRadius: BorderRadius.circular(size * .25),
        ),
        child: CustomPaint(
          painter: ZamCanMarkPainter(
            progress: drawProgress,
            body: foreground ?? brand.paper,
            accent: brand.accentSoft,
            tile: tile,
          ),
          isComplex: false,
        ),
      ),
    );
  }
}

/// Paints the mark. Kept public so the boot sequence and the golden-PNG test
/// draw exactly the same geometry as the sidebar and the launcher icon.
class ZamCanMarkPainter extends CustomPainter {
  const ZamCanMarkPainter({
    required this.progress,
    required this.body,
    required this.accent,
    this.tile = true,
    this.outlineWidth = 9,
  });

  final double progress;
  final Color body;
  final Color accent;
  final bool tile;

  /// Width of the traced guide line while the mark is being drawn.
  final double outlineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    if (t == 0) return;
    canvas.save();
    ZamCanGeometry.applyBox(canvas, size);

    final dPath = ZamCanGeometry.dPath;
    final sPath = ZamCanGeometry.sPath;
    // The D traces first, the S second, so the monogram reads as two letters
    // being written rather than a shape fading in.
    final dProgress = (t / .62).clamp(0.0, 1.0);
    final sProgress = ((t - .38) / .62).clamp(0.0, 1.0);

    // The outline is drawn first and stays crisp; the fill arrives once the
    // letter is complete, so a half-drawn frame reads as a pencil tracing
    // rather than a washed-out logo.
    final fillOpacity = ((t - .55) / .45).clamp(0.0, 1.0);
    if (fillOpacity > 0) {
      canvas.drawPath(
        dPath,
        Paint()..color = body.withValues(alpha: fillOpacity),
      );
      final sFill = ((sProgress - .35) / .65).clamp(0.0, 1.0);
      if (sFill > 0) {
        canvas.drawPath(
          sPath,
          Paint()..color = accent.withValues(alpha: sFill),
        );
        final creaseT = ((sProgress - .75) / .25).clamp(0.0, 1.0);
        if (creaseT > 0) {
          final crease = RRect.fromRectAndRadius(
            ZamCanGeometry.crease,
            const Radius.circular(ZamCanGeometry.creaseRadius),
          );
          canvas.drawRRect(
            crease,
            Paint()..color = accent.withValues(alpha: creaseT),
          );
        }
      }
    }

    // The drawn edge: a lighter guide that trails the fill while animating.
    if (t < 1) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = body;
      canvas.drawPath(ZamCanGeometry.trace(dPath, dProgress), outline);
      final sOutline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent;
      canvas.drawPath(ZamCanGeometry.trace(sPath, sProgress), sOutline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ZamCanMarkPainter old) =>
      old.progress != progress ||
      old.body != body ||
      old.accent != accent ||
      old.tile != tile;
}

/// The product wordmark: "DeskSuite" over "by ZamCan", set in the app's own
/// type rather than an image so it scales and localises.
class ZamCanWordmark extends StatelessWidget {
  const ZamCanWordmark({
    super.key,
    this.color,
    this.subtleColor,
    this.compact = false,
    this.opacity = 1,
  });

  final Color? color;
  final Color? subtleColor;
  final bool compact;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final brand = ZamCanColors.of(context);
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ZamCanBrand.product,
            style: (compact ? text.titleMedium : text.headlineSmall)?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
              color: color ?? brand.ink,
            ),
          ),
          Text(
            'BY ${ZamCanBrand.company.toUpperCase()}',
            style: text.labelSmall?.copyWith(
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: subtleColor ?? brand.accentDeep,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mark and wordmark side by side — the header used by the sidebar and the
/// onboarding screen, so both show one logo, not two variations.
class ZamCanLockup extends StatelessWidget {
  const ZamCanLockup({
    super.key,
    this.markSize = 38,
    this.compact = false,
    this.markColor,
    this.wordmarkColor,
  });

  final double markSize;
  final bool compact;
  final Color? markColor;
  final Color? wordmarkColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ZamCanMark(size: markSize),
      const SizedBox(width: 12),
      Flexible(
        child: ZamCanWordmark(
          compact: compact || markSize < 34,
          color: wordmarkColor,
        ),
      ),
    ],
  );
}

/// The scanning frame that plays around the mark on the boot screen: four
/// corner brackets that zoom in and out, with a scan line crossing them.
class ScanFramePainter extends CustomPainter {
  const ScanFramePainter({
    required this.phase,
    required this.color,
    this.lineColor,
  });

  /// 0–1 of one zoom cycle; values outside are wrapped by the caller.
  final double phase;
  final Color color;
  final Color? lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = .82 + .22 * (math.sin(phase * math.pi * 2) * .5 + .5);
    final side = size.shortestSide * zoom;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final bracket = side * .18;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, side * .022)
      ..strokeCap = StrokeCap.round
      ..color = color;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(dx * bracket, 0), paint);
      canvas.drawLine(origin, origin.translate(0, dy * bracket), paint);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);

    // The sweep: a soft band travelling top to bottom inside the frame.
    final travel = (phase * 2) % 1.0;
    final y = rect.top + rect.height * (.15 + travel * .7);
    final band = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (lineColor ?? color).withValues(alpha: 0),
              (lineColor ?? color).withValues(alpha: .45),
              (lineColor ?? color).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTWH(rect.left, y - side * .06, rect.width, side * .12),
          );
    canvas.drawRect(
      Rect.fromLTWH(rect.left, y - side * .06, rect.width, side * .12),
      band,
    );
  }

  @override
  bool shouldRepaint(covariant ScanFramePainter old) =>
      old.phase != phase || old.color != color;
}
