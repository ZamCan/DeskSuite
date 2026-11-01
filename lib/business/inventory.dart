import 'dart:convert';

import 'business_settings.dart';
import 'sale_receipt.dart';

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
    this.wholesalePriceMinor,
    this.wholesaleMinQuantity = 10,
    this.unitLabel = 'piece',
    required this.stock,
    required this.sold,
    Map<String, Object?> extraFields = const {},
  }) : extraFields = Map.unmodifiable(extraFields) {
    if (!isSafeId(id) ||
        name.trim().isEmpty ||
        name.length > 200 ||
        priceMinor < 0 ||
        priceMinor > maxUnitPriceMinor ||
        (wholesalePriceMinor != null &&
            (wholesalePriceMinor! < 0 ||
                wholesalePriceMinor! > maxUnitPriceMinor)) ||
        wholesaleMinQuantity < 1 ||
        wholesaleMinQuantity > maxSaleQuantity ||
        unitLabel.trim().isEmpty ||
        unitLabel.length > 24 ||
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
  final int? wholesalePriceMinor;
  final int wholesaleMinQuantity;
  final String unitLabel;
  final int stock;
  final int sold;
  final Map<String, Object?> extraFields;

  factory InventoryProduct.fromJson(Map<String, dynamic> json) {
    try {
      return InventoryProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        priceMinor: json['priceMinor'] as int,
        wholesalePriceMinor: json['wholesalePriceMinor'] as int?,
        wholesaleMinQuantity: json['wholesaleMinQuantity'] as int? ?? 10,
        unitLabel: json['unitLabel'] as String? ?? 'piece',
        stock: json['stock'] as int,
        sold: json['sold'] as int,
        extraFields: Map<String, Object?>.from(json)
          ..removeWhere(
            (key, _) => const {
              'id',
              'name',
              'priceMinor',
              'wholesalePriceMinor',
              'wholesaleMinQuantity',
              'unitLabel',
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
    if (wholesalePriceMinor != null) 'wholesalePriceMinor': wholesalePriceMinor,
    'wholesaleMinQuantity': wholesaleMinQuantity,
    'unitLabel': unitLabel,
    'stock': stock,
    'sold': sold,
  };

  InventoryProduct recordOneUnit() => recordUnits(1);

  /// Sells [quantity] units. Refuses rather than leaving a negative stock.
  InventoryProduct recordUnits(int quantity) {
    if (quantity < 1 || quantity > maxSaleQuantity) {
      throw const FormatException('Invalid sale quantity.');
    }
    if (stock < quantity) throw StateError('No stock available.');
    if (sold + quantity > maxStockCount) {
      throw StateError('Sold count would exceed its limit.');
    }
    return InventoryProduct(
      id: id,
      name: name,
      priceMinor: priceMinor,
      wholesalePriceMinor: wholesalePriceMinor,
      wholesaleMinQuantity: wholesaleMinQuantity,
      unitLabel: unitLabel,
      stock: stock - quantity,
      sold: sold + quantity,
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
    int? wholesalePriceMinor,
    int wholesaleMinQuantity = 10,
    String unitLabel = 'piece',
  }) => _transaction(() async {
    final current = await load();
    final product = InventoryProduct(
      id: newId(),
      name: name.trim(),
      priceMinor: priceMinor,
      wholesalePriceMinor: wholesalePriceMinor,
      wholesaleMinQuantity: wholesaleMinQuantity,
      unitLabel: unitLabel.trim(),
      stock: stock,
      sold: 0,
    );
    return _save([...current.products, product]);
  });

  /// Reads the sale log. A corrupt log is reported, never silently repaired by
  /// overwriting it, because it is the shop's record of money taken.
  Future<List<SaleRecord>> loadSales() async {
    final text = await files.readText('sales.json', '[]');
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List || decoded.length > maxSalesRetained) {
        throw const FormatException('Invalid sales log.');
      }
      return List.unmodifiable(
        decoded.map(
          (entry) =>
              SaleRecord.fromJson(Map<String, dynamic>.from(entry as Map)),
        ),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid sales log.');
    }
  }

  /// Records a sale: stock goes down, the sold counter goes up, and the sale is
  /// appended to `sales.json` so a receipt can be reprinted later.
  ///
  /// The two files cannot be written in one atomic step. On a sales-log write
  /// error a rollback is attempted, but interruption or a failed rollback can
  /// still leave them inconsistent. This is not a transactional POS ledger.
  Future<SaleOutcome> recordSale({
    required String id,
    int quantity = 1,
    String currency = 'TSh',
    bool wholesale = false,
  }) => _transaction(() async {
    if (!isSafeId(id)) {
      throw const FormatException('Invalid product identifier.');
    }
    if (!isSupportedBusinessCurrency(currency)) {
      throw const FormatException('Choose a supported shop currency.');
    }
    final current = await load();
    final index = current.products.indexWhere((p) => p.id == id);
    if (index < 0) throw StateError('Product not found.');
    final product = current.products[index];
    if (wholesale &&
        (product.wholesalePriceMinor == null ||
            quantity < product.wholesaleMinQuantity)) {
      throw FormatException(
        'Wholesale pricing requires at least ${product.wholesaleMinQuantity} ${product.unitLabel}(s).',
      );
    }
    final unitPrice = wholesale
        ? product.wholesalePriceMinor!
        : product.priceMinor;
    final pending = List.of(await loadSales());
    final next = [...current.products];
    next[index] = product.recordUnits(quantity);
    final previousText = current.encodeJson();
    // Validate all receipt data before changing stock. The receipt engine has
    // a deliberately lower per-unit limit than the inventory-value model.
    final record = SaleRecord(
      number:
          (pending.isEmpty
              ? 0
              : pending
                    .map((sale) => sale.number)
                    .reduce((a, b) => a > b ? a : b)) +
          1,
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      unitPriceMinor: unitPrice,
      soldAt: DateTime.now(),
      currency: currency,
      unitLabel: product.unitLabel,
      priceTier: wholesale ? 'wholesale' : 'retail',
    );
    if (record.number > 999999) {
      throw StateError(
        'Receipt number limit reached; export your records before continuing.',
      );
    }
    record.toLine(); // Reject an unprintable line before the stock write.
    final snapshot = await _save(next);
    final log = [...pending, record];
    final retained = log.length > maxSalesRetained
        ? log.sublist(log.length - maxSalesRetained)
        : log;
    try {
      await files.writeText(
        'sales.json',
        jsonEncode(retained.map((sale) => sale.toJson()).toList()),
      );
    } catch (error) {
      try {
        await files.writeText('products.json', previousText);
      } catch (_) {
        throw StateError(
          'The sales log and stock rollback both failed. Check the local records and backups before continuing.',
        );
      }
      throw StateError('The sale was not recorded: $error');
    }
    return SaleOutcome(snapshot: snapshot, sale: record);
  });

  /// Records one basket sale for a customer from several catalogue products.
  ///
  /// Every line is validated before any stock changes, the whole basket is
  /// stored as a single sale record (one receipt, itemised), and the same
  /// serialized transaction and rollback protection as [recordSale] applies.
  Future<SaleOutcome> recordCartSale({
    required List<CartSaleLineRequest> lines,
    String currency = 'TSh',
  }) => _transaction(() async {
    if (lines.isEmpty) {
      throw const FormatException('A sale needs at least one item.');
    }
    if (lines.length > maxSaleLines) {
      throw const FormatException(
        'A single sale can hold at most $maxSaleLines item lines. Complete this sale and start a new one.',
      );
    }
    if (!isSupportedBusinessCurrency(currency)) {
      throw const FormatException('Choose a supported shop currency.');
    }
    final requested = lines
        .map((line) => line.productId)
        .toSet();
    if (requested.length != lines.length) {
      throw const FormatException(
        'Each catalogue product may appear once in a sale. Use its quantity field instead.',
      );
    }
    final current = await load();
    final byId = {for (final product in current.products) product.id: product};
    // Resolve and validate all lines first: a basket either completes as a
    // whole or leaves the catalogue and sales log untouched.
    final updates = <String, InventoryProduct>{};
    final items = <SaleItem>[];
    for (final line in lines) {
      final product = byId[line.productId];
      if (product == null) {
        throw StateError('A product in this sale is no longer in the catalogue.');
      }
      if (line.quantity < 1 || line.quantity > maxSaleQuantity) {
        throw const FormatException('Invalid sale quantity.');
      }
      if (product.stock < line.quantity) {
        throw StateError(
          'Not enough stock for ${product.name}: ${product.stock} left.',
        );
      }
      if (product.sold + line.quantity > maxStockCount) {
        throw StateError('Sold count would exceed its limit.');
      }
      if (line.wholesale) {
        if (product.wholesalePriceMinor == null ||
            line.quantity < product.wholesaleMinQuantity) {
          throw FormatException(
            'Wholesale pricing requires at least ${product.wholesaleMinQuantity} ${product.unitLabel}(s) of ${product.name}.',
          );
        }
      }
      updates[product.id] = product.recordUnits(line.quantity);
      items.add(
        SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: line.quantity,
          unitPriceMinor: line.wholesale
              ? product.wholesalePriceMinor!
              : product.priceMinor,
          unitLabel: product.unitLabel,
          priceTier: line.wholesale ? 'wholesale' : 'retail',
        ),
      );
    }
    final pending = List.of(await loadSales());
    final record = SaleRecord(
      number:
          (pending.isEmpty
              ? 0
              : pending
                    .map((sale) => sale.number)
                    .reduce((a, b) => a > b ? a : b)) +
          1,
      productId: items.first.productId,
      productName: items.first.productName,
      quantity: items.first.quantity,
      unitPriceMinor: items.first.unitPriceMinor,
      soldAt: DateTime.now(),
      currency: currency,
      unitLabel: items.first.unitLabel,
      priceTier: items.first.priceTier,
      items: items,
    );
    if (record.number > 999999) {
      throw StateError(
        'Receipt number limit reached; export your records before continuing.',
      );
    }
    record.toLines(); // Reject an unprintable line before the stock write.
    final next = [
      for (final product in current.products)
        updates[product.id] ?? product,
    ];
    final previousText = current.encodeJson();
    final snapshot = await _save(next);
    final log = [...pending, record];
    final retained = log.length > maxSalesRetained
        ? log.sublist(log.length - maxSalesRetained)
        : log;
    try {
      await files.writeText(
        'sales.json',
        jsonEncode(retained.map((sale) => sale.toJson()).toList()),
      );
    } catch (error) {
      try {
        await files.writeText('products.json', previousText);
      } catch (_) {
        throw StateError(
          'The sales log and stock rollback both failed. Check the local records and backups before continuing.',
        );
      }
      throw StateError('The sale was not recorded: $error');
    }
    return SaleOutcome(snapshot: snapshot, sale: record);
  });

  Future<InventorySnapshot> recordOneUnit(String id) async =>
      (await recordSale(id: id)).snapshot;
}

/// One requested cart line: which product, how many, and which price tier.
/// The repository validates every field before stock changes.
class CartSaleLineRequest {
  const CartSaleLineRequest({
    required this.productId,
    required this.quantity,
    this.wholesale = false,
  });
  final String productId;
  final int quantity;
  final bool wholesale;
}

/// The stock after a sale and the sale itself.
class SaleOutcome {
  const SaleOutcome({required this.snapshot, required this.sale});
  final InventorySnapshot snapshot;
  final SaleRecord sale;

  /// The printable receipt for this sale.
  SaleReceipt receipt({String shopName = 'DeskSuite Stationery'}) =>
      SaleReceipt(
        number: sale.number,
        issuedAt: sale.soldAt,
        shopName: shopName,
        currency: sale.currency,
        lines: sale.toLines(),
      );
}
