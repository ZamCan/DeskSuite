import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/design/template_catalog.dart';

void main() {
  group('shared design template catalog', () {
    test('has stable unique IDs and labels', () {
      expect(
        designTemplateCatalog.map((item) => item.id).toSet().length,
        designTemplateCatalog.length,
      );
      expect(
        designTemplateCatalog.map((item) => item.label).toSet().length,
        designTemplateCatalog.length,
      );
      expect(designTemplateCatalog.length, greaterThanOrEqualTo(8));
      for (final definition in designTemplateCatalog) {
        expect(definition.id, isNotEmpty);
        expect(definition.schemaVersion, designTemplateCatalogVersion);
        expect(definition.source, isNotEmpty);
        expect(definition.license, isNotEmpty);
      }
    });

    test('every template creates bounded editable elements', () {
      for (final definition in designTemplateCatalog) {
        final elements = buildDesignTemplateElements(
          definition.template,
          widthMm: definition.widthMm,
          heightMm: definition.heightMm,
        );
        if (definition.template == DesignTemplate.blank) {
          expect(elements, isEmpty);
          continue;
        }
        expect(elements, isNotEmpty, reason: definition.id);
        expect(
          elements.map((element) => element.id).toSet().length,
          elements.length,
          reason: definition.id,
        );
        for (final element in elements) {
          expect(element.x, greaterThanOrEqualTo(0), reason: definition.id);
          expect(element.y, greaterThanOrEqualTo(0), reason: definition.id);
          expect(
            element.x + element.width,
            lessThanOrEqualTo(definition.widthMm + .01),
            reason: definition.id,
          );
          expect(
            element.y + element.height,
            lessThanOrEqualTo(definition.heightMm + .01),
            reason: definition.id,
          );
        }
      }
    });

    test('all layouts remain valid at narrow and wide custom canvas sizes', () {
      for (final definition in designTemplateCatalog) {
        for (final size in [(10.0, 10.0), (1200.0, 10.0), (10.0, 1200.0)]) {
          final elements = buildDesignTemplateElements(
            definition.template,
            widthMm: size.$1,
            heightMm: size.$2,
          );
          for (final element in elements) {
            expect(element.width, greaterThanOrEqualTo(1));
            expect(element.height, greaterThanOrEqualTo(1));
            expect(element.x, greaterThanOrEqualTo(0));
            expect(element.y, greaterThanOrEqualTo(0));
            expect(element.x + element.width, lessThanOrEqualTo(size.$1 + .01));
            expect(
              element.y + element.height,
              lessThanOrEqualTo(size.$2 + .01),
            );
          }
        }
      }
    });

    test('photo print sheet provides twenty editable placeholder slots', () {
      final definition = designTemplateDefinition(
        DesignTemplate.photoPrintSheet,
      );
      final elements = buildDesignTemplateElements(
        definition.template,
        widthMm: definition.widthMm,
        heightMm: definition.heightMm,
      );
      expect(
        elements.where((element) => element.kind == ElementKind.rectangle),
        hasLength(20),
      );
      expect(
        elements.where((element) => element.kind == ElementKind.text),
        hasLength(23),
      );
      expect(elements.length, lessThanOrEqualTo(maxDesignElements));
      expect(
        elements.where((element) => element.text.contains('35 × 45 mm')),
        hasLength(20),
      );
    });

    test('rejects non-finite or unsupported canvas dimensions', () {
      expect(
        () => buildDesignTemplateElements(
          DesignTemplate.flyer,
          widthMm: double.infinity,
          heightMm: 297,
        ),
        throwsFormatException,
      );
      expect(
        () => buildDesignTemplateElements(
          DesignTemplate.flyer,
          widthMm: 9,
          heightMm: 297,
        ),
        throwsFormatException,
      );
    });

    test('template output round-trips through the shared project format', () {
      final definition = designTemplateDefinition(DesignTemplate.identityBadge);
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
      final decoded = DesignDocument.decode(document.encode());
      expect(decoded.name, definition.label);
      expect(decoded.elements.length, document.elements.length);
      expect(
        decoded.elements.map((element) => element.kind).toList(),
        document.elements.map((element) => element.kind).toList(),
      );
    });
  });
}
