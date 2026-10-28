import 'package:desksuite/app/section_artwork.dart';
import 'package:desksuite/workspace/getting_started_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

void main() {
  testWidgets('guide card artwork matches its actual action', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GettingStartedPage(
            onScan: () => opened = 'scan',
            onPhoto: () => opened = 'photo',
            onText: () => opened = 'text',
            onOffice: () => opened = 'office',
            onEditableExample: () => opened = 'design',
          ),
        ),
      ),
    );
    final cases = <String, (String, String)>{
      'guide-extract-text': (SectionArt.text, 'text'),
      'guide-convert-office': (SectionArt.office, 'office'),
      'guide-clean-page': (SectionArt.scan, 'scan'),
      'guide-scan-pages': (SectionArt.scan, 'scan'),
      'guide-correct-page': (SectionArt.scan, 'scan'),
      'guide-clean-photo': (SectionArt.photo, 'photo'),
      'guide-resize-image': (SectionArt.photo, 'photo'),
      'guide-edit-design': (SectionArt.design, 'design'),
    };
    for (final entry in cases.entries) {
      final card = find.byKey(Key(entry.key));
      await reveal(tester, card);
      final illustration = find.descendant(
        of: card,
        matching: find.byType(SectionArtwork),
      );
      expect(illustration, findsOneWidget, reason: entry.key);
      expect(tester.widget<SectionArtwork>(illustration).asset, entry.value.$1);
      final button = find.descendant(
        of: card,
        matching: find.byType(OutlinedButton),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      expect(opened, entry.value.$2, reason: entry.key);
    }
    expect(tester.takeException(), isNull);
  });
}
