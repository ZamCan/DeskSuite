import 'dart:math' as math;

/// Scaling behavior for placing source content on an intended output medium.
enum PrintScalePolicy { fit, fillCrop, actualSize }

/// Printer/driver knowledge is deliberately tri-state: missing information is
/// not evidence that a capability is supported.
enum CapabilitySupport { supported, unsupported, unknown }

/// Physical output intent. This describes a page/canvas, not printer hardware.
class PrintMediaTarget {
  const PrintMediaTarget({
    required this.id,
    required this.label,
    required this.widthMm,
    required this.heightMm,
  });

  factory PrintMediaTarget.fromPreset({
    required String id,
    required ({String label, double widthMm, double heightMm}) preset,
  }) =>
      PrintMediaTarget(
        id: id,
        label: preset.label,
        widthMm: preset.widthMm,
        heightMm: preset.heightMm,
      );

  final String id;
  final String label;
  final double widthMm;
  final double heightMm;

  bool get isValid =>
      id.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      widthMm.isFinite &&
      heightMm.isFinite &&
      widthMm > 0 &&
      heightMm > 0;
}

/// Optional source physical dimensions. Null means physical scale is unknown.
class SourceGeometry {
  const SourceGeometry({this.widthMm, this.heightMm});

  final double? widthMm;
  final double? heightMm;

  bool get hasReliablePhysicalSize =>
      widthMm != null &&
      heightMm != null &&
      widthMm!.isFinite &&
      heightMm!.isFinite &&
      widthMm! > 0 &&
      heightMm! > 0;
}

/// Capability facts from the active print service/driver only. Defaults are
/// unknown; a paper catalog entry must never be used to imply hardware support.
class PrinterCapabilities {
  const PrinterCapabilities({
    this.mediaSizes = CapabilitySupport.unknown,
    this.color = CapabilitySupport.unknown,
    this.duplex = CapabilitySupport.unknown,
    this.borderless = CapabilitySupport.unknown,
    this.reportedMediaIds = const <String>{},
    this.serviceId,
    this.printerName,
    this.observedAt,
  });

  final CapabilitySupport mediaSizes;
  final CapabilitySupport color;
  final CapabilitySupport duplex;
  final CapabilitySupport borderless;
  final Set<String> reportedMediaIds;
  final String? serviceId;
  final String? printerName;
  final DateTime? observedAt;

  bool supportsMedia(PrintMediaTarget target) {
    if (mediaSizes != CapabilitySupport.supported) return false;
    return reportedMediaIds.contains(target.id);
  }
}

/// User-approved, reversible defaults for a class of print job. Persistence is
/// intentionally provided by the owning settings/repository layer.
class PrintProfile {
  const PrintProfile({
    required this.id,
    required this.label,
    required this.media,
    this.scalePolicy = PrintScalePolicy.fit,
    this.marginMm = 0,
    this.colorPreferred = true,
    this.duplexPreferred = false,
    this.printerServiceId,
  });

  final String id;
  final String label;
  final PrintMediaTarget media;
  final PrintScalePolicy scalePolicy;
  final double marginMm;
  final bool colorPreferred;
  final bool duplexPreferred;
  final String? printerServiceId;

  bool get isValid =>
      id.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      media.isValid &&
      marginMm.isFinite &&
      marginMm >= 0 &&
      marginMm * 2 < math.min(media.widthMm, media.heightMm);
}

/// Calculated placement in physical millimetres. Crop amounts are informational
/// and only meaningful for fillCrop; actual cropping must remain user-reviewable.
class PrintLayout {
  const PrintLayout({
    required this.widthMm,
    required this.heightMm,
    required this.scale,
    required this.offsetXmm,
    required this.offsetYmm,
    required this.cropXmm,
    required this.cropYmm,
  });

  final double widthMm;
  final double heightMm;
  final double scale;
  final double offsetXmm;
  final double offsetYmm;
  final double cropXmm;
  final double cropYmm;
}

class PrintJob {
  const PrintJob({
    required this.media,
    required this.sourceWidthMm,
    required this.sourceHeightMm,
    this.scalePolicy = PrintScalePolicy.fit,
    this.marginMm = 0,
  });

  final PrintMediaTarget media;
  final double sourceWidthMm;
  final double sourceHeightMm;
  final PrintScalePolicy scalePolicy;
  final double marginMm;

  bool get isValid =>
      media.isValid &&
      sourceWidthMm.isFinite &&
      sourceHeightMm.isFinite &&
      sourceWidthMm > 0 &&
      sourceHeightMm > 0 &&
      marginMm.isFinite &&
      marginMm >= 0 &&
      marginMm * 2 < media.widthMm &&
      marginMm * 2 < media.heightMm;

  /// Computes placement inside the requested margins. It never dispatches a
  /// print job or changes the original source.
  PrintLayout calculateLayout() {
    if (!isValid) {
      throw const FormatException('Invalid print-job geometry or margins.');
    }
    final availableWidth = media.widthMm - marginMm * 2;
    final availableHeight = media.heightMm - marginMm * 2;
    final scaleX = availableWidth / sourceWidthMm;
    final scaleY = availableHeight / sourceHeightMm;
    final scale = switch (scalePolicy) {
      PrintScalePolicy.fit => math.min(scaleX, scaleY),
      PrintScalePolicy.fillCrop => math.max(scaleX, scaleY),
      PrintScalePolicy.actualSize => 1.0,
    };
    final placedWidth = sourceWidthMm * scale;
    final placedHeight = sourceHeightMm * scale;
    return PrintLayout(
      widthMm: placedWidth,
      heightMm: placedHeight,
      scale: scale,
      offsetXmm: marginMm + (availableWidth - placedWidth) / 2,
      offsetYmm: marginMm + (availableHeight - placedHeight) / 2,
      cropXmm: math.max(0, (placedWidth - availableWidth) / 2),
      cropYmm: math.max(0, (placedHeight - availableHeight) / 2),
    );
  }
}
