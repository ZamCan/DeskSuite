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
      expect(designTemplateCatalog.length, greaterThanOrEqualTo(7));
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

    test('template output round-trips through the shared project format', () {
      final definition = designTemplateDefinition(DesignTemplate.identityBadge);
      final document = DesignDocument.blank(
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
