import 'dart:math' as math;
import 'dart:ui';

import 'design_document.dart';

const double millimetresPerInch = 25.4;
const double pointsPerInch = 72;

double mmToPoints(double mm) => mm * pointsPerInch / millimetresPerInch;
int mmToPixels(double mm, int dpi) => (mm * dpi / millimetresPerInch).round();

/// Hit tests a point in the document's physical coordinate space.
bool containsPoint(DesignElement element, Offset point) {
  final centre = Offset(
    element.x + element.width / 2,
    element.y + element.height / 2,
  );
  final theta = -element.rotation * math.pi / 180;
  final delta = point - centre;
  final local = Offset(
    delta.dx * math.cos(theta) - delta.dy * math.sin(theta),
    delta.dx * math.sin(theta) + delta.dy * math.cos(theta),
  );
  return local.dx.abs() <= element.width / 2 &&
      local.dy.abs() <= element.height / 2;
}

Offset handlePosition(DesignElement element) {
  final centre = Offset(
    element.x + element.width / 2,
    element.y + element.height / 2,
  );
  final theta = element.rotation * math.pi / 180;
  final dx = element.width / 2;
  final dy = element.height / 2;
  return centre +
      Offset(
        dx * math.cos(theta) - dy * math.sin(theta),
        dx * math.sin(theta) + dy * math.cos(theta),
      );
}
