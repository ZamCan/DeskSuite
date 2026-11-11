import 'dart:convert';
import 'dart:io';

import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/business/sale_receipt.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

SaleRecord _stored(Map<String, Object?> json) =>
    SaleRecord.fromJson(Map<String, dynamic>.from(json));

Map<String, Object?> _baseSale() => {
  'number': 4,
  'productId': 'p',
  'productName': 'Paper',
  'quantity': 2,
  'unitPriceMinor': 500,
  'soldAt': '2026-05-06T07:08:09.000',
};

void main() {
  test('a single-product sale stores how the customer paid', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_pay_');
    addTearDown(() => dir.delete(recursive: true));
    final repo = InventoryRepository(LocalFileStore(() async => dir));
    final added = await repo.addProduct(
      name: 'Envelope',
      priceMinor: 200,
      stock: 4,
    );
    final id = added.products.single.id;

    final sale = await repo.recordSale(id: id, paymentMethod: 'mobile');
    expect(sale.sale.paymentMethod, 'mobile');
    expect(sale.receipt().paymentMethod, 'mobile');
    expect(salePaymentMethodLabel(sale.sale.paymentMethod), 'Mobile money');
    // The receipt keeps its printed lines and total.
    expect(sale.receipt().lines.single.name, contains('Envelope'));
    expect(sale.receipt().totalMinor, 200);

    final reopened = InventoryRepository(LocalFileStore(() async => dir));
    final stored = (await reopened.loadSales()).single;
    expect(stored.paymentMethod, 'mobile');
    expect(stored.toJson()['paymentMethod'], 'mobile');
  });

  test('a basket sale keeps one method for the whole receipt', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_pay_cart_');
    addTearDown(() => dir.delete(recursive: true));
    final repo = InventoryRepository(LocalFileStore(() async => dir));
    final first = await repo.addProduct(name: 'Pen', priceMinor: 500, stock: 4);
    final pen = first.products.single.id;
    final second = await repo.addProduct(
      name: 'Book',
      priceMinor: 1500,
      stock: 4,
    );
    final book = second.products.firstWhere((p) => p.name == 'Book').id;

    final sale = await repo.recordCartSale(
      lines: [
        CartSaleLineRequest(productId: pen, quantity: 2),
        CartSaleLineRequest(productId: book, quantity: 1),
      ],
      paymentMethod: 'card',
    );
    expect(sale.sale.paymentMethod, 'card');
    final receipt = sale.receipt(shopName: 'Mussa Stationery');
    expect(receipt.paymentMethod, 'card');
    expect(receipt.totalMinor, 2500);
    expect(salePaymentMethodLabel(receipt.paymentMethod), 'Card');
  });

  test('an unknown payment id is refused and nothing is written', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_pay_bad_');
    addTearDown(() => dir.delete(recursive: true));
    final repo = InventoryRepository(LocalFileStore(() async => dir));
    final added = await repo.addProduct(name: 'Ink', priceMinor: 900, stock: 3);
    final id = added.products.single.id;

    await expectLater(
      repo.recordSale(id: id, paymentMethod: 'bitcoin'),
      throwsFormatException,
    );
    await expectLater(
      repo.recordCartSale(
        lines: [CartSaleLineRequest(productId: id, quantity: 1)],
        paymentMethod: 'bitcoin',
      ),
      throwsFormatException,
    );
    expect((await repo.load()).products.single.stock, 3);
    expect((await repo.load()).products.single.sold, 0);
    expect(await repo.loadSales(), isEmpty);
    // An unknown or absent id has no label to print.
    expect(salePaymentMethodLabel('bitcoin'), isNull);
    expect(salePaymentMethodLabel(null), isNull);
  });

  test('older sale records carry no payment method and still decode', () {
    final legacy = _stored(_baseSale());
    expect(legacy.paymentMethod, isNull);
    expect(legacy.toJson().containsKey('paymentMethod'), isFalse);
    final roundTripped = _stored(
      jsonDecode(jsonEncode(legacy.toJson())) as Map<String, dynamic>,
    );
    expect(roundTripped.paymentMethod, isNull);
    expect(roundTripped.totalMinor, 1000);

    final withMethod = _stored({..._baseSale(), 'paymentMethod': 'transfer'});
    expect(withMethod.paymentMethod, 'transfer');
    expect(salePaymentMethodLabel(withMethod.paymentMethod), 'Bank transfer');
    expect(
      _stored(
        jsonDecode(jsonEncode(withMethod.toJson())) as Map<String, dynamic>,
      ).paymentMethod,
      'transfer',
    );
    expect(
      () => _stored({..._baseSale(), 'paymentMethod': 'cash '}),
      throwsFormatException,
    );
  });

  test('the receipt refuses an unsupported payment label', () {
    SaleReceipt receipt({String? payment}) => SaleReceipt(
      number: 1,
      issuedAt: DateTime.utc(2026, 5, 6),
      lines: [SaleLine(name: 'Paper', quantity: 1, unitPriceMinor: 500)],
      paymentMethod: payment,
    );
    expect(receipt(payment: null).paymentMethod, isNull);
    expect(receipt(payment: 'cash').paymentMethod, 'cash');
    expect(() => receipt(payment: 'cheque'), throwsFormatException);
    expect(
      salePaymentMethods,
      containsAll(['cash', 'mobile', 'card', 'transfer']),
    );
  });
}
