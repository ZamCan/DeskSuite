import 'dart:convert';
import 'dart:typed_data';

import 'business_settings.dart';
import 'inventory.dart';
import 'sale_receipt.dart';
import '../core/local_file_store.dart';

/// Version of the exported business backup file. Restoring a file whose
/// schema number differs is refused instead of guessed at.
const int businessBackupSchema = 1;

/// A bundle with 5000 bounded products and 400 stored sales stays far below
/// this limit; larger inputs are refused before anything is written.
const int maxBackupBytes = 10 * 1024 * 1024;

const String backupProductsKey = 'products.json';
const String backupSalesKey = 'sales.json';
const String backupSettingsKey = 'business-settings.json';

/// A parsed business backup. It carries validated model objects, so applying
/// it to the store reuses the same validation as normal app writes.
class BusinessBackup {
  const BusinessBackup({
    required this.products,
    required this.sales,
    required this.settings,
    required this.createdAt,
  });

  final List<InventoryProduct> products;
  final List<SaleRecord> sales;
  final BusinessSettings settings;
  final String createdAt;
}

/// Serializes the current catalogue, stored sales and shop settings into one
/// self-describing JSON document.
///
/// The result is a complete, bounded offline snapshot. A later online phase
/// (for example a Google Drive app-folder sync) can upload exactly this file
/// without touching app state again; that phase is not integrated yet and
/// needs account/consent plumbing and device testing first.
String encodeBusinessBackup({
  required List<InventoryProduct> products,
  required List<SaleRecord> sales,
  required BusinessSettings settings,
  String? createdAt,
}) {
  // Building the snapshot enforces the catalogue bounds and unique ids.
  InventorySnapshot(products);
  if (sales.length > maxSalesRetained) {
    throw const FormatException('The stored sales log is too long to back up.');
  }
  return jsonEncode({
    'schema': businessBackupSchema,
    'createdAt': createdAt ?? DateTime.now().toUtc().toIso8601String(),
    'products': [for (final product in products) product.toJson()],
    'sales': [for (final sale in sales) sale.toJson()],
    'settings': settings.toJson(),
  });
}

/// Parses and validates a business backup document. Every structural or model
/// error is reported as a [FormatException] and nothing is decoded partially.
BusinessBackup decodeBusinessBackup(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    throw const FormatException('Invalid business backup.');
  }
  if (decoded['schema'] != businessBackupSchema) {
    throw const FormatException(
      'This backup uses a different schema version. Update DeskSuite first.',
    );
  }
  final createdAt = decoded['createdAt'];
  if (createdAt is! String || !_isPlausibleTimestamp(createdAt)) {
    throw const FormatException('Invalid business backup.');
  }
  final rawProducts = decoded['products'];
  if (rawProducts is! List) {
    throw const FormatException('Invalid business backup.');
  }
  if (rawProducts.length > maxInventoryItems) {
    throw const FormatException('The backup catalogue is too large.');
  }
  final products = <InventoryProduct>[
    for (final entry in rawProducts)
      InventoryProduct.fromJson(_validateEntry(entry)),
  ];
  // Surrogate validation: bounds and duplicate ids.
  InventorySnapshot(products);
  final rawSales = decoded['sales'];
  if (rawSales is! List) {
    throw const FormatException('Invalid business backup.');
  }
  if (rawSales.length > maxSalesRetained) {
    throw const FormatException('The backup sales log is too large.');
  }
  final sales = <SaleRecord>[
    for (final entry in rawSales) SaleRecord.fromJson(_validateEntry(entry)),
  ];
  final rawSettings = decoded['settings'];
  final settings = rawSettings == null
      ? const BusinessSettings()
      : BusinessSettings.fromJson(_validateEntry(rawSettings));
  return BusinessBackup(
    products: products,
    sales: sales,
    settings: settings,
    createdAt: createdAt,
  );
}

Map<String, dynamic> _validateEntry(Object? entry) {
  if (entry is! Map) {
    throw const FormatException('Invalid business backup.');
  }
  return Map<String, dynamic>.from(entry);
}

const Duration _clockSkew = Duration(hours: 24);

bool _isPlausibleTimestamp(String text) {
  try {
    return !DateTime.parse(text).isAfter(DateTime.now().toUtc().add(_clockSkew));
  } on FormatException {
    return false;
  }
}

/// Reads the three business files and serializes them into one backup
/// document. A fresh read is taken; the caller may have older UI state.
Future<BusinessBackup> readBusinessBackupSource({
  required LocalFileStore dataFiles,
  required LocalFileStore settingsFiles,
}) async {
  final productText = await dataFiles.readText(backupProductsKey, '[]');
  final salesText = await dataFiles.readText(backupSalesKey, '[]');
  final settingsText = await settingsFiles.readText(backupSettingsKey, '');
  final products = <InventoryProduct>[
    ..._decodeJsonList(productText, 'Invalid product catalogue.').map(
      (entry) => InventoryProduct.fromJson(_validateEntry(entry)),
    ),
  ];
  final sales = <SaleRecord>[
    ..._decodeJsonList(salesText, 'Invalid sales log.').map(
      (entry) => SaleRecord.fromJson(_validateEntry(entry)),
    ),
  ];
  final settings = settingsText.trim().isEmpty
      ? const BusinessSettings()
      : BusinessSettings.fromJson(_validateEntry(_decodeJson(settingsText)));
  return BusinessBackup(
    products: products,
    sales: sales,
    settings: settings,
    createdAt: DateTime.now().toUtc().toIso8601String(),
  );
}

/// Validates a picked backup document before anything on this device changes.
BusinessBackup parseBusinessBackupBytes(Uint8List bytes) {
  if (bytes.length > maxBackupBytes) {
    throw const FormatException('This backup is too large to restore.');
  }
  late final String text;
  try {
    text = utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    throw const FormatException(
      'This file is not a valid DeskSuite business backup.',
    );
  }
  return decodeBusinessBackup(text);
}

/// Restores a validated backup. Files are written one by one with atomic
/// replacements, after the whole document has passed validation; an
/// interruption between the writes can however leave a mixed state and the
/// restore should then be run again.
Future<void> restoreBusinessBackup(
  BusinessBackup backup, {
  required LocalFileStore dataFiles,
  required LocalFileStore settingsFiles,
}) async {
  await dataFiles.writeText(
    backupProductsKey,
    jsonEncode([for (final product in backup.products) product.toJson()]),
  );
  await dataFiles.writeText(
    backupSalesKey,
    jsonEncode([for (final sale in backup.sales) sale.toJson()]),
  );
  await settingsFiles.writeText(
    backupSettingsKey,
    jsonEncode(backup.settings.toJson()),
  );
  await settingsFiles.waitForWrites();
}

/// A stable, sortable file name for shared or cloud-uploaded backups.
String businessBackupFileName(DateTime moment) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'desksuite-business-backup-'
      '${moment.year}${two(moment.month)}${two(moment.day)}-'
      '${two(moment.hour)}${two(moment.minute)}.json';
}

List _decodeJsonList(String text, String failure) {
  final decoded = _decodeJson(text);
  if (decoded is! List) {
    throw FormatException(failure);
  }
  return decoded;
}

Object _decodeJson(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Invalid business backup.');
  }
}
