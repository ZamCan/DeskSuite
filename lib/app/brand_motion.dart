import 'dart:math' as math;

/// The scan frame makes one gentle zoom-in/zoom-out during a cold launch.
/// Inputs are clamped because rendering must never depend on an overshooting
/// animation curve. Reduced-motion users do not run the launch animation.
double brandScanFrameScale(double progress) {
  final t = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
  return 1 + .09 * math.sin(2 * math.pi * t);
}

/// The selected raster replaces the drawn construction near the end.
double brandArtworkReveal(double progress) {
  final t = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
  return ((t - .58) / .27).clamp(0.0, 1.0);
}
