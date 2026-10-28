import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/documents/stamp_signature_tools.dart';

void main() {
  group('StampSpec', () {
    test('formats a date as a stable human-readable stamp', () {
      const stamp = StampSpec(
        label: 'approved',
        color: Color(0xff28784f),
        includeDate: true,
      );
      expect(stamp.textAt(DateTime(2026, 10, 27)), 'APPROVED\n27 OCT 2026');
    });

    test('can create a stamp without a date', () {
      const stamp = StampSpec(
        label: 'PAID',
        color: Color(0xff28784f),
        includeDate: false,
      );
      expect(stamp.textAt(DateTime(2026, 10, 27)), 'PAID');
    });

    test('normalizes custom stamp labels', () {
      const stamp = StampSpec(
        label: '  For Review  ',
        color: Color(0xffb65c35),
        includeDate: false,
      );
      expect(stamp.textAt(DateTime(2026, 10, 27)), 'FOR REVIEW');
    });
  });
}
