import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'design_document.dart';

/// Imported image decodes are shared by preview and export, and never fetched online.
const int maxDecodedImagePixels = 24000000;

class DesignImageCache {
  final Map<String, ui.Image> _images = {};
  final Map<String, Uint8List> _sources = {};
  Map<String, ui.Image> get images => Map.unmodifiable(_images);

  Future<void> sync(DesignDocument document) async {
    final ids = document.elements
        .where((e) => e.kind == ElementKind.image)
        .map((e) => e.id)
        .toSet();
    for (final id in _images.keys.where((id) => !ids.contains(id)).toList()) {
      final removed = _images.remove(id);
      _sources.remove(id);
      if (removed != null &&
          !_images.values.any((image) => identical(image, removed))) {
        removed.dispose();
      }
    }
    for (final element in document.elements) {
      if (element.kind != ElementKind.image ||
          _images.containsKey(element.id)) {
        continue;
      }
      // Duplicated image layers share one decode, including after a project is reopened.
      String? sharedId;
      for (final entry in _sources.entries) {
        if (identical(entry.value, element.imageBytes) ||
            listEquals(entry.value, element.imageBytes)) {
          sharedId = entry.key;
          break;
        }
      }
      if (sharedId != null) {
        _images[element.id] = _images[sharedId]!;
        _sources[element.id] = element.imageBytes!;
        continue;
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        element.imageBytes!,
      );
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width <= 0 ||
            descriptor.height <= 0 ||
            descriptor.width * descriptor.height > 20000000) {
          throw const FormatException('Image dimensions exceed 20 megapixels.');
        }
        final currentPixels = _images.values.toSet().fold<int>(
          0,
          (sum, image) => sum + image.width * image.height,
        );
        if (currentPixels + descriptor.width * descriptor.height >
            maxDecodedImagePixels) {
          throw const FormatException(
            'Combined image size exceeds the 24 megapixel safety limit.',
          );
        }
        codec = await descriptor.instantiateCodec();
        final frame = await codec.getNextFrame();
        _images[element.id] = frame.image;
        _sources[element.id] = element.imageBytes!;
      } finally {
        codec?.dispose();
        descriptor?.dispose();
        buffer.dispose();
      }
    }
  }

  void dispose() {
    for (final image in _images.values.toSet()) {
      image.dispose();
    }
    _images.clear();
    _sources.clear();
  }
}

/// One renderer is used for the editor, PNG and PDF. Geometry is in mm.
class DesignPainter extends CustomPainter {
  DesignPainter(this.document, this.images, {this.selectedId});
  final DesignDocument document;
  final Map<String, ui.Image> images;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / document.widthMm;
    final scaleY = size.height / document.heightMm;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.clipRect(Rect.fromLTWH(0, 0, document.widthMm, document.heightMm));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, document.widthMm, document.heightMm),
      Paint()..color = Color(document.backgroundColor),
    );
    for (final item in document.elements) {
      canvas.save();
      final center = Offset(item.x + item.width / 2, item.y + item.height / 2);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(item.rotation * math.pi / 180);
      canvas.translate(-center.dx, -center.dy);
      final bounds = Rect.fromLTWH(item.x, item.y, item.width, item.height);
      final color = Color(item.color)
          .withValues(alpha: Color(item.color).a * item.opacity);
      switch (item.kind) {
        case ElementKind.rectangle:
          canvas.drawRect(bounds, Paint()..color = color);
        case ElementKind.ellipse:
          canvas.drawOval(bounds, Paint()..color = color);
        case ElementKind.text:
          canvas.save();
          canvas.clipRect(bounds);
          final painter = TextPainter(
            text: TextSpan(
              text: item.text,
              style: TextStyle(
                color: color,
                fontSize: item.fontSizePt * 25.4 / 72,
                fontWeight: item.bold ? FontWeight.w700 : FontWeight.w400,
                height: 1.15,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: switch (item.textAlignment) {
              TextAlignment.left => TextAlign.left,
              TextAlignment.center => TextAlign.center,
              TextAlignment.right => TextAlign.right,
            },
          )..layout(minWidth: item.width, maxWidth: item.width);
          painter.paint(canvas, Offset(item.x, item.y));
          painter.dispose();
          canvas.restore();
        case ElementKind.image:
          final image = images[item.id];
          if (image != null) {
            canvas.saveLayer(
              bounds,
              Paint()..color = Colors.white.withValues(alpha: item.opacity),
            );
            paintImage(
              canvas: canvas,
              rect: bounds,
              image: image,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            );
            canvas.restore();
          } else {
            canvas.drawRect(bounds, Paint()..color = const Color(0xffe7e2da));
          }
      }
      if (item.id == selectedId) {
        final stroke = 1.5 / scaleX;
        final handle = 8 / scaleX;
        canvas.drawRect(
          bounds,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = const Color(0xffbe6348),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: bounds.bottomRight,
            width: handle,
            height: handle,
          ),
          Paint()..color = const Color(0xffbe6348),
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DesignPainter oldDelegate) => true;
}
