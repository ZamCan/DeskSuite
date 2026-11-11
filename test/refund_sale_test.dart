import 'dart:convert';
import 'dart:io';

import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/business/sale_receipt.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails only the sales-log write so the stock rollback path can be tested.
class _FailingSalesStore extends LocalFileStore {
  _FailingSalesStore(super.root);
  var failSales = false;

  @override
  Future<void> writeText(String name, String value) {
    if (failSales && name == 'sales.json') {
      throw const FileSystemException('simulated sales-log failure');
    }
    return super.writeText(name, value);
  }
}

SaleRecord _legacySale() => SaleRecord(
  number: 7,
  productId: 'p',
  productName: 'Paper',
  quantity: 1,
  unitPriceMinor: 250,
  soldAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
);

void main() {
  test(
    'a refund returns units to stock and marks the stored receipt',
    () async {
      final dir = await Directory.systemTemp.createTemp('desksuite_refund_');
      addTearDown(() => dir.delete(recursive: true));
      final repo = InventoryRepository(LocalFileStore(() async => dir));
      final added = await repo.addProduct(
        name: 'A4 sheet',
        priceMinor: 500,
        stock: 10,
        unitLabel: 'sheet',
      );
      final id = added.products.single.id;
      final sale = await repo.recordSale(id: id, quantity: 3, currency: 'TSh');
      expect(sale.snapshot.products.single.stock, 7);

      final refund = await repo.refundSale(
        number: sale.sale.number,
        reason: '  wrong size  ',
      );
      expect(refund.snapshot.products.single.stock, 10);
      expect(refund.snapshot.products.single.sold, 0);
      expect(refund.sale.isRefunded, isTrue);
      expect(refund.sale.refundReason, 'wrong size');
      expect(refund.sale.refundedAt, isNotNull);
      expect(refund.sale.totalMinor, 1500);

      // The refund survives reopening: both files hold the restored state.
      final reopened = InventoryRepository(LocalFileStore(() async => dir));
      expect((await reopened.load()).products.single.stock, 10);
      final log = await reopened.loadSales();
      expect(log.single.isRefunded, isTrue);
      expect(log.single.refundReason, 'wrong size');
      expect(log.single.totalMinor, 1500);
    },
  );

  test('refunding a basket restores every line exactly once', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_refund_cart_');
    addTearDown(() => dir.delete(recursive: true));
    final repo = InventoryRepository(LocalFileStore(() async => dir));
    final first = await repo.addProduct(name: 'Pen', priceMinor: 500, stock: 5);
    final pen = first.products.single.id;
    final second = await repo.addProduct(
      name: 'Notebook',
      priceMinor: 1500,
      stock: 10,
    );
    final book = second.products
        .firstWhere((product) => product.name == 'Notebook')
        .id;

    final sale = await repo.recordCartSale(
      lines: [
        CartSaleLineRequest(productId: pen, quantity: 2),
        CartSaleLineRequest(productId: book, quantity: 4),
      ],
    );
    expect(sale.sale.totalUnits, 6);
    final refund = await repo.refundSale(number: sale.sale.number);

    final byName = {
      for (final product in refund.snapshot.products) product.name: product,
    };
    expect(byName['Pen']!.stock, 5);
    expect(byName['Pen']!.sold, 0);
    expect(byName['Notebook']!.stock, 10);
    expect(byName['Notebook']!.sold, 0);
    expect(refund.sale.items.length, 2);
    expect(refund.sale.refundReason, isNull);
  });

  test(
    'a sale cannot be refunded twice and an unknown receipt is refused',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'desksuite_refund_twice_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final repo = InventoryRepository(LocalFileStore(() async => dir));
      final added = await repo.addProduct(
        name: 'Ink',
        priceMinor: 900,
        stock: 4,
      );
      final id = added.products.single.id;
      final sale = await repo.recordSale(id: id, quantity: 2);
      await repo.refundSale(number: sale.sale.number);

      await expectLater(
        repo.refundSale(number: sale.sale.number),
        throwsStateError,
      );
      await expectLater(repo.refundSale(number: 9999), throwsStateError);
      // Neither refused attempt changed stock or the log.
      expect((await repo.load()).products.single.stock, 4);
      final log = await repo.loadSales();
      expect(log.single.isRefunded, isTrue);
      expect(log.single.totalUnits, 2);
    },
  );

  test('invalid receipt numbers and refund notes are rejected', () async {
    final dir = await Directory.systemTemp.createTemp(
      'desksuite_refund_limits_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final repo = InventoryRepository(LocalFileStore(() async => dir));
    final added = await repo.addProduct(
      name: 'Glue',
      priceMinor: 300,
      stock: 2,
    );
    final id = added.products.single.id;
    final sale = await repo.recordSale(id: id);

    await expectLater(repo.refundSale(number: 0), throwsFormatException);
    await expectLater(repo.refundSale(number: 1000000), throwsFormatException);
    await expectLater(
      repo.refundSale(number: sale.sale.number, reason: 'x' * 201),
      throwsFormatException,
    );
    expect((await repo.load()).products.single.stock, 1);
    expect((await repo.loadSales()).single.isRefunded, isFalse);
  });

  test('a failed sales-log write rolls the catalogue back', () async {
    final dir = await Directory.systemTemp.createTemp(
      'desksuite_refund_rollback_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final store = _FailingSalesStore(() async => dir);
    final repo = InventoryRepository(store);
    final added = await repo.addProduct(
      name: 'Clip',
      priceMinor: 100,
      stock: 3,
    );
    final id = added.products.single.id;
    final sale = await repo.recordSale(id: id, quantity: 1);
    expect((await repo.load()).products.single.stock, 2);

    store.failSales = true;
    await expectLater(
      repo.refundSale(number: sale.sale.number),
      throwsStateError,
    );
    store.failSales = false;

    // Stock is back where the sale left it, and the receipt still stands.
    expect((await repo.load()).products.single.stock, 2);
    expect((await repo.loadSales()).single.isRefunded, isFalse);
    // A later retry succeeds once the log can be written again.
    final refund = await repo.refundSale(number: sale.sale.number);
    expect(refund.snapshot.products.single.stock, 3);
    expect((await repo.loadSales()).single.isRefunded, isTrue);
  });

  test('older sale records decode as not refunded and round-trip', () async {
    final old = _legacySale();
    expect(old.isRefunded, isFalse);
    expect(old.refundReason, isNull);
    expect(old.totalUnits, 1);
    final decoded = SaleRecord.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(old.toJson())) as Map<String, dynamic>,
      ),
    );
    expect(decoded.toJson(), old.toJson());
    expect(decoded.isRefunded, isFalse);

    final refunded = old.markRefunded(
      at: DateTime.utc(2026, 2, 3, 4, 5),
      reason: 'torn',
    );
    final roundTripped = SaleRecord.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(refunded.toJson())) as Map<String, dynamic>,
      ),
    );
    expect(roundTripped.isRefunded, isTrue);
    expect(roundTripped.refundReason, 'torn');
    expect(roundTripped.refundedAt, DateTime.utc(2026, 2, 3, 4, 5));
    expect(roundTripped.totalMinor, old.totalMinor);
    expect(() => refunded.markRefunded(at: DateTime.now()), throwsStateError);
  });

  test('refund fields and stock restores are range-checked', () {
    expect(
      () => SaleRecord(
        number: 1,
        productId: 'p',
        productName: 'Paper',
        quantity: 1,
        unitPriceMinor: 100,
        soldAt: DateTime.utc(2026),
        refundReason: 'no timestamp',
      ),
      throwsFormatException,
    );
    expect(
      () => SaleRecord(
        number: 1,
        productId: 'p',
        productName: 'Paper',
        quantity: 1,
        unitPriceMinor: 100,
        soldAt: DateTime.utc(2026),
        refundedAt: DateTime.utc(2026),
        refundReason: '   ',
      ),
      throwsFormatException,
    );
    final full = InventoryProduct(
      id: 'p',
      name: 'Paper',
      priceMinor: 100,
      stock: maxStockCount,
      sold: 5,
    );
    expect(() => full.restoreUnits(1), throwsStateError);
    final empty = InventoryProduct(
      id: 'p',
      name: 'Paper',
      priceMinor: 100,
      stock: 0,
      sold: 0,
    );
    expect(() => empty.restoreUnits(1), throwsStateError);
    expect(() => empty.restoreUnits(0), throwsFormatException);
  });

  test('a partial refund returns only the chosen units to stock', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_partial_');
    addTearDown(() => dir.delete(recursive: true));
    final repo = InventoryRepository(LocalFileStore(() async => dir));
    final first = await repo.addProduct(name: 'Pen', priceMinor: 500, stock: 5);
    final pen = first.products.single.id;
    final second = await repo.addProduct(
      name: 'Notebook',
      priceMinor: 1500,
      stock: 10,
    );
    final book = second.products
        .firstWhere((product) => product.name == 'Notebook')
        .id;

    final sale = await repo.recordCartSale(
      lines: [
        CartSaleLineRequest(productId: pen, quantity: 2),
        CartSaleLineRequest(productId: book, quantity: 4),
      ],
    );
    expect(sale.sale.remainingUnits, 6);

    final refund = await repo.refundSaleLines(
      number: sale.sale.number,
      lines: [RefundLineRequest(productId: pen, quantity: 1)],
      reason: '  damaged  ',
    );
    final byName = {
      for (final product in refund.snapshot.products) product.name: product,
    };
    expect(byName['Pen']!.stock, 4);
    expect(byName['Pen']!.sold, 1);
    // The other line is untouched by a line refund.
    expect(byName['Notebook']!.stock, 6);
    expect(byName['Notebook']!.sold, 4);

    expect(refund.sale.isRefunded, isFalse);
    expect(refund.sale.isPartiallyRefunded, isTrue);
    expect(refund.sale.unitsRefunded, 1);
    expect(refund.sale.remainingUnits, 5);
    expect(refund.sale.remainingUnitsFor(pen), 1);
    expect(refund.sale.remainingUnitsFor(book), 4);
    expect(refund.sale.refunds.single.reason, 'damaged');
    expect(refund.sale.refundedMinor, 500);
    expect(refund.sale.refundSummary, contains('Refunded 1 of 6'));

    // The partial history survives reopening, in both files.
    final reopened = InventoryRepository(LocalFileStore(() async => dir));
    final stored = (await reopened.loadSales()).single;
    expect(stored.refunds.single.quantities, {pen: 1});
    expect(stored.isPartiallyRefunded, isTrue);
    expect(stored.refundedAt, isNull);
    expect((await reopened.load()).products.map((p) => p.stock), [4, 6]);
  });

  test(
    'partial refunds accumulate until the receipt is fully refunded',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'desksuite_partial_more_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final repo = InventoryRepository(LocalFileStore(() async => dir));
      final first = await repo.addProduct(
        name: 'Pen',
        priceMinor: 500,
        stock: 5,
      );
      final pen = first.products.single.id;
      final second = await repo.addProduct(
        name: 'Notebook',
        priceMinor: 1500,
        stock: 10,
      );
      final book = second.products
          .firstWhere((product) => product.name == 'Notebook')
          .id;
      final sale = await repo.recordCartSale(
        lines: [
          CartSaleLineRequest(productId: pen, quantity: 2),
          CartSaleLineRequest(productId: book, quantity: 4),
        ],
      );

      await repo.refundSaleLines(
        number: sale.sale.number,
        lines: [RefundLineRequest(productId: pen, quantity: 1)],
        reason: 'damaged',
      );
      final rest = await repo.refundSale(number: sale.sale.number);

      final byName = {
        for (final product in rest.snapshot.products) product.name: product,
      };
      expect(byName['Pen']!.stock, 5);
      expect(byName['Pen']!.sold, 0);
      expect(byName['Notebook']!.stock, 10);
      expect(byName['Notebook']!.sold, 0);
      expect(rest.sale.isRefunded, isTrue);
      expect(rest.sale.refunds.length, 2);
      expect(rest.sale.refunds.first.reason, 'damaged');
      expect(rest.sale.refunds.last.quantities, {pen: 1, book: 4});
      expect(rest.sale.remainingUnits, 0);
      expect(rest.sale.refundedMinor, rest.sale.totalMinor);
      expect(rest.sale.refundSummary, contains('Refunded in full'));

      // Nothing is left to give back.
      await expectLater(
        repo.refundSaleLines(
          number: sale.sale.number,
          lines: [RefundLineRequest(productId: pen, quantity: 1)],
        ),
        throwsStateError,
      );
      expect((await repo.load()).products.map((p) => p.sold), [0, 0]);
    },
  );

  test('a refund above the units still standing is refused', () async {
    final dir = await Directory.systemTemp.createTemp(
      'desksuite_partial_over_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final repo = InventoryRepository(LocalFileStore(() async => dir));
    final added = await repo.addProduct(name: 'Ink', priceMinor: 900, stock: 6);
    final id = added.products.single.id;
    final sale = await repo.recordSale(id: id, quantity: 2);

    await expectLater(
      repo.refundSaleLines(
        number: sale.sale.number,
        lines: [RefundLineRequest(productId: id, quantity: 3)],
      ),
      throwsStateError,
    );
    // A partially refunded receipt cannot give the same unit back again.
    await repo.refundSaleLines(
      number: sale.sale.number,
      lines: [RefundLineRequest(productId: id, quantity: 1)],
    );
    await expectLater(
      repo.refundSaleLines(
        number: sale.sale.number,
        lines: [RefundLineRequest(productId: id, quantity: 2)],
      ),
      throwsStateError,
    );
    expect((await repo.load()).products.single.stock, 5);
    expect((await repo.load()).products.single.sold, 1);
    expect((await repo.loadSales()).single.unitsRefunded, 1);
  });

  test('invalid refund lines are rejected before any write', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_partial_bad_');
    addTearDown(() => dir.delete(recursive: true));
    final repo = InventoryRepository(LocalFileStore(() async => dir));
    final added = await repo.addProduct(
      name: 'Glue',
      priceMinor: 300,
      stock: 3,
    );
    final id = added.products.single.id;
    final sale = await repo.recordSale(id: id, quantity: 2);

    await expectLater(
      repo.refundSaleLines(number: sale.sale.number, lines: const []),
      throwsFormatException,
    );
    await expectLater(
      repo.refundSaleLines(
        number: sale.sale.number,
        lines: [
          RefundLineRequest(productId: id, quantity: 1),
          RefundLineRequest(productId: id, quantity: 1),
        ],
      ),
      throwsFormatException,
    );
    await expectLater(
      repo.refundSaleLines(
        number: sale.sale.number,
        lines: [RefundLineRequest(productId: id, quantity: 0)],
      ),
      throwsFormatException,
    );
    // A product this receipt never sold cannot be refunded through it.
    await expectLater(
      repo.refundSaleLines(
        number: sale.sale.number,
        lines: const [RefundLineRequest(productId: 'ghost', quantity: 1)],
      ),
      throwsStateError,
    );
    await expectLater(
      repo.refundSaleLines(
        number: sale.sale.number,
        lines: [RefundLineRequest(productId: id, quantity: 1)],
        reason: 'x' * 201,
      ),
      throwsFormatException,
    );

    expect((await repo.load()).products.single.stock, 1);
    final log = (await repo.loadSales()).single;
    expect(log.refunds, isEmpty);
    expect(log.isRefunded, isFalse);
  });

  test('a failed log write rolls a partial refund back', () async {
    final dir = await Directory.systemTemp.createTemp(
      'desksuite_partial_rollback_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final store = _FailingSalesStore(() async => dir);
    final repo = InventoryRepository(store);
    final added = await repo.addProduct(
      name: 'Clip',
      priceMinor: 100,
      stock: 4,
    );
    final id = added.products.single.id;
    final sale = await repo.recordSale(id: id, quantity: 3);

    store.failSales = true;
    await expectLater(
      repo.refundSaleLines(
        number: sale.sale.number,
        lines: [RefundLineRequest(productId: id, quantity: 1)],
      ),
      throwsStateError,
    );
    store.failSales = false;
    expect((await repo.load()).products.single.stock, 1);
    expect((await repo.loadSales()).single.refunds, isEmpty);

    final retried = await repo.refundSaleLines(
      number: sale.sale.number,
      lines: [RefundLineRequest(productId: id, quantity: 1)],
    );
    expect(retried.snapshot.products.single.stock, 2);
    expect((await repo.loadSales()).single.unitsRefunded, 1);
  });

  test('stored refunds cannot describe more units than were sold', () {
    Map<String, dynamic> recorded(Map<String, Object?> refund) => {
      'number': 3,
      'productId': 'p',
      'productName': 'Paper',
      'quantity': 2,
      'unitPriceMinor': 500,
      'soldAt': '2026-03-04T05:06:07.000',
      'refunds': [refund],
    };
    final at = DateTime.utc(2026, 3, 5).toIso8601String();
    final valid = SaleRecord.fromJson(
      recorded({
        'at': at,
        'items': [
          {'productId': 'p', 'quantity': 1},
        ],
      }),
    );
    expect(valid.isPartiallyRefunded, isTrue);
    expect(valid.remainingUnitsFor('p'), 1);

    expect(
      () => SaleRecord.fromJson(
        recorded({
          'at': at,
          'items': [
            {'productId': 'p', 'quantity': 3},
          ],
        }),
      ),
      throwsFormatException,
    );
    // A product that is not on the receipt cannot be refunded through it.
    expect(
      () => SaleRecord.fromJson(
        recorded({
          'at': at,
          'items': [
            {'productId': 'other', 'quantity': 1},
          ],
        }),
      ),
      throwsFormatException,
    );
  });
}
