import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:desksuite/design/design_controller.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/design/template_catalog.dart';

void main() {
  Uint8List samplePng() {
    final image = img.Image(width: 8, height: 10);
    img.fill(image, color: img.ColorRgb8(180, 90, 70));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('filling a photo slot replaces its label and is undoable', () {
    final definition = designTemplateDefinition(DesignTemplate.photoPrintSheet);
    final document =
        DesignDocument.blank(
          name: definition.label,
          widthMm: definition.widthMm,
          heightMm: definition.heightMm,
        ).copyWith(
          elements: buildDesignTemplateElements(
            definition.template,
            widthMm: definition.widthMm,
            heightMm: definition.heightMm,
          ),
        );
    final controller = DesignController(document);
    final slot = document.elements.firstWhere(
      (element) =>
          element.kind == ElementKind.rectangle &&
          element.width == 35 &&
          element.height == 45,
    );
    controller.select(slot.id);
    final image = DesignElement(
      id: 'filled-photo-slot-test',
      kind: ElementKind.image,
      x: slot.x,
      y: slot.y,
      width: slot.width,
      height: slot.height,
      imageBytes: samplePng(),
    );

    controller.replaceSelectedPhotoPlaceholder(image);

    expect(controller.selectedId, image.id);
    expect(
      controller.document.elements.where(
        (element) =>
            element.kind == ElementKind.image && element.id == image.id,
      ),
      hasLength(1),
    );
    expect(
      controller.document.elements.where(
        (element) =>
            element.kind == ElementKind.text &&
            element.text.contains('35 × 45 mm') &&
            element.x >= slot.x &&
            element.x < slot.x + slot.width &&
            element.y >= slot.y &&
            element.y < slot.y + slot.height,
      ),
      isEmpty,
    );
    expect(
      controller.document.elements.where(
        (element) =>
            element.kind == ElementKind.rectangle && element.id == slot.id,
      ),
      isEmpty,
    );
    final reopened = DesignDocument.decode(controller.document.encode());
    expect(
      reopened.elements
          .firstWhere((element) => element.id == image.id)
          .imageBytes,
      orderedEquals(image.imageBytes!),
    );

    controller.undo();
    expect(
      controller.document.elements.any((element) => element.id == slot.id),
      isTrue,
    );
    expect(
      controller.document.elements.where(
        (element) =>
            element.kind == ElementKind.text &&
            element.text.contains('35 × 45 mm') &&
            element.x >= slot.x &&
            element.x < slot.x + slot.width &&
            element.y >= slot.y &&
            element.y < slot.y + slot.height,
      ),
      hasLength(1),
    );
    controller.dispose();
  });

  test('staff, member and event slots survive project round-trip and undo', () {
    for (final template in [
      DesignTemplate.identityBadge,
      DesignTemplate.memberCard,
      DesignTemplate.eventBadge,
    ]) {
      final definition = designTemplateDefinition(template);
      final original =
          DesignDocument.blank(
            name: definition.label,
            widthMm: definition.widthMm,
            heightMm: definition.heightMm,
          ).copyWith(
            elements: buildDesignTemplateElements(
              template,
              widthMm: definition.widthMm,
              heightMm: definition.heightMm,
            ),
          );
      final reopened = DesignDocument.decode(original.encode());
      final slot = reopened.elements.singleWhere(
        (element) => element.text == photoPlaceholderMarker,
      );
      // Even a legacy-looking overlapping label belongs to the user and must
      // not be deleted when a modern marked slot is filled.
      final unrelated = DesignElement(
        id: 'unrelated-label',
        kind: ElementKind.text,
        x: slot.x,
        y: slot.y,
        width: 4,
        height: 4,
        text: '35 × 45 mm — unrelated artwork',
      );
      final controller = DesignController(
        reopened.copyWith(elements: [...reopened.elements, unrelated]),
      );
      controller.select(slot.id);
      expect(controller.canFillSelectedPhotoPlaceholder, isTrue);
      final photo = DesignElement(
        id: 'id-photo',
        kind: ElementKind.image,
        x: slot.x,
        y: slot.y,
        width: slot.width,
        height: slot.height,
        imageBytes: samplePng(),
      );
      controller.replaceSelectedPhotoPlaceholder(photo);
      expect(
        controller.document.elements.any((e) => e.id == unrelated.id),
        isTrue,
      );
      expect(controller.document.elements.any((e) => e.id == photo.id), isTrue);
      expect(
        DesignDocument.decode(controller.document.encode()).elements
            .singleWhere((e) => e.id == photo.id)
            .imageBytes,
        orderedEquals(photo.imageBytes!),
      );
      controller.undo();
      expect(controller.document.elements.any((e) => e.id == slot.id), isTrue);
      expect(
        controller.document.elements.any((e) => e.id == unrelated.id),
        isTrue,
      );
      controller.redo();
      expect(controller.document.elements.any((e) => e.id == photo.id), isTrue);
      controller.dispose();
    }
  });

  test('rejects a regular rectangle instead of deleting unrelated artwork', () {
    final document = DesignDocument.blank(
      name: 'Test',
      widthMm: 100,
      heightMm: 100,
    );
    final controller = DesignController(document);
    final rectangle = DesignElement(
      id: 'ordinary-rectangle',
      kind: ElementKind.rectangle,
      x: 10,
      y: 10,
      width: 35,
      height: 45,
    );
    controller.add(rectangle);
    expect(
      () => controller.replaceSelectedPhotoPlaceholder(
        DesignElement(
          id: 'photo-image',
          kind: ElementKind.image,
          x: 10,
          y: 10,
          width: 35,
          height: 45,
          imageBytes: samplePng(),
        ),
      ),
      throwsStateError,
    );
    expect(controller.document.elements.single.id, rectangle.id);
    controller.dispose();
  });
}
