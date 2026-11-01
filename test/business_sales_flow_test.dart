import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/business/business_settings.dart';
import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/business/sale_receipt.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:desksuite/legacy_studios.dart';
import 'package:desksuite/printing/print_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reveal.dart';

/// Pumps real time until [done] is true, for real IO and PDF rendering work
/// that a fixed number of pump rounds would race.
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

/// Fake inventory repository: the stocks and tiers behave like the real
/// model, but nothing is written to disk from the widget test.
class _BasketRepository extends InventoryRepository {
  _BasketRepository() : super(LocalFileStore(() async => Directory.systemTemp));

  var products = <InventoryProduct>[
    InventoryProduct(
      id: 'pen',
      name: 'Blue pen',
      priceMinor: 1500,
      stock: 10,
      sold: 0,
    ),
    InventoryProduct(
      id: 'paper',
      name: 'A5 paper',
      priceMinor: 2000,
      stock: 5,
      sold: 0,
      wholesalePriceMinor: 1700,
      wholesaleMinQuantity: 3,
      unitLabel: 'box',
    ),
  ];
  var sales = <SaleRecord>[];
  List<CartSaleLineRequest>? lastCart;
  String? lastCurrency;
  String? lastSingleCurrency;

  @override
  Future<InventorySnapshot> load() async => InventorySnapshot(products);

  @override
  Future<List<SaleRecord>> loadSales() async =>
      List.unmodifiable(List.of(sales));

  /// Captures the quick one-tap retail sale.
  @override
  Future<SaleOutcome> recordSale({
    required String id,
    int quantity = 1,
    String currency = 'TSh',
    bool wholesale = false,
  }) async {
    lastSingleCurrency = currency;
    return _record(lines: [
      CartSaleLineRequest(
        productId: id,
        quantity: quantity,
        wholesale: wholesale,
      ),
    ], currency: currency);
  }

  /// Captures the whole basket as the page assembled it.
  @override
  Future<SaleOutcome> recordCartSale({
    required List<CartSaleLineRequest> lines,
    String currency = 'TSh',
  }) async {
    lastCart = lines;
    lastCurrency = currency;
    return _record(lines: lines, currency: currency);
  }

  Future<SaleOutcome> _record({
    required List<CartSaleLineRequest> lines,
    required String currency,
  }) async {
    final items = <SaleItem>[];
    for (final line in lines) {
      var product =
          products.singleWhere((candidate) => candidate.id == line.productId);
      final unitPriceMinor = line.wholesale
          ? product.wholesalePriceMinor!
          : product.priceMinor;
      product = product.recordUnits(line.quantity);
      products[products.indexWhere(
        (candidate) => candidate.id == line.productId,
      )] = product;
      items.add(
        SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: line.quantity,
          unitPriceMinor: unitPriceMinor,
          unitLabel: product.unitLabel,
          priceTier: line.wholesale ? 'wholesale' : 'retail',
        ),
      );
    }
    final sale = SaleRecord(
      number: sales.length + 1,
      productId: items.first.productId,
      productName: items.first.productName,
      quantity: items.first.quantity,
      unitPriceMinor: items.first.unitPriceMinor,
      soldAt: DateTime(2026, 10, 31, 9, 15),
      currency: currency,
      unitLabel: items.first.unitLabel,
      priceTier: items.first.priceTier,
      items: items,
    );
    sales.add(sale);
    return SaleOutcome(snapshot: InventorySnapshot(products), sale: sale);
  }
}

/// A print gateway test double that captures the receipt PDF.
class _CapturePrinter implements PrintGateway {
  Uint8List? bytes;
  String? name;

  @override
  Future<bool> printPdf({
    required Uint8List bytes,
    required String name,
    required double widthMm,
    required double heightMm,
  }) async {
    this.bytes = bytes;
    this.name = name;
    return true;
  }
}

void main() {
  late Directory dataDir;
  late Directory settingsDir;
  late LocalFileStore settingsFiles;
  late _BasketRepository repository;
  late _CapturePrinter printer;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('desksuite_basket_ui_');
    settingsDir = await Directory.systemTemp.createTemp('desksuite_basket_cfg_');
    settingsFiles = LocalFileStore(() async => settingsDir);
    repository = _BasketRepository();
    printer = _CapturePrinter();
  });

  tearDown(() async {
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
    if (await settingsDir.exists()) await settingsDir.delete(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessPage(
            repository: repository,
            settings: BusinessSettingsRepository(settingsFiles),
            printer: printer,
            shopName: 'Mussa Stationery',
          ),
        ),
      ),
    );
    // The page must finish loading before interactions begin.
    await settleUntil(tester, find.byKey(const Key('new-sale')));
  }

  testWidgets('one customer basket becomes one itemised stored receipt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('new-sale')));
    await tester.pumpAndSettle();
    // Two retail pens and one wholesale paper box for this customer.
    await tester.tap(find.byKey(const Key('cart-add-pen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cart-inc-pen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cart-add-paper')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('cart-tier-paper')));
    await tester.tap(find.byKey(const Key('cart-tier-paper')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Wholesale'));
    await tester.pumpAndSettle();

    await reveal(tester, find.byKey(const Key('cart-total')));
    final total = tester.widget<Text>(find.byKey(const Key('cart-total')));
    expect(total.data, contains('47.00'));
    expect(total.data, contains('3 item(s)'));

    await tester.tap(find.byKey(const Key('complete-sale')));
    await tester.pumpAndSettle();
    await settleUntil(tester, find.textContaining('Sale recorded'));

    // The repository received exactly the assembled basket.
    expect(repository.lastCart!.length, 2);
    final penLine = repository.lastCart!
        .firstWhere((line) => line.productId == 'pen');
    final paperLine = repository.lastCart!
        .firstWhere((line) => line.productId == 'paper');
    expect(penLine.quantity, 2);
    expect(penLine.wholesale, isFalse);
    expect(paperLine.quantity, 1);
    expect(paperLine.wholesale, isTrue);
    expect(repository.lastCurrency, 'TSh');

    // The receipt is stored automatically and shown as itemised; prints are
    // optional and stay on demand.
    await reveal(tester, find.byKey(const Key('stored-receipt-1')));
    expect(find.textContaining('2 products'), findsOneWidget);
    await reveal(tester, find.byTooltip('Reprint receipt'));
    await tester.tap(find.byTooltip('Reprint receipt'));
    await waitUntil(tester, () => printer.bytes != null);
    expect(String.fromCharCodes(printer.bytes!.take(5)), '%PDF-');
    expect(printer.name, 'receipt-0001');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the receipt currency setting drives stock labels and sales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The seeded USD setting is real file IO; without runAsync the fake-async
    // test zone would suspend it forever (the ten-minute widget timeout).
    await tester.runAsync(() async {
      await BusinessSettingsRepository(
        settingsFiles,
      ).save(const BusinessSettings(currency: 'USD'));
    });
    await pumpPage(tester);

    // Stock value and product price lines use the saved currency instead of
    // the default 'TSh'.
    await settleUntil(tester, find.textContaining('Stock value at listed prices'));
    await settleUntil(tester, find.textContaining('USD 250.00'));
    // The product row is below the fold on a 360x720 phone, so the lazy list
    // has not built it yet; scroll it into view instead of pumping for it.
    await reveal(tester, find.textContaining('USD 15.00'));
    // Return to the top so the settings card is on screen again before the
    // dropdown interaction.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pump();

    final currencyDropdown = find.byKey(const Key('shop-currency'));
    await reveal(tester, currencyDropdown);
    await tester.tap(currencyDropdown);
    await tester.pumpAndSettle();
    final kshOption = find.text('Kenyan shilling (KSh)');
    await settleUntil(tester, kshOption);
    await tester.tap(kshOption.last);
    await tester.pumpAndSettle();

    // The selection persists to the real settings file and drives the labels.
    // The label changes only after the save completes, so waiting for it is
    // also the signal that the file has been rewritten (the file already
    // exists from the seeded USD value, so existence alone proves nothing).
    await settleUntil(tester, find.textContaining('KSh 250.00'));
    final stored = await tester.runAsync(
      () => File('${settingsDir.path}/business-settings.json').readAsString(),
    );
    expect(stored, contains('KSh'));
    await reveal(tester, find.textContaining('KSh 15.00'));

    // A one-tap retail sale carries the selected currency into the receipt.
    final sell = find.byTooltip('Record one unit sold');
    await reveal(tester, sell);
    await settleUntilEnabled(tester, sell.first);
    await tester.tap(sell.first);
    await settleUntil(tester, find.textContaining('Sale recorded'));
    await settleUntil(tester, find.textContaining('KSh 15.00'));
    expect(repository.lastSingleCurrency, 'KSh');
    expect(tester.takeException(), isNull);
  });

  testWidgets('restoring a backup needs explicit confirmation', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPage(tester);
    final restore = find.byKey(const Key('import-backup'));
    await reveal(tester, restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(find.text('Restore business backup?'), findsOneWidget);
    // Nothing is imported until the user explicitly confirms.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Restore business backup?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
