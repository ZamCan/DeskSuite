import 'dart:math' as math;
import 'dart:typed_data';

/// An approximate suggestion in clockwise order, starting at top-left.
/// Coordinates range from 0 to 1; callers must let the user review them.
class PageCornerSuggestion {
  const PageCornerSuggestion(this.points);
  final List<math.Point<double>> points;
}

const int _maxSuggestionSide = 512;

/// Tries to find a bright, approximately quadrilateral page on a darker,
/// contrasting background. [rgba] must be a bounded thumbnail, not the full
/// photograph. It is never mutated. Returns null when the heuristic cannot
/// support a suggestion; a positive result can still be wrong.
///
/// This is not document classification: a bright rectangular object may be
/// suggested. The caller must display the result and require manual review.
PageCornerSuggestion? suggestPageCornersRgba(
  Uint8List rgba,
  int width,
  int height,
) {
  if (width < 1 ||
      height < 1 ||
      width > _maxSuggestionSide ||
      height > _maxSuggestionSide ||
      rgba.length != width * height * 4) {
    throw const FormatException('Invalid page-suggestion thumbnail.');
  }
  if (width < 16 || height < 16) return null;

  final size = width * height;
  final luma = Uint8List(size);
  final histogram = Uint32List(256);
  for (var i = 0; i < size; i++) {
    final offset = i * 4;
    final value =
        (77 * rgba[offset] + 150 * rgba[offset + 1] + 29 * rgba[offset + 2]) >>
        8;
    final alpha = rgba[offset + 3];
    final flattened = (value * alpha + 255 * (255 - alpha) + 127) ~/ 255;
    luma[i] = flattened;
    histogram[flattened]++;
  }
  int percentile(int numerator) {
    final target = (size * numerator + 99) ~/ 100;
    var count = 0;
    for (var i = 0; i < 256; i++) {
      count += histogram[i];
      if (count >= target) return i;
    }
    return 255;
  }

  final low = percentile(10), high = percentile(90);
  if (high - low < 30) return null;
  final thresholds = <int>{
    _otsu(histogram, size),
    for (final fraction in [.12, .20, .30, .40, .50])
      (low + (high - low) * fraction).round(),
  };
  final queue = Int32List(size);
  _Candidate? best;
  for (final threshold in thresholds) {
    final visited = Uint8List(size);
    for (var start = 0; start < size; start++) {
      if (visited[start] != 0 || luma[start] <= threshold) continue;
      var head = 0, tail = 0;
      queue[tail++] = start;
      visited[start] = 1;
      var minX = width, minY = height, maxX = -1, maxY = -1;
      var minSum = width + height, maxSum = -1;
      var minDiff = width, maxDiff = -height;
      var topLeft = start,
          topRight = start,
          bottomRight = start,
          bottomLeft = start;
      while (head < tail) {
        final index = queue[head++];
        final x = index % width, y = index ~/ width;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        final sum = x + y, diff = x - y;
        if (sum < minSum) {
          minSum = sum;
          topLeft = index;
        }
        if (diff > maxDiff) {
          maxDiff = diff;
          topRight = index;
        }
        if (sum > maxSum) {
          maxSum = sum;
          bottomRight = index;
        }
        if (diff < minDiff) {
          minDiff = diff;
          bottomLeft = index;
        }
        if (x > 0) {
          final next = index - 1;
          if (visited[next] == 0 && luma[next] > threshold) {
            visited[next] = 1;
            queue[tail++] = next;
          }
        }
        if (x + 1 < width) {
          final next = index + 1;
          if (visited[next] == 0 && luma[next] > threshold) {
            visited[next] = 1;
            queue[tail++] = next;
          }
        }
        if (y > 0) {
          final next = index - width;
          if (visited[next] == 0 && luma[next] > threshold) {
            visited[next] = 1;
            queue[tail++] = next;
          }
        }
        if (y + 1 < height) {
          final next = index + width;
          if (visited[next] == 0 && luma[next] > threshold) {
            visited[next] = 1;
            queue[tail++] = next;
          }
        }
      }
      // Cropped or edge-touching pages cannot be inferred reliably. Small
      // regions are typically noise, text or unrelated objects.
      if (tail < size * .08 ||
          tail > size * .90 ||
          minX < 2 ||
          minY < 2 ||
          maxX >= width - 2 ||
          maxY >= height - 2) {
        continue;
      }
      final indices = [topLeft, topRight, bottomRight, bottomLeft];
      if (indices.toSet().length != 4) continue;
      final points = [
        for (final index in indices)
          math.Point<double>(
            (index % width).toDouble(),
            (index ~/ width).toDouble(),
          ),
      ];
      final candidate = _scoreCandidate(points, tail, luma, width, height);
      if (candidate != null && (best == null || candidate.score > best.score)) {
        best = candidate;
      }
    }
  }
  if (best == null) return null;
  return PageCornerSuggestion([
    for (final point in best.points)
      math.Point(point.x / (width - 1), point.y / (height - 1)),
  ]);
}

int _otsu(Uint32List histogram, int count) {
  var total = 0;
  for (var i = 0; i < 256; i++) {
    total += i * histogram[i];
  }
  var lowCount = 0, lowTotal = 0, threshold = 0;
  var best = -1.0;
  for (var i = 0; i < 256; i++) {
    lowCount += histogram[i];
    lowTotal += i * histogram[i];
    final highCount = count - lowCount;
    if (lowCount == 0 || highCount == 0) continue;
    final difference = lowTotal / lowCount - (total - lowTotal) / highCount;
    final score = lowCount.toDouble() * highCount * difference * difference;
    if (score > best) {
      best = score;
      threshold = i;
    }
  }
  return threshold;
}

class _Candidate {
  const _Candidate(this.points, this.score);
  final List<math.Point<double>> points;
  final double score;
}

_Candidate? _scoreCandidate(
  List<math.Point<double>> points,
  int count,
  Uint8List luma,
  int width,
  int height,
) {
  var twiceArea = 0.0;
  for (var i = 0; i < 4; i++) {
    final a = points[i], b = points[(i + 1) % 4], c = points[(i + 2) % 4];
    final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (cross <= 1) return null;
    twiceArea += a.x * b.y - b.x * a.y;
  }
  final area = twiceArea / 2;
  if (area < width * height * .08 || area > width * height * .90) return null;
  final fill = count / area;
  if (fill < .68 || fill > 1.18) return null;

  // A real boundary should usually be brighter just inside than outside.
  // Test each edge, not just the mean, to reject a threshold contour cutting
  // across a smooth shadow. A suggestion is still not a guarantee.
  const samplesPerEdge = 12;
  var good = 0, contrastTotal = 0.0;
  for (var edge = 0; edge < 4; edge++) {
    final a = points[edge], b = points[(edge + 1) % 4];
    final dx = b.x - a.x, dy = b.y - a.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 12) return null;
    final nx = -dy / length, ny = dx / length;
    var edgeGood = 0;
    for (var i = 0; i < samplesPerEdge; i++) {
      final t = (i + 1) / (samplesPerEdge + 1);
      final x = a.x + t * dx, y = a.y + t * dy;
      final insideX = (x + nx * 4).round().clamp(0, width - 1);
      final insideY = (y + ny * 4).round().clamp(0, height - 1);
      final outsideX = (x - nx * 4).round().clamp(0, width - 1);
      final outsideY = (y - ny * 4).round().clamp(0, height - 1);
      final difference =
          luma[insideY * width + insideX] - luma[outsideY * width + outsideX];
      if (difference >= 12) {
        edgeGood++;
        good++;
      }
      contrastTotal += difference.clamp(0, 100);
    }
    if (edgeGood < samplesPerEdge ~/ 2) return null;
  }
  if (good < samplesPerEdge * 4 * .70) return null;
  final edgeQuality = good / (samplesPerEdge * 4);
  final contrast = contrastTotal / (samplesPerEdge * 4 * 100);
  final areaFraction = area / (width * height);
  return _Candidate(
    points,
    edgeQuality * .5 + contrast * .25 + areaFraction * .25,
  );
}
