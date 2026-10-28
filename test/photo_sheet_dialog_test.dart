import 'dart:typed_data';

import 'package:desksuite/images/photo_processor.dart';
import 'package:desksuite/printing/photo_sheet_dialog.dart';
import 'package:desksuite/printing/photo_specifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  testWidgets(
    'default sheet is usable and unknown official dimensions are blank',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 8, height: 10)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoSheetDialog(photo: PhotoResult(png, 8, 10)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, 'Export PDF');
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(find.textContaining('4 fit on this page'), findsOneWidget);
      final dropdown = find.byKey(
        ValueKey('photo-size-$customPhotoSpecificationIndex'),
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tanzania · passport application').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('sheet-photo-width')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('sheet-photo-height')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        find.textContaining('Enter the required finished photo width'),
        findsOneWidget,
      );
    },
  );
}
