import 'dart:io';

import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late InventoryRepository repository;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('desksuite_cart_');
    repository = InventoryRepository(LocalFileStore(() async => dir));
  });

  tearDown(() => dir.delete(recursive: true));

  Future<InventoryProduct> seed(
    String name,
    int priceMinor, {
    int stock = 10,
    String unit = 'piece',
    int? wholesalePriceMinor,
    int wholesaleMinQuantity = 3,
  }) async {
    final snapshot = await repository.addProduct(
      name: name,
      priceMinor: priceMinor,
      stock: stock,
      unitLabel: unit,
      wholesalePriceMinor: wholesalePriceMinor,
      wholesaleMinQuantity: wholesaleMinQuantity,
    );
    return snapshot.products.last;
  }

  test('a basket sale stores one itemised receipt and reduces every stock', () async {
    final pen = await seed('Blue pen', 1500, stock: 10);
    final paper = await seed('A4 paper', 5000, stock: 7, unit: 'box');
    final outcome = await repository.recordCartSale(
      lines: [
        CartSaleLineRequest(productId: pen.id, quantity: 2),
        CartSaleLineRequest(productId: paper.id, quantity: 1, wholesale: true),
      ],
      currency: 'USD',
    );
    expect(outcome.sale.isCartSale, isTrue);
    expect(outcome.sale.items.length, 2);
    expect(outcome.sale.number, 1);
    expect(outcome.sale.currency, 'USD');
    final prices = <String, int>{
      for (final item in outcome.sale.items) item.productId: item.unitPriceMinor,
    };
    expect(prices[pen.id], 1500);
    expect(prices[paper.id], 5000);
    expect(outcome.sale.totalMinor, 2 * 1500 + 5000);
    final after = await repository.load();
    final byId = {for (final product in after.products) product.id: product};
    expect(byId[pen.id], isNotNull);
    expect(byId[pen.id]!.stock, 8);
    expect(byId[pen.id]!.sold, 2);
    expect(byId[paper.id]!.stock, 6);
    expect(byId[paper.id]!.sold, 1);
    // The stored receipt reopens from the sales log with the same lines.
    final stored = await repository.loadSales();
    expect(stored.length, 1);
    expect(stored.single.isCartSale, isTrue);
    expect(stored.single.toLines().length, 2);
    expect(stored.single.items.map((item) => item.productName), [
      'Blue pen',
      'A4 paper',
    ]);
    // The receipt produced for this sale is itemised and totals the basket.
    final receipt = outcome.receipt(shopName: 'Mussa Stationery');
    expect(receipt.lines.length, 2);
    expect(receipt.totalMinor, 2 * 1500 + 5000);
    expect(receipt.formattedTotal, 'USD 80.00');
  });

  test('receipt numbers continue across single and basket sales', () async {
    await seed('Pen', 1000, stock: 9);
    final first = await repository.recordSale(
      id: (await repository.load()).products.single.id,
      currency: 'TSh',
    );
    final outcome = await repository.recordCartSale(
      lines: [
        CartSaleLineRequest(
          productId: (await repository.load()).products.single.id,
          quantity: 3,
        ),
      ],
    );
    expect(first.sale.number, 1);
    expect(outcome.sale.number, 2);
    expect(outcome.sale.items.single.quantity, 3);
    expect((await repository.loadSales()).length, 2);
  });

  test('a duplicated product in one basket is refused without stock change', () async {
    final pen = await seed('Pen', 1000, stock: 5);
    await expectLater(
      repository.recordCartSale(
        lines: [
          CartSaleLineRequest(productId: pen.id, quantity: 1),
          CartSaleLineRequest(productId: pen.id, quantity: 2),
        ],
      ),
      throwsFormatException,
    );
    final after = await repository.load();
    expect(after.products.single.stock, 5);
    expect(await repository.loadSales(), isEmpty);
  });

  test('wholesale lines require a wholesale price and minimum quantity', () async {
    await seed('Pen', 1000, stock: 5, wholesaleMinQuantity: 3);
    final penId = (await repository.load()).products.first.id;
    // No wholesale price on this product.
    await expectLater(
      repository.recordCartSale(
        lines: [CartSaleLineRequest(productId: penId, quantity: 4, wholesale: true)],
      ),
      throwsFormatException,
    );
    final paper = await seed(
      'Paper',
      5000,
      wholesalePriceMinor: 4000,
      wholesaleMinQuantity: 3,
    );
    // Order quantity below the wholesale minimum.
    await expectLater(
      repository.recordCartSale(
        lines: [
          CartSaleLineRequest(productId: paper.id, quantity: 2, wholesale: true),
        ],
      ),
      throwsFormatException,
    );
    // Above the minimum the wholesale price is used.
    final outcome = await repository.recordCartSale(
      lines: [
        CartSaleLineRequest(productId: paper.id, quantity: 3, wholesale: true),
      ],
    );
    expect(outcome.sale.priceTier, 'wholesale');
    expect(outcome.sale.unitPriceMinor, 4000);
  });

  test('a basket larger than the available stock is refused with the catalogue unchanged', () async {
    final pen = await seed('Pen', 1000, stock: 2);
    await expectLater(
      repository.recordCartSale(
        lines: [CartSaleLineRequest(productId: pen.id, quantity: 3)],
      ),
      throwsStateError,
    );
    expect((await repository.load()).products.single.stock, 2);
    expect(await repository.loadSales(), isEmpty);
  });

  test('an empty basket and an oversized product bundle are refused', () async {
    final pen = await seed('Pen', 1000);
    await expectLater(
      repository.recordCartSale(lines: const []),
      throwsFormatException,
    );
    // maxSaleLines is 40; a larger request is refused before any write.
    final duplicateLines = List.generate(
      41,
      (index) => CartSaleLineRequest(productId: pen.id, quantity: 1),
    );
    await expectLater(
      repository.recordCartSale(lines: duplicateLines),
      throwsFormatException,
    );
    expect(await repository.loadSales(), isEmpty);
  });

  test('a sales-log write failure rolls the whole basket back', () async {
    final pen = await seed('Pen', 1000, stock: 4);
    final paper = await seed('Paper', 2000, stock: 4);
    var failSalesLog = false;
    final guarded = _FailingSalesLogStore(
      LocalFileStore(() async => dir),
      () => failSalesLog = true,
    );
    final guardedRepository = InventoryRepository(guarded);
    await expectLater(
      guardedRepository.recordCartSale(
        lines: [
          CartSaleLineRequest(productId: pen.id, quantity: 1),
          CartSaleLineRequest(productId: paper.id, quantity: 1),
        ],
      ),
      throwsStateError,
    );
    expect(failSalesLog, isTrue);
    // The rollback restored both stocks and no sale was kept.
    final restored = await repository.load();
    final byId = {for (final product in restored.products) product.id: product};
    expect(byId[pen.id]!.stock, 4);
    expect(byId[paper.id]!.stock, 4);
    expect(await repository.loadSales(), isEmpty);
  });
}

/// Delegates every operation to a working store but fails the specific
/// sales-log write, so rollback behaviour is exercised without patching disk.
class _FailingSalesLogStore extends LocalFileStore {
  _FailingSalesLogStore(this._fallback, this._onFailure) : super(_fallback.root);

  final LocalFileStore _fallback;
  final void Function() _onFailure;

  @override
  Future<String> readText(String name, [String fallback = '']) =>
      _fallback.readText(name, fallback);

  @override
  Future<void> writeText(String name, String value) {
    if (name == 'sales.json') {
      _onFailure();
      return Future.error(StateError('simulated sales-log failure'));
    }
    return _fallback.writeText(name, value);
  }
}
