import 'dart:io';

import 'package:desksuite/business/business_settings.dart';
import 'package:desksuite/business/sale_receipt.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currency settings default safely and persist the chosen label', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_settings_');
    addTearDown(() => dir.delete(recursive: true));
    final repository = BusinessSettingsRepository(LocalFileStore(() async => dir));
    expect((await repository.load()).currency, 'TSh');
    await repository.save(const BusinessSettings(currency: 'USD'));
    expect((await repository.load()).currency, 'USD');
    await expectLater(
      repository.save(const BusinessSettings(currency: 'NOPE')),
      throwsFormatException,
    );
    expect((await repository.load()).currency, 'USD');
  });

  test('legacy sales default to TSh and current tier records round-trip', () {
    final legacy = SaleRecord.fromJson({
      'number': 1,
      'productId': 'p1',
      'productName': 'Pen',
      'quantity': 1,
      'unitPriceMinor': 125,
      'soldAt': DateTime(2026, 1, 1).toIso8601String(),
    });
    expect(legacy.currency, 'TSh');
    expect(legacy.unitLabel, 'piece');
    expect(legacy.priceTier, 'retail');

    final sale = SaleRecord(
      number: 2,
      productId: 'p2',
      productName: 'Paper',
      quantity: 20,
      unitPriceMinor: 80,
      soldAt: DateTime(2026, 1, 2),
      currency: 'USD',
      unitLabel: 'sheet',
      priceTier: 'wholesale',
    );
    final restored = SaleRecord.fromJson(sale.toJson());
    expect(restored.currency, 'USD');
    expect(restored.unitLabel, 'sheet');
    expect(restored.priceTier, 'wholesale');
    expect(restored.totalMinor, 1600);
  });
}
