import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/design/template_catalog.dart';
import 'package:desksuite/printing/paper_catalog.dart';
import 'package:desksuite/workspace/new_design_dialog.dart';

void main() {
  testWidgets('pre-tutorial design flow offers a clean blank canvas only', (
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

    final picker = tester.widget<DropdownButtonFormField<DesignTemplate>>(
      find.byKey(const Key('design-template-picker')),
    );
    expect(picker.initialValue, DesignTemplate.blank);
    await tester.tap(find.byKey(const Key('design-template-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Blank canvas'), findsWidgets);
    expect(find.text('Staff ID badge'), findsNothing);
    expect(find.text('Editorial poster'), findsNothing);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('YOUR BRAND'), findsNothing);
    expect(find.textContaining('EXAMPLE'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('project-name')),
      'My first design',
    );
    await tester.tap(find.byKey(const Key('create-design')));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.name, 'My first design');
    expect(created!.widthMm, 210);
    expect(created!.heightMm, 297);
    expect(created!.elements, isEmpty);
    expect(paperSheetPresets, isNotEmpty);
  });
}
