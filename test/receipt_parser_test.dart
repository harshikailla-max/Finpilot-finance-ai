import 'package:flutter_test/flutter_test.dart';
import 'package:finpilot_ai/services/receipt_parser_service.dart';

void main() {
  group('ReceiptParserService Tests', () {
    test('Correctly extracts merchant, date, total, tax, and line items from standard receipt', () {
      const sampleReceipt = '''
STARBUCKS COFFEE INDIA
Store # 4122, Indiranagar, Bangalore
GSTIN: 29AABCS1429B1Z8
Date: 15/10/2026  Time: 14:32

1x Caffe Latte         240.00
1x Blueberry Muffin    180.00
2x Chocolate Cookie    120.00

Sub Total: 540.00
CGST @ 2.5%: 13.50
SGST @ 2.5%: 13.50
Total Tax: 27.00
Grand Total: 567.00

Payment Method: UPI
UPI Ref: 4291847192
Thank you for visiting!
''';

      final result = ReceiptParserService.parseReceiptText(sampleReceipt);

      expect(result.merchant, equals('Starbucks Coffee'));
      expect(result.total, equals(567.00));
      expect(result.subtotal, equals(540.00));
      expect(result.tax, isNotNull);
      expect(result.tax!, greaterThanOrEqualTo(27.00));
      expect(result.category, equals('Food & Dining'));
      expect(result.paymentMethod, equals('UPI'));
      expect(result.date.year, equals(2026));
      expect(result.date.month, equals(10));
      expect(result.date.day, equals(15));
      expect(result.lineItems.length, greaterThanOrEqualTo(2));
      expect(
        result.lineItems.any((item) => item.name.contains('Caffe Latte')),
        isTrue,
      );
    });

    test('Parses supermarket grocery receipt with items and tax correctly', () {
      const sampleReceipt = '''
DMART HYPERMARKET
Avenue Supermarts Ltd
Date: 2026-09-18
Bill No: DM-92419

Fortune Sunlite Oil 1L    145.00
Aashirvaad Atta 5kg       260.00
Amul Butter 500g          275.00

Subtotal: 680.00
GST Included: 34.00
Total Amount: 680.00
PAID BY CASH
''';

      final result = ReceiptParserService.parseReceiptText(sampleReceipt);

      expect(result.merchant, equals('D-Mart'));
      expect(result.total, equals(680.00));
      expect(result.category, equals('Groceries'));
      expect(result.paymentMethod, equals('Cash'));
      expect(result.date.year, equals(2026));
      expect(result.date.month, equals(9));
      expect(result.date.day, equals(18));
      expect(result.lineItems.length, equals(3));
    });

    test('Handles empty or unreadable text gracefully without throwing or inventing fake data', () {
      final result = ReceiptParserService.parseReceiptText('');

      expect(result.merchant, isEmpty);
      expect(result.total, equals(0.0));
      expect(result.confidence, equals(0.0));
      expect(result.lineItems, isEmpty);
    });

    test('Parses date format DD MMM YYYY accurately', () {
      const sampleReceipt = '''
Decathlon Sports India
Date: 04 Nov 2026
Quechua Backpack 20L   499.00
Total: 499.00
Paid via Credit Card
''';

      final result = ReceiptParserService.parseReceiptText(sampleReceipt);

      expect(result.merchant, equals('Decathlon'));
      expect(result.total, equals(499.00));
      expect(result.category, equals('Shopping'));
      expect(result.paymentMethod, equals('Credit Card'));
      expect(result.date.year, equals(2026));
      expect(result.date.month, equals(11));
      expect(result.date.day, equals(4));
    });
  });
}
