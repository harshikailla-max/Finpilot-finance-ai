import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/zxing.dart';

enum QrPayloadType {
  upi,
  gstEinvoice,
  url,
  barcode,
  text,
}

class ReceiptQrPayload {
  final bool isFound;
  final QrPayloadType type;
  final String rawText;
  final String? formatName;

  // Parsed UPI fields
  final String? upiPayeeVpa; // pa
  final String? upiPayeeName; // pn
  final double? upiAmount; // am
  final String? upiCurrency; // cu
  final String? upiTransactionNote; // tn
  final String? upiRefId; // tr

  // Parsed GST e-Invoice fields
  final String? invoiceNumber;
  final String? invoiceDate;
  final double? invoiceAmount;
  final String? sellerGstin;

  const ReceiptQrPayload({
    required this.isFound,
    this.type = QrPayloadType.text,
    this.rawText = '',
    this.formatName,
    this.upiPayeeVpa,
    this.upiPayeeName,
    this.upiAmount,
    this.upiCurrency,
    this.upiTransactionNote,
    this.upiRefId,
    this.invoiceNumber,
    this.invoiceDate,
    this.invoiceAmount,
    this.sellerGstin,
  });

  factory ReceiptQrPayload.none() => const ReceiptQrPayload(isFound: false);

  Map<String, dynamic> toJson() => {
        'isFound': isFound,
        'type': type.name,
        'rawText': rawText,
        'formatName': formatName,
        'upiPayeeVpa': upiPayeeVpa,
        'upiPayeeName': upiPayeeName,
        'upiAmount': upiAmount,
        'upiCurrency': upiCurrency,
        'upiTransactionNote': upiTransactionNote,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate,
        'invoiceAmount': invoiceAmount,
        'sellerGstin': sellerGstin,
      };
}

class ReceiptQrService {
  /// Decodes QR codes or barcodes from image bytes using ZXing in pure Dart.
  static Future<ReceiptQrPayload> decodeFromImageBytes(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        return ReceiptQrPayload.none();
      }

      // Run decoding
      final result = _scanImage(image);
      if (result != null) {
        return _parseBarcodeResult(result);
      }

      // If not found in original orientation, try 90-degree rotations
      for (final angle in [90, 180, 270]) {
        final rotated = img.copyRotate(image, angle: angle);
        final rotResult = _scanImage(rotated);
        if (rotResult != null) {
          return _parseBarcodeResult(rotResult);
        }
      }

      return ReceiptQrPayload.none();
    } catch (e) {
      debugPrint('ReceiptQrService decode error: $e');
      return ReceiptQrPayload.none();
    }
  }

  static Result? _scanImage(img.Image image) {
    try {
      final width = image.width;
      final height = image.height;
      final luminances = Uint8List(width * height);

      int idx = 0;
      for (final pixel in image) {
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        luminances[idx++] = ((r + (g << 1) + b) ~/ 4);
      }

      final source = RGBLuminanceSource.orig(width, height, luminances);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final reader = MultiFormatReader();

      const hints = DecodeHint(
        tryHarder: true,
        possibleFormats: [
          BarcodeFormat.qrCode,
          BarcodeFormat.dataMatrix,
          BarcodeFormat.aztec,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
        ],
      );

      return reader.decode(bitmap, hints);
    } catch (_) {
      return null;
    }
  }

  /// Parses raw barcode or QR text directly into structured ReceiptQrPayload.
  static ReceiptQrPayload parseBarcodeString(String text, {String? formatName}) {
    final raw = text.trim();
    final format = formatName ?? 'qrCode';

    if (raw.isEmpty) {
      return ReceiptQrPayload.none();
    }

    // 1. UPI Payment URI (e.g. upi://pay?pa=...&pn=...&am=...)
    if (raw.toLowerCase().startsWith('upi://') || raw.toLowerCase().contains('upi://pay')) {
      return _parseUpiUri(raw, format);
    }

    // 2. GST e-Invoice QR Code (JSON or key-value format)
    if (_isGstInvoice(raw)) {
      return _parseGstInvoice(raw, format);
    }

    // 3. General URL (never auto-open, display safely)
    if (raw.toLowerCase().startsWith('http://') || raw.toLowerCase().startsWith('https://')) {
      return ReceiptQrPayload(
        isFound: true,
        type: QrPayloadType.url,
        rawText: raw,
        formatName: format,
      );
    }

    // 4. Barcode or General Text
    final is1DBarcode = format.toLowerCase().contains('code') ||
        format.toLowerCase().contains('ean') ||
        format.toLowerCase().contains('upc');

    return ReceiptQrPayload(
      isFound: true,
      type: is1DBarcode ? QrPayloadType.barcode : QrPayloadType.text,
      rawText: raw,
      formatName: format,
    );
  }

  /// Parses the raw string result into structured ReceiptQrPayload.
  static ReceiptQrPayload _parseBarcodeResult(Result result) {
    return parseBarcodeString(result.text, formatName: result.barcodeFormat.name);
  }

  /// Parses UPI URI parameters: pa, pn, am, cu, tn, tr, mc
  static ReceiptQrPayload _parseUpiUri(String raw, String format) {
    try {
      final uri = Uri.parse(raw);
      final params = uri.queryParameters;

      final pa = params['pa']?.trim(); // Payee address
      final pn = params['pn']?.trim(); // Payee name
      final amStr = params['am']?.trim(); // Amount
      final cu = params['cu']?.trim() ?? 'INR'; // Currency
      final tn = params['tn']?.trim(); // Transaction note / description
      final tr = params['tr']?.trim(); // Transaction ref

      double? amount;
      if (amStr != null && amStr.isNotEmpty) {
        amount = double.tryParse(amStr);
      }

      return ReceiptQrPayload(
        isFound: true,
        type: QrPayloadType.upi,
        rawText: raw,
        formatName: format,
        upiPayeeVpa: pa,
        upiPayeeName: pn,
        upiAmount: amount,
        upiCurrency: cu,
        upiTransactionNote: tn,
        upiRefId: tr,
      );
    } catch (_) {
      // Fallback regex parsing if Uri.parse fails
      final paMatch = RegExp(r'[?&]pa=([^&]+)').firstMatch(raw);
      final pnMatch = RegExp(r'[?&]pn=([^&]+)').firstMatch(raw);
      final amMatch = RegExp(r'[?&]am=([^&]+)').firstMatch(raw);
      final tnMatch = RegExp(r'[?&]tn=([^&]+)').firstMatch(raw);

      final pa = paMatch != null ? Uri.decodeComponent(paMatch.group(1)!) : null;
      final pn = pnMatch != null ? Uri.decodeComponent(pnMatch.group(1)!) : null;
      final amStr = amMatch?.group(1);
      final tn = tnMatch != null ? Uri.decodeComponent(tnMatch.group(1)!) : null;

      final amount = amStr != null ? double.tryParse(amStr) : null;

      return ReceiptQrPayload(
        isFound: true,
        type: QrPayloadType.upi,
        rawText: raw,
        formatName: format,
        upiPayeeVpa: pa,
        upiPayeeName: pn,
        upiAmount: amount,
        upiCurrency: 'INR',
        upiTransactionNote: tn,
      );
    }
  }

  /// Checks if the payload contains GST e-invoice parameters
  static bool _isGstInvoice(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('gstin') ||
        lower.contains('totinvval') ||
        lower.contains('docno') ||
        lower.contains('irn');
  }

  /// Parses GST e-invoice details from JSON or text
  static ReceiptQrPayload _parseGstInvoice(String raw, String format) {
    try {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final gstin = json['SellerGstin']?.toString() ?? json['gstin']?.toString();
        final docNo = json['DocNo']?.toString() ?? json['doc_no']?.toString();
        final docDt = json['DocDt']?.toString() ?? json['doc_date']?.toString();
        final amt = (json['TotInvVal'] as num?)?.toDouble() ??
            double.tryParse(json['total']?.toString() ?? '');

        return ReceiptQrPayload(
          isFound: true,
          type: QrPayloadType.gstEinvoice,
          rawText: raw,
          formatName: format,
          sellerGstin: gstin,
          invoiceNumber: docNo,
          invoiceDate: docDt,
          invoiceAmount: amt,
        );
      }
    } catch (_) {}

    // Regex extraction fallback
    final gstinMatch = RegExp(r'\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b').firstMatch(raw);
    final amtMatch = RegExp(r'(?:Total|TotInvVal|Amount)[:=\s]+([0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(raw);
    final docMatch = RegExp(r'(?:DocNo|InvNo|Invoice)[:=\s]+([A-Za-z0-9\-\/]+)', caseSensitive: false).firstMatch(raw);

    return ReceiptQrPayload(
      isFound: true,
      type: QrPayloadType.gstEinvoice,
      rawText: raw,
      formatName: format,
      sellerGstin: gstinMatch?.group(0),
      invoiceNumber: docMatch?.group(1),
      invoiceAmount: amtMatch != null ? double.tryParse(amtMatch.group(1)!) : null,
    );
  }

  // ============================================================
  // IMAGE READABILITY & TRANSFORMATION UTILITIES
  // ============================================================

  /// Rotates image bytes by 90 degrees clockwise
  static Uint8List rotateClockwise(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;
      final rotated = img.copyRotate(image, angle: 90);
      return Uint8List.fromList(img.encodeJpg(rotated, quality: 90));
    } catch (_) {
      return bytes;
    }
  }

  /// Enhances image readability by increasing contrast and slight brightness
  static Uint8List enhanceReadability(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;
      final adjusted = img.adjustColor(
        image,
        contrast: 1.25,
        brightness: 1.05,
      );
      return Uint8List.fromList(img.encodeJpg(adjusted, quality: 90));
    } catch (_) {
      return bytes;
    }
  }

  /// Converts image to grayscale to improve OCR clarity on noisy receipts
  static Uint8List convertToGrayscale(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;
      final gray = img.grayscale(image);
      return Uint8List.fromList(img.encodeJpg(gray, quality: 90));
    } catch (_) {
      return bytes;
    }
  }
}
