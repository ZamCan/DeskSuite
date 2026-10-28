import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/printing/paper_catalog.dart';
import 'package:desksuite/workspace/new_design_dialog.dart';

void main() {
  testWidgets('selecting a template creates an editable design', (
    tester,
  ) async {
    DesignDocument? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                created = await showDialog<DesignDocument>(
                  context: context,
                  builder: (_) => const NewDesignDialog(),
                );
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('design-template-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business card').last);
    await tester.pumpAndSettle();
    // A template's dimensions are custom, not the last paper preset.
    expect(find.byKey(ValueKey(paperSheetPresets.length)), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('canvas-width')))
          .controller!
          .text,
      '85.0',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('canvas-height')))
          .controller!
          .text,
      '55.0',
    );

    await tester.ensureVisible(find.byKey(const Key('canvas-width')));
    await tester.enterText(find.byKey(const Key('canvas-width')), '86');
    await tester.enterText(find.byKey(const Key('canvas-height')), '57');
    await tester.pump();
    expect(find.byKey(ValueKey(paperSheetPresets.length)), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-design')));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.widthMm, 86);
    expect(created!.heightMm, 57);
    expect(created!.elements, isNotEmpty);
    expect(
      created!.elements.any((element) => element.text == 'YOUR BRAND'),
      isTrue,
    );
  });
}
