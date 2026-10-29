import 'dart:typed_data';

import 'package:desksuite/office/office_format.dart';
import 'package:desksuite/office/office_preview_page.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'experimental preview is disabled by default and format list is explicit',
    () {
      // Run this test without the experimental dart-define.
      expect(officePreviewEnabled, isFalse);
      for (final format in [
        OfficeFormat.doc,
        OfficeFormat.docx,
        OfficeFormat.xls,
        OfficeFormat.xlsx,
        OfficeFormat.ppt,
        OfficeFormat.pptx,
        OfficeFormat.odt,
        OfficeFormat.ods,
        OfficeFormat.odp,
        OfficeFormat.ole,
      ]) {
        expect(canPreviewOfficeFormat(format), isTrue, reason: format.label);
      }
      expect(canPreviewOfficeFormat(OfficeFormat.pdf), isFalse);
      expect(canPreviewOfficeFormat(OfficeFormat.rtf), isFalse);
    },
  );

  testWidgets(
    'unsupported platforms fail closed rather than showing a fake preview',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      // Widget-test invariants run before addTearDown. Reset the foundation
      // override inside the test body even if an assertion fails.
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: OfficePreviewPage(
              source: Uint8List(1),
              sourceName: 'file.docx',
            ),
          ),
        );
        expect(find.byType(AndroidView), findsNothing);
        expect(find.textContaining('available on Android'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
