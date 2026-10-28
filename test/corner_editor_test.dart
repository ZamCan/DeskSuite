import 'dart:async';
import 'dart:typed_data';

import 'package:desksuite/document_scan/corner_editor.dart';
import 'package:desksuite/document_scan/scan_processor.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final image = Uint8List.fromList(
    img.encodePng(img.Image(width: 80, height: 100)),
  );
  final page = PhotoResult(image, 80, 100);
  const suggestion = ScanCorners(
    ScanPoint(.1, .1),
    ScanPoint(.9, .08),
    ScanPoint(.91, .9),
    ScanPoint(.08, .92),
  );

  Widget host(
    Future<ScanCorners?> Function(PhotoResult) suggest,
    void Function(ScanCorners?) complete,
  ) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          onPressed: () async {
            final result = await showDialog<ScanCorners>(
              context: context,
              builder: (_) => CornerEditor(photo: page, suggester: suggest),
            );
            complete(result);
          },
          child: const Text('Open corners'),
        ),
      ),
    ),
  );

  testWidgets('suggestion is reviewable and only returned on confirmation', (
    tester,
  ) async {
    ScanCorners? selected;
    var calls = 0;
    await tester.pumpWidget(
      host((photo) async {
        calls++;
        expect(photo.bytes, orderedEquals(image));
        return suggestion;
      }, (value) => selected = value),
    );
    await tester.tap(find.text('Open corners'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.byKey(const Key('suggest-corners')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      find.textContaining('Suggested corners are approximate'),
      findsOneWidget,
    );
    expect(selected, isNull);
    await tester.tap(find.byKey(const Key('apply-corners')));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(selected!.topLeft.x, .1);
    expect(selected!.bottomRight.y, .9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no suggestion leaves the manual editor usable', (tester) async {
    ScanCorners? selected;
    await tester.pumpWidget(
      host((_) async => null, (value) => selected = value),
    );
    await tester.tap(find.text('Open corners'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('suggest-corners')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No reliable suggestion'), findsOneWidget);
    await tester.tap(find.byKey(const Key('apply-corners')));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(selected!.topLeft.x, 0);
    expect(selected!.bottomRight.y, 1);
  });

  testWidgets('pending suggestion cannot apply and can be cancelled safely', (
    tester,
  ) async {
    final pending = Completer<ScanCorners?>();
    await tester.pumpWidget(host((_) => pending.future, (_) {}));
    await tester.tap(find.text('Open corners'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('suggest-corners')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('apply-corners')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    pending.complete(suggestion);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
