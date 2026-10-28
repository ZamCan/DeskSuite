import 'package:desksuite/design/design_controller.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/design/editor_widgets.dart';
import 'package:desksuite/design/template_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ID photo area exposes the real fill action; ordinary shapes do not',
    (tester) async {
      final definition = designTemplateDefinition(DesignTemplate.memberCard);
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
      addTearDown(controller.dispose);
      final slot = document.elements.singleWhere(
        (e) => e.text == photoPlaceholderMarker,
      );
      controller.select(slot.id);
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ObjectInspector(
              controller: controller,
              onEditText: () {},
              onFillPhotoSlot: () => tapped = true,
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('fill-photo-slot')));
      expect(tapped, isTrue);
      final other = document.elements.firstWhere(
        (e) =>
            e.kind == ElementKind.rectangle && e.text != photoPlaceholderMarker,
      );
      controller.select(other.id);
      await tester.pump();
      expect(find.byKey(const Key('fill-photo-slot')), findsNothing);
    },
  );
}
