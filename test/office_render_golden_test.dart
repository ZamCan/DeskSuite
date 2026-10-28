import 'dart:io';

import 'package:desksuite/app/theme.dart';
import 'package:flutter/services.dart';

import 'package:desksuite/office/render/office_preview.dart';
import 'package:desksuite/office/render/pptx_layout.dart';
import 'package:desksuite/office/render/xlsx_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the fixtures through the real viewers. These goldens are the
/// evidence that a `.pptx` is drawn as a slide with positioned shapes and a
/// picture, and an `.xlsx` as a formatted grid — not as a pile of text.
/// The test binding draws every glyph as a box unless a real font is loaded,
/// which would make the goldens useless as evidence.
Future<void> _loadFonts() async {
  final loader = FontLoader('DeskSuiteSans');
  for (final file in [
    'assets/fonts/NotoSans-Regular.ttf',
    'assets/fonts/NotoSans-Bold.ttf',
  ]) {
    final bytes = File(file).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Widget _app(Widget child) => MaterialApp(
  // The real app theme, so the golden shows the app's own typeface.
  theme: deskTheme(Brightness.light),
  home: Scaffold(body: child),
);

void main() {
  setUpAll(_loadFonts);

  testWidgets('a pptx renders as a positioned slide', (tester) async {
    tester.view.physicalSize = const Size(900, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final deck = parsePptx(
      Uint8List.fromList(
        File('test/fixtures/office/deck.pptx').readAsBytesSync(),
      ),
    );
    await tester.pumpWidget(
      _app(SizedBox(width: 900, height: 700, child: PptxViewer(deck: deck))),
    );
    // Let the picture decode through the real codec.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(find.byKey(const Key('slide-0')), findsOneWidget);
    expect(find.text('Slide 1 of 2'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('slide-0')),
      matchesGoldenFile('goldens/pptx-slide-1.png'),
    );
  });

  testWidgets('an xlsx renders as a formatted grid', (tester) async {
    tester.view.physicalSize = const Size(900, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final book = parseXlsx(
      Uint8List.fromList(
        File('test/fixtures/office/ledger.xlsx').readAsBytesSync(),
      ),
    );
    await tester.pumpWidget(
      _app(SizedBox(width: 900, height: 700, child: XlsxViewer(book: book))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('sheet-Sales')), findsOneWidget);
    await expectLater(
      find.byKey(const Key('sheet-Sales')),
      matchesGoldenFile('goldens/xlsx-sheet.png'),
    );
  });

  testWidgets('the slide pager moves between slides', (tester) async {
    final deck = parsePptx(
      Uint8List.fromList(
        File('test/fixtures/office/deck.pptx').readAsBytesSync(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PptxViewer(deck: deck)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('slide-next')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Slide 2 of 2'), findsOneWidget);
    expect(find.byKey(const Key('slide-next')), findsOneWidget);
    // The last slide disables "next" rather than wrapping around silently.
    final next = tester.widget<IconButton>(find.byKey(const Key('slide-next')));
    expect(next.onPressed, isNull);
  });
}
