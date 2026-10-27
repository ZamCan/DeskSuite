import 'dart:io';

import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'money parses as exact minor units and totals avoid floating-point errors',
    () {
      expect(parseMinorAmount('12'), 1200);
      expect(parseMinorAmount('0.05'), 5);
      expect(parseMinorAmount('7.2'), 720);
      for (final bad in ['-1', '1.234', 'NaN', '1e9', '', '10000000000.00']) {
        expect(() => parseMinorAmount(bad), throwsFormatException);
      }
      final data = InventorySnapshot([
        InventoryProduct(
          id: 'p',
          name: 'Paper',
          priceMinor: 999999999999,
          stock: 1000000000,
          sold: 2,
        ),
      ]);
      expect(data.stockValueMinor, BigInt.parse('999999999999000000000'));
      expect(formatMinorAmount(data.stockValueMinor), '9999999999990000000.00');
    },
  );

  test(
    'legacy catalogue is retained and concurrent stock updates do not oversell',
    () async {
      final dir = await Directory.systemTemp.createTemp('desksuite_inventory_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/products.json');
      await file.writeAsString(
        '[{"id":"123","name":"Paper","priceMinor":1250,"stock":1,"sold":0,"supplier":"existing field"}]',
      );
      final repo = InventoryRepository(LocalFileStore(() async => dir));
      expect((await repo.load()).products.single.name, 'Paper');
      final first = repo.recordOneUnit('123');
      final second = expectLater(repo.recordOneUnit('123'), throwsStateError);
      final updated = await first;
      await second;
      expect(updated.products.single.stock, 0);
      expect((await repo.load()).products.single.sold, 1);
      expect(
        (await repo.load()).products.single.extraFields['supplier'],
        'existing field',
      );
      final reopened = InventoryRepository(LocalFileStore(() async => dir));
      expect((await reopened.load()).products.single.stock, 0);
    },
  );

  test(
    'malformed catalogue and failed writes do not overwrite the old file',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'desksuite_inventory_errors_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/products.json');
      await file.writeAsString('{corrupt');
      final repo = InventoryRepository(LocalFileStore(() async => dir));
      await expectLater(repo.load(), throwsFormatException);
      await expectLater(
        repo.addProduct(name: 'Pen', priceMinor: 25, stock: 2),
        throwsFormatException,
      );
      expect(await file.readAsString(), '{corrupt');
      await file.writeAsString('[]');
      final added = await repo.addProduct(
        name: 'Pen',
        priceMinor: 25,
        stock: 2,
      );
      expect(added.products.single.name, 'Pen');
      if (!Platform.isWindows) {
        expect((await Process.run('chmod', ['500', dir.path])).exitCode, 0);
        try {
          await expectLater(
            repo.addProduct(name: 'Paper', priceMinor: 100, stock: 1),
            throwsA(isA<FileSystemException>()),
          );
        } finally {
          await Process.run('chmod', ['700', dir.path]);
        }
        expect((await repo.load()).products.map((p) => p.name), ['Pen']);
        expect(
          (await repo.addProduct(
            name: 'Paper',
            priceMinor: 100,
            stock: 1,
          )).products.length,
          2,
        );
      }
    },
  );
}
