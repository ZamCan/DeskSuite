import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/business/sale_receipt.dart';
import 'package:desksuite/printing/print_gateway.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:desksuite/main.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

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

/// Returns stock and sales without touching disk, so the widget test measures
/// the UI path only. Persistence is verified in test/sale_receipt_test.dart.
class FakeSalesRepository extends InventoryRepository {
  FakeSalesRepository()
    : super(LocalFileStore(() async => Directory.systemTemp));

  var _product = InventoryProduct(
    id: 'ab12',
    name: 'Blue pen',
    priceMinor: 12550,
    stock: 4,
    sold: 0,
  );
  var _sales = 0;

  @override
  Future<InventorySnapshot> load() async => InventorySnapshot([_product]);

  @override
  Future<List<SaleRecord>> loadSales() async => const [];

  @override
  Future<SaleOutcome> recordSale({required String id, int quantity = 1}) async {
    _product = _product.recordUnits(quantity);
    final sale = SaleRecord(
      number: ++_sales,
      productId: _product.id,
      productName: _product.name,
      quantity: quantity,
      unitPriceMinor: _product.priceMinor,
      soldAt: DateTime(2026, 10, 28, 9, 30),
    );
    return SaleOutcome(snapshot: InventorySnapshot([_product]), sale: sale);
  }
}

class CapturePrinter implements PrintGateway {
  Uint8List? bytes;
  String? name;
  double? widthMm;
  double? heightMm;

  @override
  Future<bool> printPdf({
    required Uint8List bytes,
    required String name,
    required double widthMm,
    required double heightMm,
  }) async {
    this.bytes = bytes;
    this.name = name;
    this.widthMm = widthMm;
    this.heightMm = heightMm;
    return true;
  }
}

/// Pumps real time until [done] is true. PDF rendering and font loading are real
/// asynchronous work that a fixed number of pump rounds races on slower machines.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (done()) return;
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  fail('Timed out after ${timeout.inSeconds}s waiting for the app.');
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
      final snapshot = await settledIo(
        tester,
        repo.load,
        label: 'the catalogue',
      );
      expect(snapshot.products.single.stock, 0);
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

  testWidgets('a sale can be printed as a real A5 receipt', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeSalesRepository();
    final printer = CapturePrinter();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessPage(
            repository: repo,
            printer: printer,
            shopName: 'Mussa Stationery',
          ),
        ),
      ),
    );
    await settleIo(tester);

    final sell = find.byTooltip('Record one unit sold');
    // The card sits below the fold on a 360x720 phone; ensureVisible alone does
    // not build a lazy list child that has never been laid out.
    await reveal(tester, sell);
    await tester.tap(sell);
    await settleIo(tester);

    expect(find.textContaining('Sale recorded'), findsOneWidget);
    expect(find.textContaining('TSh 125.50'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Receipt'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Receipt'));
    await waitUntil(tester, () => printer.bytes != null);
    expect(String.fromCharCodes(printer.bytes!.take(5)), '%PDF-');
    expect(printer.name, 'receipt-0001');
    expect(printer.widthMm, 148);
    expect(printer.heightMm, 210);
    expect(tester.takeException(), isNull);
  });
}
