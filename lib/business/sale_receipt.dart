import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../office/office_pdf.dart' show deskSuitePdfTheme;

/// Upper bounds for a sale. They exist so a corrupt or hostile file cannot make
/// the app allocate an unbounded receipt.
const int maxSaleLines = 40;
const int maxSaleQuantity = 999;
const int maxUnitPriceMinor = 1000000000;
const int maxSalesRetained = 400;
const int maxRefundsPerSale = 40;
const int maxRefundNoteLength = 200;

/// How a customer paid. Stored as a stable id so a receipt read years later
/// is not tied to a UI label.
const List<String> salePaymentMethods = ['cash', 'mobile', 'card', 'transfer'];

/// The operator-facing name of an id from [salePaymentMethods], or `null` when
/// no method was recorded.
String? salePaymentMethodLabel(String? method) => switch (method) {
  'cash' => 'Cash',
  'mobile' => 'Mobile money',
  'card' => 'Card',
  'transfer' => 'Bank transfer',
  _ => null,
};

/// `2026-11-10 14:32`, in local time, for receipts and refund notes.
String formatSaleTimestamp(DateTime moment) {
  final local = moment.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// One refund event on a receipt: which units came back, when, and why.
class SaleRefund {
  SaleRefund({
    required this.at,
    required Map<String, int> quantities,
    this.reason,
  }) : quantities = Map.unmodifiable(quantities) {
    if (this.quantities.isEmpty || this.quantities.length > maxSaleLines) {
      throw const FormatException('Invalid refund.');
    }
    for (final entry in this.quantities.entries) {
      if (entry.key.isEmpty ||
          entry.key.length > 64 ||
          entry.value < 1 ||
          entry.value > maxSaleQuantity) {
        throw const FormatException('Invalid refund.');
      }
    }
    if (reason != null &&
        (reason!.trim().isEmpty || reason!.length > maxRefundNoteLength)) {
      throw const FormatException('Invalid refund.');
    }
  }

  final DateTime at;

  /// Units given back per product id.
  final Map<String, int> quantities;

  /// The optional operator note stored with this refund.
  final String? reason;

  int get units => quantities.values.fold(0, (sum, value) => sum + value);

  factory SaleRefund.fromJson(Map<String, dynamic> json) {
    try {
      final rawItems = json['items'];
      if (rawItems is! List) throw const FormatException('Invalid refund.');
      final quantities = <String, int>{};
      for (final entry in rawItems) {
        if (entry is! Map) throw const FormatException('Invalid refund.');
        final productId = entry['productId'] as String;
        final quantity = entry['quantity'] as int;
        if (quantities.containsKey(productId)) {
          throw const FormatException('Invalid refund.');
        }
        quantities[productId] = quantity;
      }
      return SaleRefund(
        at: DateTime.parse(json['at'] as String),
        quantities: quantities,
        reason: json['reason'] as String?,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid refund.');
    }
  }

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'items': [
      for (final entry in quantities.entries)
        {'productId': entry.key, 'quantity': entry.value},
    ],
    if (reason != null) 'reason': reason,
  };
}

/// One line of a sale, priced in minor units of the shop currency.
class SaleLine {
  SaleLine({
    required this.name,
    required this.quantity,
    required this.unitPriceMinor,
  }) {
    if (name.trim().isEmpty ||
        // A sale line may append a 24-character unit to a 200-character name.
        name.length > 227 ||
        quantity < 1 ||
        quantity > maxSaleQuantity ||
        unitPriceMinor < 0 ||
        unitPriceMinor > maxUnitPriceMinor) {
      throw const FormatException('Invalid sale line.');
    }
  }

  final String name;
  final int quantity;
  final int unitPriceMinor;

  int get totalMinor => quantity * unitPriceMinor;
}

/// One purchased product inside a stored sale. A cart sale keeps these so a
/// single receipt can cover several products for one customer; older
/// single-product records store only the top-level fields.
class SaleItem {
  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    this.unitLabel = 'piece',
    this.priceTier = 'retail',
  }) {
    if (productId.isEmpty ||
        productId.length > 64 ||
        productName.trim().isEmpty ||
        productName.length > 200 ||
        quantity < 1 ||
        quantity > maxSaleQuantity ||
        unitPriceMinor < 0 ||
        unitPriceMinor > maxUnitPriceMinor ||
        unitLabel.trim().isEmpty ||
        unitLabel.length > 24 ||
        !const {'retail', 'wholesale'}.contains(priceTier)) {
      throw const FormatException('Invalid sale line item.');
    }
  }

  final String productId;
  final String productName;
  final int quantity;
  final int unitPriceMinor;
  final String unitLabel;
  final String priceTier;

  int get totalMinor => quantity * unitPriceMinor;

  SaleLine toLine() => SaleLine(
    name: '$productName ($unitLabel)',
    quantity: quantity,
    unitPriceMinor: unitPriceMinor,
  );

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    try {
      return SaleItem(
        productId: json['productId'] as String,
        productName: json['productName'] as String,
        quantity: json['quantity'] as int,
        unitPriceMinor: json['unitPriceMinor'] as int,
        unitLabel: json['unitLabel'] as String? ?? 'piece',
        priceTier: json['priceTier'] as String? ?? 'retail',
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid sale line item.');
    }
  }

  Map<String, Object?> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unitPriceMinor': unitPriceMinor,
    'unitLabel': unitLabel,
    'priceTier': priceTier,
  };
}

/// A completed sale, ready to be rendered as a receipt.
class SaleReceipt {
  SaleReceipt({
    required this.number,
    required this.issuedAt,
    required Iterable<SaleLine> lines,
    this.shopName = 'DeskSuite Stationery',
    this.currency = 'TSh',
    this.paymentMethod,
    this.refundSummary,
  }) : lines = List.unmodifiable(lines) {
    if (number < 1 || number > 999999) {
      throw const FormatException('Invalid receipt number.');
    }
    if (paymentMethod != null && !salePaymentMethods.contains(paymentMethod)) {
      throw const FormatException('Invalid payment method.');
    }
    if (refundSummary != null &&
        (refundSummary!.trim().isEmpty || refundSummary!.length > 300)) {
      throw const FormatException('Invalid refund summary.');
    }
    if (shopName.trim().isEmpty || shopName.length > 120) {
      throw const FormatException('Invalid shop name.');
    }
    if (currency.isEmpty || currency.length > 8) {
      throw const FormatException('Invalid currency label.');
    }
    if (this.lines.isEmpty || this.lines.length > maxSaleLines) {
      throw const FormatException(
        'A receipt needs between 1 and $maxSaleLines lines.',
      );
    }
  }

  final int number;
  final DateTime issuedAt;
  final String shopName;
  final String currency;
  final List<SaleLine> lines;

  /// How the customer paid, printed when it was recorded.
  final String? paymentMethod;

  /// One truthful line about refunds already given back, if any.
  final String? refundSummary;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
  int get totalMinor => lines.fold(0, (sum, line) => sum + line.totalMinor);
  String get formattedTotal =>
      formatGroupedMoney(totalMinor, currency: currency);
  String get receiptNumber => number.toString().padLeft(4, '0');
}

/// Groups the integer part in threes: `1234567` -> `12,345.67`.
String formatGroupedMoney(int minor, {String currency = 'TSh'}) {
  final negative = minor < 0;
  final value = minor.abs();
  final whole = (value ~/ 100).toString();
  final cents = (value % 100).toString().padLeft(2, '0');
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${negative ? '-' : ''}$currency $buffer.$cents';
}

/// A sale as it is stored on disk, so a receipt can be reprinted later.
class SaleRecord {
  SaleRecord({
    required this.number,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.soldAt,
    this.currency = 'TSh',
    this.unitLabel = 'piece',
    this.priceTier = 'retail',
    this.items = const [],
    this.refundedAt,
    this.refundReason,
    this.paymentMethod,
    this.refunds = const [],
  }) {
    if (number < 1 ||
        productId.isEmpty ||
        productName.trim().isEmpty ||
        productName.length > 200 ||
        quantity < 1 ||
        quantity > maxSaleQuantity ||
        unitPriceMinor < 0 ||
        unitPriceMinor > maxUnitPriceMinor ||
        currency.trim().isEmpty ||
        currency.length > 8 ||
        unitLabel.trim().isEmpty ||
        unitLabel.length > 24 ||
        !const {'retail', 'wholesale'}.contains(priceTier) ||
        (paymentMethod != null &&
            !salePaymentMethods.contains(paymentMethod)) ||
        (refundedAt == null && refundReason != null) ||
        (refundReason != null &&
            (refundReason!.trim().isEmpty ||
                refundReason!.length > maxRefundNoteLength)) ||
        refunds.length > maxRefundsPerSale) {
      throw const FormatException('Invalid sale record.');
    }
    if (items.isNotEmpty &&
        (items.length > maxSaleLines ||
            items.map((item) => item.productId).toSet().length !=
                items.length)) {
      throw const FormatException('Invalid sale record.');
    }
    // A refund may only give back units this receipt actually sold, and the
    // file must never describe more refunded units than sold ones.
    final sold = <String, int>{
      if (items.isEmpty) productId: quantity,
      for (final item in items) item.productId: item.quantity,
    };
    final returned = <String, int>{};
    for (final refund in refunds) {
      for (final entry in refund.quantities.entries) {
        if (!sold.containsKey(entry.key)) {
          throw const FormatException('Invalid sale record.');
        }
        if ((returned[entry.key] ?? 0) + entry.value > sold[entry.key]!) {
          throw const FormatException('Invalid sale record.');
        }
        returned[entry.key] = (returned[entry.key] ?? 0) + entry.value;
      }
    }
    if (refundedAt != null && refunds.isNotEmpty) {
      // A receipt marked refunded in full must account for every unit.
      for (final entry in sold.entries) {
        if ((returned[entry.key] ?? 0) != entry.value) {
          throw const FormatException('Invalid sale record.');
        }
      }
    }
  }

  final int number;
  final String productId;
  final String productName;
  final int quantity;
  final int unitPriceMinor;
  final DateTime soldAt;
  final String currency;
  final String unitLabel;
  final String priceTier;

  /// Cart lines when this record covers several products for one customer,
  /// or an empty list for a single-product sale.
  final List<SaleItem> items;

  /// When this sale was refunded, or `null` while it stands.
  final DateTime? refundedAt;

  /// The optional operator note stored with a refund.
  final String? refundReason;

  /// How the customer paid, or `null` when no method was recorded (every sale
  /// written before payment methods existed, and quick one-tap sales).
  final String? paymentMethod;

  /// Every refund given back against this receipt, oldest first.
  final List<SaleRefund> refunds;

  bool get isCartSale => items.isNotEmpty;

  /// Every unit on the receipt, across cart lines.
  int get totalUnits =>
      isCartSale ? items.fold(0, (sum, item) => sum + item.quantity) : quantity;

  /// The receipt's lines, including the synthetic line of a single-product
  /// sale, so callers never have to special-case the two stored shapes.
  List<SaleItem> get lineItems => isCartSale
      ? items
      : [
          SaleItem(
            productId: productId,
            productName: productName,
            quantity: quantity,
            unitPriceMinor: unitPriceMinor,
            unitLabel: unitLabel,
            priceTier: priceTier,
          ),
        ];

  /// This receipt's unit price for [productId]; 0 when it is not on it.
  int unitPriceFor(String productId) {
    for (final item in lineItems) {
      if (item.productId == productId) return item.unitPriceMinor;
    }
    return 0;
  }

  /// Units of [productId] that this receipt sold.
  int soldUnitsFor(String productId) => lineItems
      .where((item) => item.productId == productId)
      .fold(0, (sum, item) => sum + item.quantity);

  /// Units of [productId] already given back. A receipt voided by an older
  /// version has no per-line refund history, so it counts as fully returned.
  int refundedUnitsFor(String productId) {
    if (refundedAt != null) return soldUnitsFor(productId);
    return refunds.fold(
      0,
      (sum, refund) => sum + (refund.quantities[productId] ?? 0),
    );
  }

  /// Units of [productId] that can still be refunded.
  int remainingUnitsFor(String productId) =>
      soldUnitsFor(productId) - refundedUnitsFor(productId);

  /// What is still refundable per product; products already fully refunded are
  /// left out so a dialog can never offer a zero-unit refund.
  Map<String, int> get remainingUnitsByProduct => {
    for (final item in lineItems)
      if (remainingUnitsFor(item.productId) > 0)
        item.productId: remainingUnitsFor(item.productId),
  };

  /// Units given back so far, across every refund on this receipt.
  int get unitsRefunded => refundedAt != null
      ? totalUnits
      : refunds.fold(0, (sum, refund) => sum + refund.units);

  /// Units that have not been refunded.
  int get remainingUnits => totalUnits - unitsRefunded;

  /// Whether nothing on this receipt is still standing.
  bool get isRefunded => remainingUnits == 0;

  bool get isPartiallyRefunded => unitsRefunded > 0 && remainingUnits > 0;

  /// The money given back so far, at the prices this receipt was sold at.
  int get refundedMinor => refundedAt != null
      ? totalMinor
      : lineItems.fold(
          0,
          (sum, item) =>
              sum + refundedUnitsFor(item.productId) * item.unitPriceMinor,
        );

  /// A short printable summary of the refund state, or `null` when none was
  /// recorded. It never claims a refund that is not in the stored history.
  String? get refundSummary {
    if (unitsRefunded == 0) return null;
    final moment = refunds.isEmpty ? refundedAt! : refunds.last.at;
    final note = refunds.isEmpty ? refundReason : refunds.last.reason;
    final base = isRefunded
        ? 'Refunded in full on ${formatSaleTimestamp(moment)}'
        : 'Refunded $unitsRefunded of $totalUnits unit(s) on '
              '${formatSaleTimestamp(moment)}';
    return note == null ? base : '$base · $note';
  }

  /// Returns a copy with [quantities] units given back at [at]. Giving back
  /// more units than remain, or a product that is not on the receipt, is
  /// refused instead of silently clamping.
  SaleRecord withRefund({
    required DateTime at,
    required Map<String, int> quantities,
    String? reason,
  }) {
    if (isRefunded) {
      throw StateError('Receipt $receiptNumber is already refunded in full.');
    }
    if (quantities.isEmpty) {
      throw const FormatException('Choose at least one unit to refund.');
    }
    final remaining = remainingUnitsByProduct;
    for (final entry in quantities.entries) {
      if (entry.value < 1) {
        throw const FormatException('Choose at least one unit to refund.');
      }
      final left = remaining[entry.key] ?? 0;
      if (entry.value > left) {
        throw StateError(
          'Receipt $receiptNumber has only $left unit(s) of that product '
          'left to refund.',
        );
      }
    }
    final trimmed = reason?.trim();
    final normalized = trimmed == null || trimmed.isEmpty ? null : trimmed;
    final event = SaleRefund(
      at: at,
      quantities: quantities,
      reason: normalized,
    );
    final completed = remaining.keys.every(
      (id) => (remaining[id] ?? 0) <= (quantities[id] ?? 0),
    );
    return SaleRecord(
      number: number,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPriceMinor: unitPriceMinor,
      soldAt: soldAt,
      currency: currency,
      unitLabel: unitLabel,
      priceTier: priceTier,
      items: items,
      paymentMethod: paymentMethod,
      refunds: [...refunds, event],
      refundedAt: completed ? at : null,
      refundReason: completed ? normalized : null,
    );
  }

  /// Voids whatever is still standing on this receipt. Refunding twice is
  /// refused.
  SaleRecord markRefunded({required DateTime at, String? reason}) {
    if (isRefunded) throw StateError('This sale is already refunded.');
    return withRefund(
      at: at,
      quantities: remainingUnitsByProduct,
      reason: reason,
    );
  }

  String get receiptNumber => number.toString().padLeft(4, '0');

  int get totalMinor => isCartSale
      ? items.fold(0, (sum, item) => sum + item.totalMinor)
      : quantity * unitPriceMinor;

  SaleLine toLine() => SaleLine(
    name: '$productName ($unitLabel)',
    quantity: quantity,
    unitPriceMinor: unitPriceMinor,
  );

  /// The receipt lines this record produces, honouring cart sales.
  List<SaleLine> toLines() =>
      isCartSale ? [for (final item in items) item.toLine()] : [toLine()];

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    try {
      final rawItems = json['items'];
      final items = <SaleItem>[];
      if (rawItems is List) {
        if (rawItems.length > maxSaleLines) {
          throw const FormatException('Invalid sale record.');
        }
        for (final entry in rawItems) {
          if (entry is! Map) {
            throw const FormatException('Invalid sale record.');
          }
          items.add(SaleItem.fromJson(Map<String, dynamic>.from(entry)));
        }
      } else if (rawItems != null) {
        throw const FormatException('Invalid sale record.');
      }
      return SaleRecord(
        number: json['number'] as int,
        productId: json['productId'] as String,
        productName: json['productName'] as String,
        quantity: json['quantity'] as int,
        unitPriceMinor: json['unitPriceMinor'] as int,
        soldAt: DateTime.parse(json['soldAt'] as String),
        currency: json['currency'] as String? ?? 'TSh',
        unitLabel: json['unitLabel'] as String? ?? 'piece',
        priceTier: json['priceTier'] as String? ?? 'retail',
        items: items,
        refundedAt: switch (json['refundedAt']) {
          final String value => DateTime.parse(value),
          null => null,
          _ => throw const FormatException('Invalid sale record.'),
        },
        refundReason: json['refundReason'] as String?,
        paymentMethod: json['paymentMethod'] as String?,
        refunds: switch (json['refunds']) {
          final List raw => [
            for (final entry in raw)
              SaleRefund.fromJson(Map<String, dynamic>.from(entry as Map)),
          ],
          null => const [],
          _ => throw const FormatException('Invalid sale record.'),
        },
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid sale record.');
    }
  }

  Map<String, Object?> toJson() => {
    'number': number,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unitPriceMinor': unitPriceMinor,
    'soldAt': soldAt.toIso8601String(),
    'currency': currency,
    'unitLabel': unitLabel,
    'priceTier': priceTier,
    if (isCartSale) 'items': [for (final item in items) item.toJson()],
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (refundedAt != null) 'refundedAt': refundedAt!.toIso8601String(),
    if (refundReason != null) 'refundReason': refundReason,
    if (refunds.isNotEmpty)
      'refunds': [for (final refund in refunds) refund.toJson()],
  };
}

/// Builds a real A5 PDF receipt. Text uses the embedded Noto Sans theme so
/// currency symbols and non-Latin shop names are not silently dropped.
Future<Uint8List> buildReceiptPdf(
  SaleReceipt receipt, {
  pw.ThemeData? theme,
}) async {
  final resolved = theme ?? await deskSuitePdfTheme();
  final document = pw.Document(
    theme: resolved,
    title: 'Receipt ${receipt.receiptNumber}',
  );
  final issued = receipt.issuedAt;
  final stamp =
      '${issued.year.toString().padLeft(4, '0')}-'
      '${issued.month.toString().padLeft(2, '0')}-'
      '${issued.day.toString().padLeft(2, '0')} '
      '${issued.hour.toString().padLeft(2, '0')}:'
      '${issued.minute.toString().padLeft(2, '0')}';

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        148 * PdfPageFormat.mm,
        210 * PdfPageFormat.mm,
        marginAll: 12 * PdfPageFormat.mm,
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            receipt.shopName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Receipt ${receipt.receiptNumber} · $stamp',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (receipt.paymentMethod != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Paid by ${salePaymentMethodLabel(receipt.paymentMethod)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 0.7),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(flex: 5, child: pw.Text('Item', style: _head)),
              pw.SizedBox(width: 28, child: pw.Text('Qty', style: _head)),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  'Unit',
                  style: _head,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  'Amount',
                  style: _head,
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.4),
          ...receipt.lines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      line.name,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.SizedBox(
                    width: 28,
                    child: pw.Text(
                      '${line.quantity}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      formatGroupedMoney(
                        line.unitPriceMinor,
                        currency: receipt.currency,
                      ),
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      formatGroupedMoney(
                        line.totalMinor,
                        currency: receipt.currency,
                      ),
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.7),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${receipt.itemCount} item(s)',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Text(
                receipt.formattedTotal,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          if (receipt.refundSummary != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              receipt.refundSummary!,
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ],
          pw.Spacer(),
          pw.Divider(thickness: 0.4),
          pw.Text(
            'Internal sales receipt from DeskSuite. Not a tax invoice or an '
            'official fiscal receipt. Keep it for your own records.',
            style: const pw.TextStyle(fontSize: 7.5),
          ),
        ],
      ),
    ),
  );
  return document.save();
}

final pw.TextStyle _head = pw.TextStyle(
  fontSize: 8,
  fontWeight: pw.FontWeight.bold,
);
