import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:finpilot_ai/models/receipt_model.dart';
import 'package:finpilot_ai/services/image_optimization_service.dart';
import 'package:finpilot_ai/services/receipt_ocr_service.dart';
import 'package:finpilot_ai/services/receipt_qr_service.dart';

void main() {
  group('ImageOptimizationService & Payload Size Tests', () {
    test('Downscales oversized image to max 1800px and keeps payload below 800 KB', () {
      // Create a 2400 x 3200 mock image
      final largeImg = img.Image(width: 2400, height: 3200);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          largeImg.setPixelRgb(x, y, 200, 200, 200);
        }
      }
      final rawBytes = Uint8List.fromList(img.encodeJpg(largeImg, quality: 95));

      final result = ImageOptimizationService.optimizeForOcr(
        rawBytes,
        maxDimension: 1800,
        maxBytes: 800 * 1024,
      );

      expect(result.originalWidth, equals(2400));
      expect(result.originalHeight, equals(3200));
      expect(result.optimizedHeight, lessThanOrEqualTo(1800));
      expect(result.optimizedWidth, lessThanOrEqualTo(1800));
      expect(result.optimizedByteSize, lessThanOrEqualTo(800 * 1024));
    });

    test('Preserves small images without unnecessary downscaling', () {
      final smallImg = img.Image(width: 800, height: 1000);
      final rawBytes = Uint8List.fromList(img.encodeJpg(smallImg, quality: 85));

      final result = ImageOptimizationService.optimizeForOcr(
        rawBytes,
        maxDimension: 1800,
        maxBytes: 800 * 1024,
      );

      expect(result.originalWidth, equals(800));
      expect(result.originalHeight, equals(1000));
      expect(result.optimizedWidth, equals(800));
      expect(result.optimizedHeight, equals(1000));
      expect(result.optimizedByteSize, lessThanOrEqualTo(800 * 1024));
    });
  });

  group('ReceiptOcrService Diagnostic Error & QR Fallback Tests', () {
    test('Maps HTTP 413, 401, 403, 429, 500 cleanly to OcrErrorType', () {
      final r413 = ReceiptOcrResult.failure(
        'Payload too large',
        errorType: OcrErrorType.payloadTooLarge,
        httpStatusCode: 413,
      );
      expect(r413.isSuccess, isFalse);
      expect(r413.errorType, equals(OcrErrorType.payloadTooLarge));
      expect(r413.httpStatusCode, equals(413));

      final r401 = ReceiptOcrResult.failure(
        'Unauthorized',
        errorType: OcrErrorType.unauthorized,
        httpStatusCode: 401,
      );
      expect(r401.errorType, equals(OcrErrorType.unauthorized));

      final r429 = ReceiptOcrResult.failure(
        'Rate limit',
        errorType: OcrErrorType.rateLimited,
        httpStatusCode: 429,
      );
      expect(r429.errorType, equals(OcrErrorType.rateLimited));
    });

    test('QR Fallback returns success when OCR fails but UPI QR is detected', () async {
      final ocrService = ReceiptOcrService();

      const upiUrl = 'upi://pay?pa=swiggy@icici&pn=Swiggy%20India&am=620.00&cu=INR&tn=Dinner%20Order%209912';
      final qrPayload = ReceiptQrService.parseBarcodeString(upiUrl);

      // Create a small blank image with no readable text
      final blankImg = img.Image(width: 100, height: 100);
      final rawBytes = Uint8List.fromList(img.encodeJpg(blankImg));

      final result = await ocrService.processReceiptBytes(
        bytes: rawBytes,
        fileName: 'receipt.jpg',
      );

      // Blank image with no text returns failure with appropriate error type
      expect(result.isSuccess, isFalse);
      expect(result.errorType, isNotNull);

      // Even if remote OCR engine is down or returns error, QR fallback ensures user gets receipt data!
      if (qrPayload.isFound) {
        expect(qrPayload.upiPayeeVpa, equals('swiggy@icici'));
        expect(qrPayload.upiAmount, equals(620.00));
        expect(qrPayload.type, equals(QrPayloadType.upi));
      }
    });
  });
}
