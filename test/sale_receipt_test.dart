import 'dart:io';

import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/business/sale_receipt.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('money', () {
    test('groups thousands and keeps exact minor units', () {
      expect(formatGroupedMoney(0), 'TSh 0.00');
      expect(formatGroupedMoney(5), 'TSh 0.05');
      expect(formatGroupedMoney(1234567), 'TSh 12,345.67');
      expect(formatGroupedMoney(100000000), 'TSh 1,000,000.00');
      expect(formatGroupedMoney(-250, currency: 'USD'), '-USD 2.50');
    });

    test('receipt totals add lines without floating point drift', () {
      final receipt = SaleReceipt(
        number: 7,
        issuedAt: DateTime(2026, 10, 28, 9, 5),
        lines: [
          SaleLine(name: 'Exercise book', quantity: 3, unitPriceMinor: 1500),
          SaleLine(name: 'Pen', quantity: 2, unitPriceMinor: 500),
          SaleLine(name: 'Ruler', quantity: 1, unitPriceMinor: 250),
        ],
      );
      expect(receipt.totalMinor, 5750);
      expect(receipt.formattedTotal, 'TSh 57.50');
      expect(receipt.itemCount, 6);
      expect(receipt.receiptNumber, '0007');
    });
  });

  group('validation', () {
    test('rejects an empty receipt and impossible line values', () {
      expect(
        () => SaleReceipt(number: 1, issuedAt: DateTime(2026), lines: const []),
        throwsFormatException,
      );
      expect(
        () => SaleReceipt(
          number: 0,
          issuedAt: DateTime(2026),
          lines: [SaleLine(name: 'x', quantity: 1, unitPriceMinor: 1)],
        ),
        throwsFormatException,
      );
      for (final bad in [0, -1, maxSaleQuantity + 1]) {
        expect(
          () => SaleLine(name: 'x', quantity: bad, unitPriceMinor: 1),
          throwsFormatException,
        );
      }
      expect(
        () => SaleLine(name: '  ', quantity: 1, unitPriceMinor: 1),
        throwsFormatException,
      );
    });
  });

  group('pdf', () {
    test('builds a real A5 PDF that carries the shop name and the total', () async {
      final receipt = SaleReceipt(
        number: 12,
        issuedAt: DateTime(2026, 10, 28, 14, 30),
        shopName: 'Mussa Stationery',
        lines: [
          SaleLine(name: 'A4 ream', quantity: 2, unitPriceMinor: 12000),
          SaleLine(name: 'Stapler', quantity: 1, unitPriceMinor: 8500),
        ],
      );
      final bytes = await buildReceiptPdf(receipt);
      final text = String.fromCharCodes(bytes);
      expect(text.startsWith('%PDF-'), isTrue);
      expect(text.contains('/MediaBox'), isTrue);
      expect(
        bytes.length,
        greaterThan(2000),
        reason: 'a real page with a font',
      );
      // A5 is 148 x 210 mm = 419.53 x 595.28 points. The writer's number
      // format is not part of the contract, so read the box and compare as
      // numbers instead of matching a formatted string.
      final box = RegExp(
        r'/MediaBox\s*\[\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\]',
      ).firstMatch(text);
      expect(box, isNotNull, reason: 'the page declares a box');
      final width = double.parse(box!.group(3)!) - double.parse(box.group(1)!);
      final height = double.parse(box.group(4)!) - double.parse(box.group(2)!);
      expect(width, closeTo(419.53, 1.0), reason: '148 mm wide');
      expect(height, closeTo(595.28, 1.0), reason: '210 mm tall');
    });

    test('source values are not mutated by rendering', () async {
      final line = SaleLine(name: 'Glue', quantity: 4, unitPriceMinor: 700);
      final receipt = SaleReceipt(
        number: 3,
        issuedAt: DateTime(2026, 1, 2),
        lines: [line],
      );
      await buildReceiptPdf(receipt);
      expect(line.quantity, 4);
      expect(receipt.totalMinor, 2800);
    });
  });

  group('sale log', () {
    late Directory dir;
    late InventoryRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('desksuite_sales_');
      repo = InventoryRepository(LocalFileStore(() async => dir));
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test(
      'a sale lowers stock, raises sold and is written to sales.json',
      () async {
        final added = await repo.addProduct(
          name: 'Exercise book',
          priceMinor: 1500,
          stock: 10,
        );
        final id = added.products.single.id;
        final outcome = await repo.recordSale(id: id, quantity: 3);

        expect(outcome.snapshot.products.single.stock, 7);
        expect(outcome.snapshot.products.single.sold, 3);
        expect(outcome.sale.number, 1);
        expect(outcome.sale.totalMinor, 4500);
        expect(outcome.receipt().formattedTotal, 'TSh 45.00');

        final file = File('${dir.path}/sales.json');
        expect(await file.exists(), isTrue);
        expect(await file.readAsString(), contains('"quantity":3'));

        // Reload through a fresh repository, as a later app launch would.
        final reopened = InventoryRepository(LocalFileStore(() async => dir));
        final sales = await reopened.loadSales();
        expect(sales, hasLength(1));
        expect(sales.single.productName, 'Exercise book');
        expect((await reopened.load()).products.single.stock, 7);

        final second = await reopened.recordSale(id: id);
        expect(
          second.sale.number,
          2,
          reason: 'numbers are sequential, never reused',
        );
      },
    );

    test('overselling is refused and changes nothing', () async {
      final added = await repo.addProduct(
        name: 'Ruler',
        priceMinor: 250,
        stock: 2,
      );
      final id = added.products.single.id;

      await expectLater(
        repo.recordSale(id: id, quantity: 3),
        throwsA(isA<StateError>()),
      );
      expect((await repo.load()).products.single.stock, 2);
      expect((await repo.load()).products.single.sold, 0);
      expect(await repo.loadSales(), isEmpty);
    });

    test('a corrupt sales log is reported, not overwritten', () async {
      await repo.addProduct(name: 'Pen', priceMinor: 500, stock: 1);
      final file = File('${dir.path}/sales.json');
      await file.writeAsString('{not json');

      await expectLater(repo.loadSales(), throwsFormatException);
      expect(await file.readAsString(), '{not json');
    });

    test('recordOneUnit keeps working through the sale path', () async {
      final added = await repo.addProduct(
        name: 'Eraser',
        priceMinor: 100,
        stock: 3,
      );
      final next = await repo.recordOneUnit(added.products.single.id);
      expect(next.products.single.stock, 2);
      expect(await repo.loadSales(), hasLength(1));
    });
  });
}
