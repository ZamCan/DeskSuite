import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:desksuite/main.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CaptureFiles implements FileGateway {
  Uint8List? bytes;
  String? name;
  @override
  Future<Uint8List?> pickImage() async => null;
  @override
  Future<Uint8List?> pickProject() async => null;
  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    this.bytes = bytes;
    this.name = name;
    return true;
  }
}

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets(
    'product form and stock counter persist without pretending to take payment',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('desksuite_inventory_ui_'),
      ))!;
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final repo = InventoryRepository(LocalFileStore(() async => dir));
      final files = CaptureFiles();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusinessPage(repository: repo, files: files),
          ),
        ),
      );
      await settleIo(tester);
      await tester.ensureVisible(find.byKey(const Key('add-product')));
      await tester.tap(find.byKey(const Key('add-product')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('product-name')), 'Blue pen');
      await tester.enterText(find.byKey(const Key('product-price')), '125.50');
      await tester.enterText(find.byKey(const Key('product-stock')), '1');
      await tester.tap(find.text('Add'));
      await settleIo(tester);
      expect(find.text('Blue pen'), findsOneWidget);
      final sell = find.byTooltip('Record one unit sold');
      await tester.ensureVisible(sell);
      await tester.tap(sell);
      await settleIo(tester);
      final snapshot = await tester.runAsync(repo.load);
      expect(snapshot!.products.single.stock, 0);
      expect(snapshot.products.single.sold, 1);
      final sellButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Record one unit sold',
      );
      expect(tester.widget<IconButton>(sellButton).onPressed, isNull);
      await tester.ensureVisible(find.byKey(const Key('export-catalogue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-catalogue')));
      await settleIo(tester);
      expect(files.name, 'desksuite-products.json');
      expect(
        (jsonDecode(utf8.decode(files.bytes!)) as List).single['name'],
        'Blue pen',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a damaged catalogue is reported instead of silently replaced', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('desksuite_inventory_corrupt_'),
    ))!;
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = File('${dir.path}/products.json');
    await tester.runAsync(() => file.writeAsString('{broken'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessPage(
            repository: InventoryRepository(LocalFileStore(() async => dir)),
          ),
        ),
      ),
    );
    await settleIo(tester);
    expect(
      find.textContaining('original file has not been changed'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add-product')), findsNothing);
    expect(await tester.runAsync(() => file.readAsString()), '{broken');
  });
}
