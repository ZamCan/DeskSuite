import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import '../images/photo_processor.dart';
import 'page_corner_pixels.dart';
import 'scan_processor.dart';

/// Decode and suggest on a worker isolate; never crops or edits the page.
Future<ScanCorners?> suggestScanCornersInBackground(PhotoResult page) =>
    compute(suggestScanCorners, page.bytes);

/// Conservative bright-page heuristic. A null result means manual adjustment
/// remains available; a returned result must still be reviewed by the user.
ScanCorners? suggestScanCorners(Uint8List encoded) {
  final source = decodeBoundedPhoto(encoded, byteLimit: maxPhotoWorkingBytes);
  final scale = math.min(1.0, 512 / math.max(source.width, source.height));
  final thumbnail = img
      .copyResize(
        source,
        width: math.max(1, (source.width * scale).round()),
        height: math.max(1, (source.height * scale).round()),
        interpolation: img.Interpolation.average,
      )
      .convert(format: img.Format.uint8, numChannels: 4, noAnimation: true);
  final suggestion = suggestPageCornersRgba(
    thumbnail.toUint8List(),
    thumbnail.width,
    thumbnail.height,
  );
  if (suggestion == null) return null;
  final p = suggestion.points;
  final corners = ScanCorners(
    ScanPoint(p[0].x, p[0].y),
    ScanPoint(p[1].x, p[1].y),
    ScanPoint(p[2].x, p[2].y),
    ScanPoint(p[3].x, p[3].y),
  );
  try {
    corners.validate();
    return corners;
  } on FormatException {
    return null;
  }
}
