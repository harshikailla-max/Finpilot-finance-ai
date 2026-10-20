import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:finpilot_ai/services/receipt_parser_service.dart';
import 'package:finpilot_ai/services/receipt_qr_service.dart';

void main() {
  group('ReceiptQrService & UPI / GST QR Decoding Tests', () {
    test('Decodes standard UPI URI correctly', () {
      const upiUrl = 'upi://pay?pa=merchant@okaxis&pn=Blue%20Tokai%20Coffee&am=480.50&cu=INR&tn=Cold%20Brew%20and%20Croissant';

      final payload = ReceiptQrService.parseBarcodeString(upiUrl, formatName: 'qrCode');

      expect(payload.isFound, isTrue);
      expect(payload.type, equals(QrPayloadType.upi));
      expect(payload.upiPayeeVpa, equals('merchant@okaxis'));
      expect(payload.upiPayeeName, equals('Blue Tokai Coffee'));
      expect(payload.upiAmount, equals(480.50));
      expect(payload.upiCurrency, equals('INR'));
      expect(payload.upiTransactionNote, equals('Cold Brew and Croissant'));
    });

    test('Decodes minimal UPI URI without amount or note', () {
      const upiUrl = 'upi://pay?pa=store99@upi&pn=Corner%20Grocery';

      final payload = ReceiptQrService.parseBarcodeString(upiUrl, formatName: 'qrCode');

      expect(payload.isFound, isTrue);
      expect(payload.type, equals(QrPayloadType.upi));
      expect(payload.upiPayeeVpa, equals('store99@upi'));
      expect(payload.upiPayeeName, equals('Corner Grocery'));
      expect(payload.upiAmount, isNull);
      expect(payload.upiTransactionNote, isNull);
    });

    test('Decodes GST e-Invoice QR JSON format', () {
      final gstJson = jsonEncode({
        'SellerGstin': '29ABCDE1234F1Z5',
        'BuyerGstin': '29XYZAB9876C1Z2',
        'DocNo': 'INV-2026-9041',
        'DocDt': '2026-10-15',
        'TotInvVal': 3450.75,
        'Irn': '7a4b89324e9f3b12984501238abcf0123456789abcdef0123456789abcdef012',
      });

      final payload = ReceiptQrService.parseBarcodeString(gstJson, formatName: 'qrCode');

      expect(payload.isFound, isTrue);
      expect(payload.type, equals(QrPayloadType.gstEinvoice));
      expect(payload.sellerGstin, equals('29ABCDE1234F1Z5'));
      expect(payload.invoiceNumber, equals('INV-2026-9041'));
      expect(payload.invoiceAmount, equals(3450.75));
      expect(payload.rawText, contains('INV-2026-9041'));
    });

    test('Handles 1D barcode and general web URL safely without auto-navigation', () {
      const barcodeStr = '8901030912345';
      final barcodePayload = ReceiptQrService.parseBarcodeString(barcodeStr, formatName: 'ean13');

      expect(barcodePayload.isFound, isTrue);
      expect(barcodePayload.type, equals(QrPayloadType.barcode));
      expect(barcodePayload.rawText, equals(barcodeStr));

      const webUrl = 'https://finpilot.ai/receipts/verify?id=99281';
      final urlPayload = ReceiptQrService.parseBarcodeString(webUrl, formatName: 'qrCode');

      expect(urlPayload.isFound, isTrue);
      expect(urlPayload.type, equals(QrPayloadType.url));
      expect(urlPayload.rawText, equals(webUrl));
    });

    test('Parser integrates UPI QR payload seamlessly into ReceiptData', () {
      const upiUrl = 'upi://pay?pa=starbucks@hdfcbank&pn=Starbucks%20India&am=395.00&cu=INR&tn=Invoice%2049281';
      final qrPayload = ReceiptQrService.parseBarcodeString(upiUrl);

      const ocrText = '''
        STARBUCKS COFFEE INDIA
        GSTIN: 27AABCS1429B1Z1
        Date: 15/10/2026
        Java Chip Frappuccino  350.00
        CGST 2.5%              8.75
        SGST 2.5%              8.75
        Total Amount:         395.00
      ''';

      final receipt = ReceiptParserService.parseReceiptText(ocrText, qrPayload: qrPayload);

      expect(receipt.total, equals(395.00));
      expect(receipt.isTotalUncertain, isFalse);
      expect(receipt.merchant.toLowerCase(), contains('starbucks'));
      expect(receipt.gstin, equals('27AABCS1429B1Z1'));
      expect(receipt.qrPayload, isNotNull);
      expect(receipt.qrPayload!.upiPayeeVpa, equals('starbucks@hdfcbank'));
    });

    test('Image transformation utilities rotate, enhance contrast, and convert to grayscale', () {
      // Create a small test image (10x10)
      final testImg = img.Image(width: 10, height: 10);
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          testImg.setPixelRgba(x, y, 100, 150, 200, 255);
        }
      }
      final rawPng = Uint8List.fromList(img.encodePng(testImg));

      // Test 90 degree clockwise rotation
      final rotatedBytes = ReceiptQrService.rotateClockwise(rawPng);
      final rotatedImg = img.decodeImage(rotatedBytes);
      expect(rotatedImg, isNotNull);
      expect(rotatedImg!.width, equals(10));
      expect(rotatedImg.height, equals(10));

      // Test enhance readability
      final enhancedBytes = ReceiptQrService.enhanceReadability(rawPng);
      final enhancedImg = img.decodeImage(enhancedBytes);
      expect(enhancedImg, isNotNull);

      // Test convert to grayscale
      final grayBytes = ReceiptQrService.convertToGrayscale(rawPng);
      final decodedGray = img.decodeImage(grayBytes);
      expect(decodedGray, isNotNull);
      expect(decodedGray!.width, equals(10));
    });
  });
}
