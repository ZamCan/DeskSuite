import 'dart:typed_data';

import 'package:desksuite/design/design_controller.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/design/geometry.dart';
import 'package:desksuite/design/template_catalog.dart';
import 'package:desksuite/printing/design_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DesignDocument sample() => DesignDocument(
    id: 'project_1',
    name: 'Poster',
    widthMm: 210,
    heightMm: 297,
    updatedAt: DateTime.utc(2026),
    elements: [
      DesignElement(
        id: 'text_1',
        kind: ElementKind.text,
        x: 10,
        y: 20,
        width: 80,
        height: 30,
        rotation: 15,
        text: 'Hello 世界',
        fontSizePt: 24,
        bold: true,
        textAlignment: TextAlignment.center,
      ),
      DesignElement(
        id: 'image_1',
        kind: ElementKind.image,
        x: 50,
        y: 80,
        width: 40,
        height: 20,
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    ],
  );

  test(
    'versioned project preserves geometry, ordering, text and embedded bytes',
    () {
      final original = sample();
      final restored = DesignDocument.decode(original.encode());
      expect(restored.widthMm, 210);
      expect(restored.elements.map((e) => e.id), ['text_1', 'image_1']);
      expect(restored.elements.first.text, 'Hello 世界');
      expect(restored.elements.first.rotation, 15);
      expect(restored.elements.first.bold, isTrue);
      expect(restored.elements.last.imageBytes, orderedEquals([1, 2, 3, 4]));
    },
  );

  test(
    'rejects invalid versions, dangerous identifiers and bad dimensions',
    () {
      final bytes = sample().encode();
      final badVersion = String.fromCharCodes(bytes)
          .replaceFirst('"version":1', '"version":99');
      expect(
        () => DesignDocument.decode(badVersion.codeUnits),
        throwsFormatException,
      );
      expect(() => sample().copyWith(id: '../escape'), throwsFormatException);
      expect(
        () => sample().copyWith(widthMm: double.nan),
        throwsFormatException,
      );
      expect(() => DesignDocument.decode([123]), throwsFormatException);
    },
  );

  test('poster exports offer only resolutions within the pixel budget', () {
    final a0 = DesignDocument.blank(name: 'A0 poster', widthMm: 841, heightMm: 1189);
    expect(exportDimensions(a0, 100).width, 3311);
    expect(() => exportDimensions(a0, 150), throwsFormatException);
    final banner = DesignDocument.blank(name: '48 by 72 banner', widthMm: 1219.2, heightMm: 1828.8);
    expect(exportDimensions(banner, 36).width, 1728);
    expect(() => exportDimensions(banner, 72), throwsFormatException);
  });

  test('rotated object hit testing uses document coordinates', () {
    final e = DesignElement(
      id: 'r',
      kind: ElementKind.rectangle,
      x: 0,
      y: 0,
      width: 40,
      height: 20,
      rotation: 90,
    );
    expect(containsPoint(e, const Offset(20, 25)), isTrue);
    expect(containsPoint(e, const Offset(38, 10)), isFalse);
    final handle = handlePosition(e);
    expect(handle.dx, closeTo(10, 0.00001));
    expect(handle.dy, closeTo(30, 0.00001));
  });

  test('drag, undo, redo and duplicate preserve independent snapshots', () {
    final controller = DesignController(sample());
    controller.beginGesture(const Offset(30, 30), handleRadiusMm: 2);
    expect(controller.selectedId, 'text_1');
    controller.updateGesture(const Offset(5, 7));
    controller.updateGesture(const Offset(3, 1));
    controller.endGesture();
    expect(controller.selected!.x, 18);
    expect(controller.selected!.y, 28);
    controller.undo();
    expect(controller.selected!.x, 10);
    controller.redo();
    expect(controller.selected!.x, 18);
    controller.duplicateSelected();
    expect(controller.document.elements.length, 3);
    expect(controller.document.elements.last.id, isNot('text_1'));
    controller.undo();
    expect(controller.document.elements.length, 2);
    controller.dispose();
  });

  test(
    'paper conversions and output limits are physical, not screen based',
    () {
      expect(mmToPoints(25.4), closeTo(72, 0.0001));
      expect(effectiveImageDpi(300, 150, 50.8, 25.4), closeTo(150, .0001));
      expect(mmToPixels(210, 300), 2480);
      expect(mmToPixels(297, 300), 3508);
      final size = exportDimensions(sample(), 300);
      expect(size.width, 2480);
      expect(size.height, 3508);
      expect(() => exportDimensions(sample(), 600), throwsFormatException);
    },
  );
  test(
    'rotated image resize preserves aspect ratio and the opposite corner',
    () {
      final image = DesignElement(
        id: 'image',
        kind: ElementKind.image,
        x: 10,
        y: 10,
        width: 80,
        height: 40,
        rotation: 90,
        imageBytes: Uint8List.fromList([1]),
      );
      final doc = sample().copyWith(elements: [image]);
      final controller = DesignController(doc);
      controller.select('image');
      final originalOpposite = const Offset(70, -10);
      controller.beginGesture(handlePosition(image), handleRadiusMm: 2);
      controller.updateGesture(const Offset(0, -20));
      controller.endGesture();
      final resized = controller.selected!;
      expect(resized.width / resized.height, closeTo(2, .0001));
      expect(resized.width, lessThan(80));
      final centre = Offset(
        resized.x + resized.width / 2,
        resized.y + resized.height / 2,
      );
      final opposite = centre + Offset(resized.height / 2, -resized.width / 2);
      expect((opposite - originalOpposite).distance, lessThan(.001));
      controller.undo();
      expect(controller.selected!.width, 80);
      controller.dispose();
    },
  );
  test('photo sheet slot replacement embeds image and removes its label', () {
    final definition = designTemplateDefinition(DesignTemplate.photoPrintSheet);
    final elements = buildDesignTemplateElements(
      definition.template,
      widthMm: definition.widthMm,
      heightMm: definition.heightMm,
    );
    final document = DesignDocument.blank(
      name: definition.label,
      widthMm: definition.widthMm,
      heightMm: definition.heightMm,
    ).copyWith(elements: elements);
    final controller = DesignController(document);
    addTearDown(controller.dispose);
    final slot = elements.firstWhere((element) =>
      element.kind == ElementKind.rectangle &&
      element.width == 35 && element.height == 45);
    controller.select(slot.id);
    final photo = DesignElement(
      id: 'photo_filled_test',
      kind: ElementKind.image,
      x: slot.x,
      y: slot.y,
      width: slot.width,
      height: slot.height,
      imageBytes: Uint8List.fromList([1, 2, 3]),
    );
    controller.replaceSelectedPhotoPlaceholder(photo);
    expect(controller.selectedId, photo.id);
    expect(controller.document.elements.where((e) => e.kind == ElementKind.image), hasLength(1));
    expect(controller.document.elements.where((e) =>
      e.kind == ElementKind.rectangle && e.width == 35 && e.height == 45), hasLength(19));
    expect(controller.document.elements.where((e) =>
      e.kind == ElementKind.text && e.text.contains('35 × 45 mm')), hasLength(19));
    final reopened = DesignDocument.decode(controller.document.encode());
    expect(reopened.elements.firstWhere((e) => e.id == photo.id).imageBytes, orderedEquals([1, 2, 3]));
    controller.undo();
    expect(controller.document.elements.where((e) =>
      e.kind == ElementKind.rectangle && e.width == 35 && e.height == 45), hasLength(20));
  });
}
