import 'dart:typed_data';

import 'package:desksuite/document_scan/document_cleanup.dart';
import 'package:desksuite/document_scan/document_cleanup_dialog.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = img.Image(width: 80, height: 60, numChannels: 4);
  img.fill(source, color: img.ColorRgba8(120, 120, 120, 255));
  final page = PhotoResult(Uint8List.fromList(img.encodePng(source)), 80, 60);

  Widget app({required bool fail, required double scale}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          onPressed: () => showDialog<PhotoResult>(
            context: context,
            builder: (_) => DocumentCleanupDialog(
              page: page,
              processor: (request) async {
                if (fail) throw const FormatException('Preview failed safely.');
                return processDocumentCleanup(request);
              },
            ),
          ),
          child: const Text('Open cleanup'),
        ),
      ),
    ),
  );

  testWidgets('landscape large text leaves preview and apply controls usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(fail: false, scale: 1.8));
    await tester.tap(find.text('Open cleanup'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('cleanup-use')))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byKey(const Key('cleanup-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cleanup-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cleanup-after-image')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('cleanup-use')))
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.byKey(const Key('cleanup-amount')));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('cleanup-amount'))) +
          const Offset(40, 20),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('cleanup-use')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview failure is visible and cannot apply a result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(fail: true, scale: 1.5));
    await tester.tap(find.text('Open cleanup'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cleanup-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cleanup-preview')));
    await tester.pumpAndSettle();
    expect(find.text('Preview failed safely.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('cleanup-use')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('cleanup-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Open cleanup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
