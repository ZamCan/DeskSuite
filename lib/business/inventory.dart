import 'dart:convert';

import '../core/ids.dart';
import '../core/local_file_store.dart';

const int maxInventoryItems = 5000;
const int maxStockCount = 1000000000;
const int maxUnitPriceMinor = 999999999999;

/// Parses a non-negative decimal amount without binary floating-point rounding.
int parseMinorAmount(String input) {
  final match = RegExp(r'^(\d{1,10})(?:\.(\d{1,2}))?$')
      .firstMatch(input.trim());
  if (match == null) {
    throw const FormatException(
      'Enter a non-negative amount with at most two decimal places.',
    );
  }
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final minor = whole * 100 + int.parse(fraction);
  if (minor > maxUnitPriceMinor) {
    throw const FormatException('Amount is too large.');
  }
  return minor;
}

String formatMinorAmount(BigInt minor) {
  final sign = minor.isNegative ? '-' : '';
  final value = minor.abs();
  return '$sign${value ~/ BigInt.from(100)}.${(value % BigInt.from(100)).toString().padLeft(2, '0')}';
}

class InventoryProduct {
  InventoryProduct({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.stock,
    required this.sold,
    Map<String, Object?> extraFields = const {},
  }) : extraFields = Map.unmodifiable(extraFields) {
    if (!isSafeId(id) ||
        name.trim().isEmpty ||
        name.length > 200 ||
        priceMinor < 0 ||
        priceMinor > maxUnitPriceMinor ||
        stock < 0 ||
        stock > maxStockCount ||
        sold < 0 ||
        sold > maxStockCount) {
      throw const FormatException('Invalid product record.');
    }
  }

  final String id;
  final String name;
  final int priceMinor;
  final int stock;
  final int sold;
  final Map<String, Object?> extraFields;

  factory InventoryProduct.fromJson(Map<String, dynamic> json) {
    try {
      return InventoryProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        priceMinor: json['priceMinor'] as int,
        stock: json['stock'] as int,
        sold: json['sold'] as int,
        extraFields: Map<String, Object?>.from(json)
          ..removeWhere(
            (key, _) => const {
              'id',
              'name',
              'priceMinor',
              'stock',
              'sold',
            }.contains(key),
          ),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid product record.');
    }
  }

  Map<String, Object?> toJson() => {
    ...extraFields,
    'id': id,
    'name': name,
    'priceMinor': priceMinor,
    'stock': stock,
    'sold': sold,
  };

  InventoryProduct recordOneUnit() {
    if (stock < 1) throw StateError('No stock available.');
    if (sold == maxStockCount) throw StateError('Sold count is at its limit.');
    return InventoryProduct(
      id: id,
      name: name,
      priceMinor: priceMinor,
      stock: stock - 1,
      sold: sold + 1,
      extraFields: extraFields,
    );
  }
}

class InventorySnapshot {
  InventorySnapshot(Iterable<InventoryProduct> products)
    : products = List.unmodifiable(products) {
    if (this.products.length > maxInventoryItems ||
        this.products.map((e) => e.id).toSet().length != this.products.length) {
      throw const FormatException('Invalid or duplicate product records.');
    }
  }
  final List<InventoryProduct> products;
  String encodeJson() =>
      jsonEncode(products.map((product) => product.toJson()).toList());
  BigInt get unitsSold =>
      products.fold(BigInt.zero, (sum, p) => sum + BigInt.from(p.sold));
  BigInt get stockValueMinor => products.fold(
    BigInt.zero,
    (sum, p) => sum + BigInt.from(p.priceMinor) * BigInt.from(p.stock),
  );
}

/// A small catalogue/stock-counter starter, not a complete point-of-sale ledger.
/// Each read-modify-write is serialized and committed atomically on disk.
class InventoryRepository {
  InventoryRepository(this.files);
  final LocalFileStore files;
  Future<void> _tail = Future.value();

  Future<T> _transaction<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<InventorySnapshot> load() async {
    final text = await files.readText('products.json', '[]');
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List || decoded.length > maxInventoryItems) {
        throw const FormatException('Invalid product catalogue.');
      }
      return InventorySnapshot(
        decoded.map(
          (entry) => InventoryProduct.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        ),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid product catalogue.');
    }
  }

  Future<InventorySnapshot> _save(List<InventoryProduct> products) async {
    final snapshot = InventorySnapshot(products);
    await files.writeText('products.json', snapshot.encodeJson());
    return snapshot;
  }

  Future<InventorySnapshot> addProduct({
    required String name,
    required int priceMinor,
    required int stock,
  }) => _transaction(() async {
    final current = await load();
    final product = InventoryProduct(
      id: newId(),
      name: name.trim(),
      priceMinor: priceMinor,
      stock: stock,
      sold: 0,
    );
    return _save([...current.products, product]);
  });

  Future<InventorySnapshot> recordOneUnit(String id) => _transaction(() async {
    if (!isSafeId(id)) {
      throw const FormatException('Invalid product identifier.');
    }
    final current = await load();
    final index = current.products.indexWhere((p) => p.id == id);
    if (index < 0) throw StateError('Product not found.');
    final next = [...current.products];
    next[index] = next[index].recordOneUnit();
    return _save(next);
  });
}
