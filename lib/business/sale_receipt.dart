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

/// One line of a sale, priced in minor units of the shop currency.
class SaleLine {
  SaleLine({
    required this.name,
    required this.quantity,
    required this.unitPriceMinor,
  }) {
    if (name.trim().isEmpty ||
        name.length > 200 ||
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

/// A completed sale, ready to be rendered as a receipt.
class SaleReceipt {
  SaleReceipt({
    required this.number,
    required this.issuedAt,
    required Iterable<SaleLine> lines,
    this.shopName = 'DeskSuite Stationery',
    this.currency = 'TSh',
  }) : lines = List.unmodifiable(lines) {
    if (number < 1 || number > 999999) {
      throw const FormatException('Invalid receipt number.');
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
        !const {'retail', 'wholesale'}.contains(priceTier)) {
      throw const FormatException('Invalid sale record.');
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

  int get totalMinor => quantity * unitPriceMinor;

  SaleLine toLine() => SaleLine(
    name: '$productName ($unitLabel)',
    quantity: quantity,
    unitPriceMinor: unitPriceMinor,
  );

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    try {
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
