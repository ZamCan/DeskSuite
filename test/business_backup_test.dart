import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/business/business_backup.dart';
import 'package:desksuite/business/business_settings.dart';
import 'package:desksuite/business/inventory.dart';
import 'package:desksuite/core/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sourceDir;
  late Directory targetDir;
  late LocalFileStore sourceFiles;
  late LocalFileStore targetFiles;
  late InventoryRepository sourceRepository;
  late InventoryRepository targetRepository;

  setUp(() async {
    sourceDir = await Directory.systemTemp.createTemp('desksuite_backup_src_');
    targetDir = await Directory.systemTemp.createTemp('desksuite_backup_dst_');
    sourceFiles = LocalFileStore(() async => sourceDir);
    targetFiles = LocalFileStore(() async => targetDir);
    sourceRepository = InventoryRepository(sourceFiles);
    targetRepository = InventoryRepository(targetFiles);
  });

  tearDown(() async {
    await sourceDir.delete(recursive: true);
    await targetDir.delete(recursive: true);
  });

  Future<String> seedShop() async {
    await sourceRepository.addProduct(
      name: 'Blue pen',
      priceMinor: 1500,
      stock: 10,
      unitLabel: 'piece',
      wholesalePriceMinor: 1200,
    );
    final products = await sourceRepository.load();
    await sourceRepository.recordCartSale(
      lines: [CartSaleLineRequest(productId: products.products.single.id, quantity: 2)],
      currency: 'TSh',
    );
    final settingsFiles = LocalFileStore(() async => sourceDir);
    await BusinessSettingsRepository(
      settingsFiles,
    ).save(const BusinessSettings(currency: 'USD'));
    final encoded = await readBusinessBackupSource(
      dataFiles: sourceFiles,
      settingsFiles: settingsFiles,
    );
    return encodeBusinessBackup(
      products: encoded.products,
      sales: encoded.sales,
      settings: encoded.settings,
      createdAt: '2026-10-31T10:00:00.000Z',
    );
  }

  test('a seeded shop round-trips through the backup document unchanged', () async {
    final encoded = await seedShop();
    final backup = decodeBusinessBackup(encoded);
    expect(backup.products.length, 1);
    expect(backup.products.single.name, 'Blue pen');
    expect(backup.products.single.wholesalePriceMinor, 1200);
    expect(backup.sales.single.isCartSale, isTrue);
    expect(backup.sales.single.items.single.quantity, 2);
    expect(backup.settings.currency, 'USD');
    expect(backup.createdAt, '2026-10-31T10:00:00.000Z');

    await restoreBusinessBackup(
      backup,
      dataFiles: targetFiles,
      settingsFiles: targetFiles,
    );
    final restoredCatalogue = await targetRepository.load();
    expect(restoredCatalogue.products.single.name, 'Blue pen');
    expect(restoredCatalogue.products.single.stock, 8);
    final restoredSales = await targetRepository.loadSales();
    expect(restoredSales.single.totalMinor, 3000);
    final restoredSettings = await BusinessSettingsRepository(
      targetFiles,
    ).load();
    expect(restoredSettings.currency, 'USD');
  });

  test('an empty shop produces a valid backup', () async {
    final source = await readBusinessBackupSource(
      dataFiles: sourceFiles,
      settingsFiles: LocalFileStore(() async => sourceDir),
    );
    final encoded = encodeBusinessBackup(
      products: source.products,
      sales: source.sales,
      settings: source.settings,
    );
    final backup = decodeBusinessBackup(encoded);
    expect(backup.products, isEmpty);
    expect(backup.sales, isEmpty);
    expect(backup.settings.currency, 'TSh');
  });

  test('malformed or foreign documents are refused', () {
    expect(() => decodeBusinessBackup('not json'), throwsFormatException);
    expect(() => decodeBusinessBackup('[1,2]'), throwsFormatException);
    expect(
      () => decodeBusinessBackup(jsonEncode({'schema': 99, 'products': []})),
      throwsFormatException,
    );
    expect(
      () => decodeBusinessBackup(
        jsonEncode({'schema': 1, 'createdAt': 'not a date', 'products': []}),
      ),
      throwsFormatException,
    );
    // A product row with a hostile name fails model validation.
    expect(
      () => decodeBusinessBackup(
        jsonEncode({
          'schema': 1,
          'createdAt': '2026-10-31T10:00:00.000Z',
          'products': [
            {'id': 'p1', 'name': ' ', 'priceMinor': 1, 'stock': 1, 'sold': 0},
          ],
        }),
      ),
      throwsFormatException,
    );
  });

  test('restore refuses oversized payloads before touching the store', () async {
    final oversized = Uint8List(maxBackupBytes + 1);
    expect(() => parseBusinessBackupBytes(oversized), throwsFormatException);
    // Nothing was written by the refused restore attempt.
    final untouched = await targetRepository.load();
    expect(untouched.products, isEmpty);
    expect(await targetRepository.loadSales(), isEmpty);
  });

  test('picked bytes with a broken date cannot enter the store', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'schema': 1,
          'createdAt': 'tomorrow-maybe',
          'products': <Object>[],
        }),
      ),
    );
    expect(() => parseBusinessBackupBytes(bytes), throwsFormatException);
  });

  test('backup file names are stable and date-ordered', () {
    final name = businessBackupFileName(DateTime.parse('2026-10-31T17:45:09'));
    expect(name, 'desksuite-business-backup-20261031-1745.json');
    expect(RegExp(r'^[\w.-]{1,128}$').hasMatch(name), isTrue);
  });
}
