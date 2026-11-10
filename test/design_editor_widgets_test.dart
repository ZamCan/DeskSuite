import 'package:desksuite/design/design_controller.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/design/editor_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inspector controls visibility and opacity on the real layer', (
    tester,
  ) async {
    final document = DesignDocument(
      id: 'inspector_project',
      name: 'Inspector test',
      widthMm: 100,
      heightMm: 100,
      updatedAt: DateTime.utc(2026),
      elements: [
        DesignElement(
          id: 'shape_1',
          kind: ElementKind.rectangle,
          x: 10,
          y: 10,
          width: 30,
          height: 20,
        ),
      ],
    );
    final controller = DesignController(document)..select('shape_1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectInspector(
            controller: controller,
            onEditText: () {},
            onFillPhotoSlot: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Opacity'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '50%'));
    await tester.pump();
    expect(controller.selected!.opacity, 0.5);

    await tester.tap(find.byTooltip('Lock canvas movement'));
    await tester.pump();
    expect(controller.selected!.locked, isTrue);
    expect(find.byTooltip('Unlock canvas movement'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide object'));
    await tester.pump();
    expect(controller.selected!.visible, isFalse);
    expect(find.byTooltip('Show object'), findsOneWidget);
  });

  testWidgets('inspector aligns the real layer vertically on the page', (
    tester,
  ) async {
    final document = DesignDocument(
      id: 'align_project',
      name: 'Align test',
      widthMm: 100,
      heightMm: 100,
      updatedAt: DateTime.utc(2026),
      elements: [
        DesignElement(
          id: 'shape_1',
          kind: ElementKind.rectangle,
          x: 10,
          y: 10,
          width: 30,
          height: 20,
        ),
      ],
    );
    final controller = DesignController(document)..select('shape_1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectInspector(
            controller: controller,
            onEditText: () {},
            onFillPhotoSlot: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    Future<void> tapTool(String tooltip) async {
      final finder = find.byTooltip(tooltip);
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
    }

    await tapTool('Middle of page');
    expect(controller.selected!.y, closeTo(40, 0.0001));
    await tapTool('Align object bottom');
    expect(controller.selected!.y, closeTo(80, 0.0001));
    await tapTool('Align object top');
    expect(controller.selected!.y, 0);
    expect(controller.selected!.x, 10, reason: 'horizontal position kept');
  });
}
