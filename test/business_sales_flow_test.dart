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

/// Scrolls a lazy page while real asynchronous work settles until [target] is
/// built, then brings it into view. [reveal] alone cannot do this: the child a
/// test needs may not exist until a later file read completes.
Future<void> revealWhenLoaded(
  WidgetTester tester,
  Finder target, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pump();
      return;
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
  }
  fail('Timed out waiting for the target widget to be built.');
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
  String? lastPaymentMethod;
  List<RefundLineRequest>? lastRefundLines;
  int? lastRefundNumber;

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
    String? paymentMethod,
  }) async {
    lastSingleCurrency = currency;
    lastPaymentMethod = paymentMethod;
    return _record(
      lines: [
        CartSaleLineRequest(
          productId: id,
          quantity: quantity,
          wholesale: wholesale,
        ),
      ],
      currency: currency,
      paymentMethod: paymentMethod,
    );
  }

  /// Captures the whole basket as the page assembled it.
  @override
  Future<SaleOutcome> recordCartSale({
    required List<CartSaleLineRequest> lines,
    String currency = 'TSh',
    String? paymentMethod,
  }) async {
    lastCart = lines;
    lastCurrency = currency;
    lastPaymentMethod = paymentMethod;
    return _record(
      lines: lines,
      currency: currency,
      paymentMethod: paymentMethod,
    );
  }

  /// Captures the refund the page asked for, without touching any files.
  @override
  Future<RefundOutcome> refundSaleLines({
    required int number,
    required List<RefundLineRequest> lines,
    String? reason,
  }) async {
    lastRefundNumber = number;
    lastRefundLines = lines;
    final record = sales.firstWhere((sale) => sale.number == number);
    final quantities = {
      for (final line in lines) line.productId: line.quantity,
    };
    for (final entry in quantities.entries) {
      final at = products.indexWhere((product) => product.id == entry.key);
      products[at] = products[at].restoreUnits(entry.value);
    }
    final refunded = record.withRefund(
      at: DateTime(2026, 11, 10, 12),
      quantities: quantities,
      reason: reason,
    );
    sales[sales.indexOf(record)] = refunded;
    return RefundOutcome(snapshot: InventorySnapshot(products), sale: refunded);
  }

  Future<SaleOutcome> _record({
    required List<CartSaleLineRequest> lines,
    required String currency,
    String? paymentMethod,
  }) async {
    final items = <SaleItem>[];
    for (final line in lines) {
      var product = products.singleWhere(
        (candidate) => candidate.id == line.productId,
      );
      final unitPriceMinor = line.wholesale
          ? product.wholesalePriceMinor!
          : product.priceMinor;
      product = product.recordUnits(line.quantity);
      products[products.indexWhere(
            (candidate) => candidate.id == line.productId,
          )] =
          product;
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
      paymentMethod: paymentMethod,
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
    settingsDir = await Directory.systemTemp.createTemp(
      'desksuite_basket_cfg_',
    );
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
    await reveal(tester, find.byKey(const Key('cart-add-paper')));
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
    final penLine = repository.lastCart!.firstWhere(
      (line) => line.productId == 'pen',
    );
    final paperLine = repository.lastCart!.firstWhere(
      (line) => line.productId == 'paper',
    );
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
      await BusinessSettingsRepository(settingsFiles)
          .save(const BusinessSettings(currency: 'USD'));
    });
    await pumpPage(tester);

    // Stock value and product price lines use the saved currency instead of
    // the default 'TSh'.
    await settleUntil(
      tester,
      find.textContaining('Stock value at listed prices'),
    );
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
    // The label changes only after the save completes, so finding it is also
    // the signal that the file has been rewritten (the file already exists from
    // the seeded USD value, so existence alone proves nothing). Scroll back to
    // the summary first: revealing the dropdown above may have pushed it off
    // the top of the lazy list, so pumping alone could never find it.
    await reveal(tester, find.textContaining('Stock value at listed prices'));
    await settleUntil(tester, find.textContaining('KSh 250.00'));
    final stored = await tester.runAsync(
      () => File('${settingsDir.path}/business-settings.json').readAsString(),
    );
    expect(stored, contains('KSh'));
    await reveal(tester, find.textContaining('KSh 15.00'));

    // A one-tap retail sale carries the selected currency into the receipt.
    final sell = find.byTooltip('Record one unit sold');
    await reveal(tester, sell.first);
    await settleUntilEnabled(tester, sell.first);
    await tester.tap(sell.first);
    await settleUntil(tester, find.textContaining('Sale recorded'));
    await settleUntil(tester, find.textContaining('KSh 15.00'));
    expect(repository.lastSingleCurrency, 'KSh');
    expect(tester.takeException(), isNull);
  });

  testWidgets('refunding a stored receipt returns stock after confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The real repository and private files back this flow, so the assertion
    // covers the stored state and not only the widget tree. The stored files
    // are seeded directly: a store queue created inside the fake-async zone
    // would only drain while the test pumps.
    await tester.runAsync(() async {
      await File('${dataDir.path}/products.json').writeAsString(
        '[{"id":"pen","name":"Blue pen","priceMinor":1500,'
        '"unitLabel":"piece","stock":8,"sold":2}]',
      );
      await File('${dataDir.path}/sales.json').writeAsString(
        '[{"number":1,"productId":"pen","productName":"Blue pen",'
        '"quantity":2,"unitPriceMinor":1500,'
        '"soldAt":"2026-10-31T09:15:00.000","currency":"TSh",'
        '"unitLabel":"piece","priceTier":"retail"}]',
      );
    });
    final realRepository = InventoryRepository(
      LocalFileStore(() async => dataDir),
    );
    const saleNumber = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessPage(
            repository: realRepository,
            settings: BusinessSettingsRepository(settingsFiles),
            printer: printer,
            shopName: 'Mussa Stationery',
          ),
        ),
      ),
    );
    await settleUntil(tester, find.byKey(const Key('new-sale')));

    // The catalogue loads first and the stored receipts follow, so scroll the
    // lazy page while real file I/O settles until the receipt is built.
    final refundButton = find.byKey(ValueKey('refund-sale-$saleNumber'));
    await revealWhenLoaded(tester, refundButton);
    await tester.tap(refundButton);
    await tester.pumpAndSettle();
    expect(find.text('Refund this sale?'), findsOneWidget);

    // Cancelling changes nothing: the sale stands and stock stays sold.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Refund this sale?'), findsNothing);
    final untouched = await settledIo(
      tester,
      () => realRepository.load(),
      label: 'the catalogue',
    );
    expect(untouched.products.single.stock, 8);

    await tester.tap(refundButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('refund-reason')),
      'Torn cover',
    );
    await tester.tap(find.byKey(const Key('confirm-refund')));
    // The refunded state is only shown after both files are written.
    await settleUntil(tester, find.textContaining('· refunded'));

    final restored = await settledIo(
      tester,
      () => realRepository.load(),
      label: 'the refunded catalogue',
    );
    expect(restored.products.single.stock, 10);
    expect(restored.products.single.sold, 0);
    final log = await settledIo(
      tester,
      () => realRepository.loadSales(),
      label: 'the sales log',
    );
    expect(log.single.refundReason, 'Torn cover');
    expect(log.single.isRefunded, isTrue);
    // The receipt now shows its refunded state and can no longer be refunded.
    expect(refundButton, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new sale records the chosen payment method', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('new-sale')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('cart-add-pen')));
    await tester.tap(find.byKey(const Key('cart-add-pen')));
    await tester.pumpAndSettle();

    // The operator picks how the customer paid before completing the sale.
    await reveal(tester, find.byKey(const Key('sale-payment')));
    await tester.tap(find.byKey(const Key('sale-payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();

    await reveal(tester, find.byKey(const Key('complete-sale')));
    await tester.tap(find.byKey(const Key('complete-sale')));
    await tester.pumpAndSettle();
    await settleUntil(tester, find.textContaining('Sale recorded'));

    expect(repository.lastPaymentMethod, 'cash');
    expect(repository.sales.single.paymentMethod, 'cash');
    // The stored receipt shows the method it actually recorded.
    await revealWhenLoaded(tester, find.byKey(const Key('stored-receipt-1')));
    expect(find.textContaining('retail · Cash'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refunding part of a receipt returns only those units', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A real stored receipt of two pens, with the catalogue already sold down.
    await tester.runAsync(() async {
      await File('${dataDir.path}/products.json').writeAsString(
        '[{"id":"pen","name":"Blue pen","priceMinor":1500,'
        '"unitLabel":"piece","stock":8,"sold":2}]',
      );
      await File('${dataDir.path}/sales.json').writeAsString(
        '[{"number":1,"productId":"pen","productName":"Blue pen",'
        '"quantity":2,"unitPriceMinor":1500,'
        '"soldAt":"2026-10-31T09:15:00.000","currency":"TSh",'
        '"unitLabel":"piece","priceTier":"retail",'
        '"paymentMethod":"mobile"}]',
      );
    });
    final realRepository = InventoryRepository(
      LocalFileStore(() async => dataDir),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessPage(
            repository: realRepository,
            settings: BusinessSettingsRepository(settingsFiles),
            printer: printer,
            shopName: 'Mussa Stationery',
          ),
        ),
      ),
    );
    await settleUntil(tester, find.byKey(const Key('new-sale')));

    final refundButton = find.byKey(const ValueKey('refund-sale-1'));
    await revealWhenLoaded(tester, refundButton);
    // The stored receipt shows the payment it was saved with.
    expect(find.textContaining('· Mobile money'), findsOneWidget);
    await tester.tap(refundButton);
    await tester.pumpAndSettle();
    expect(find.text('Refund this sale?'), findsOneWidget);
    // Everything still standing starts selected.
    expect(find.textContaining('Refund value: TSh 30.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('refund-dec-pen')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Refund value: TSh 15.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-refund')));
    await settleUntil(tester, find.textContaining('1 of 2 refunded'));

    final restored = await settledIo(
      tester,
      () => realRepository.load(),
      label: 'the partly refunded catalogue',
    );
    expect(restored.products.single.stock, 9);
    expect(restored.products.single.sold, 1);
    final log = await settledIo(
      tester,
      () => realRepository.loadSales(),
      label: 'the sales log',
    );
    expect(log.single.refunds.single.quantities, {'pen': 1});
    expect(log.single.isPartiallyRefunded, isTrue);
    expect(log.single.remainingUnits, 1);
    // The rest of the receipt can still be refunded later.
    expect(find.byKey(const ValueKey('refund-sale-1')), findsOneWidget);
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
