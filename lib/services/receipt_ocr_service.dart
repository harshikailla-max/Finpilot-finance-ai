import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/receipt_model.dart';
import 'image_optimization_service.dart';
import 'receipt_parser_service.dart';
import 'receipt_qr_service.dart';
import 'receipt_suggestion_service.dart';
import 'storage_service.dart';
import 'tesseract_ocr_service.dart';

class ReceiptOcrService {
  final StorageService? storageService;

  ReceiptOcrService({this.storageService});

  /// Check receipt OCR backend health
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final baseUri = kIsWeb ? Uri.base : Uri.parse('http://localhost:8088');
      final healthUri = baseUri.resolve('/api/health/receipt');
      final resp = await http.get(healthUri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'isHealthy': false};
  }

  /// Primary OCR & Scanner pipeline: accepts image or PDF bytes,
  /// optimizes payload size, scans for embedded QR / Barcode, and recognizes text.
  Future<ReceiptOcrResult> processReceiptBytes({
    required Uint8List bytes,
    required String fileName,
    void Function(String status, double progress)? onProgress,
  }) async {
    final lowerName = fileName.toLowerCase();

    // 1. Scan for embedded QR code or barcode (UPI, GST e-invoice, retail barcode)
    ReceiptQrPayload qrPayload = ReceiptQrPayload.none();
    if (!lowerName.endsWith('.pdf')) {
      try {
        qrPayload = await ReceiptQrService.decodeFromImageBytes(bytes);
      } catch (e) {
        debugPrint('Receipt QR decode skipped or failed: $e');
      }
    }

    // 2. PDF File Text Extraction (Pure Dart, 100% Cross-Platform)
    if (lowerName.endsWith('.pdf')) {
      return _extractPdfText(bytes, fileName, qrPayload: qrPayload);
    }

    // 3. Optimize image dimensions & compress before processing to eliminate HTTP 413 & speed up OCR
    if (onProgress != null) onProgress('optimizing image', 0.05);
    final optimized = ImageOptimizationService.optimizeForOcr(bytes);
    debugPrint(
      'ReceiptOcrService: Prepared image payload ${optimized.optimizedWidth}x${optimized.optimizedHeight} '
      '(${(optimized.optimizedByteSize / 1024).toStringAsFixed(1)} KB) from original '
      '${optimized.originalWidth}x${optimized.originalHeight} (${(optimized.originalByteSize / 1024).toStringAsFixed(1)} KB)',
    );

    // 4. Image File Text Extraction via Free Tesseract.js / Vision / OCR Service
    return _extractImageText(
      optimized.bytes,
      fileName,
      qrPayload: qrPayload,
      onProgress: onProgress,
    );
  }

  /// Extracts text directly from digital or scanned PDF receipts
  Future<ReceiptOcrResult> _extractPdfText(
    Uint8List bytes,
    String fileName, {
    ReceiptQrPayload? qrPayload,
  }) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String extractedText = extractor.extractText();
      document.dispose();

      if (extractedText.trim().isEmpty) {
        return ReceiptOcrResult.failure(
          'This PDF appears to be empty or contains flattened scanned images without an embedded text layer.',
          errorType: OcrErrorType.emptyResult,
        );
      }

      final data = ReceiptParserService.parseReceiptText(
        extractedText,
        fileName: fileName,
        qrPayload: qrPayload,
      );
      return ReceiptOcrResult.success(
        rawText: extractedText,
        data: data,
        qrPayload: qrPayload,
      );
    } catch (e) {
      return ReceiptOcrResult.failure(
        'Unable to parse PDF receipt: ${e.toString().replaceAll('Exception:', '').trim()}',
        errorType: OcrErrorType.unreadable,
      );
    }
  }

  /// Extracts text from image bytes using Free On-Device Tesseract.js or available helpers
  Future<ReceiptOcrResult> _extractImageText(
    Uint8List bytes,
    String fileName, {
    ReceiptQrPayload? qrPayload,
    void Function(String status, double progress)? onProgress,
  }) async {
    // Attempt 1: Browser-based Free On-Device Tesseract.js OCR (No API key needed!)
    if (kIsWeb && TesseractOcrService.isSupported) {
      try {
        if (onProgress != null) onProgress('Initializing Tesseract OCR engine...', 0.15);
        final tesseractRes = await TesseractOcrService.recognize(
          bytes: bytes,
          onProgress: onProgress,
        );

        if (tesseractRes.isSuccess && tesseractRes.text.trim().isNotEmpty) {
          debugPrint('Tesseract.js OCR extracted ${tesseractRes.text.length} chars (conf: ${tesseractRes.confidence}%)');
          final data = ReceiptParserService.parseReceiptText(
            tesseractRes.text,
            fileName: fileName,
            qrPayload: qrPayload,
          );
          return ReceiptOcrResult.success(
            rawText: tesseractRes.text,
            data: data,
            qrPayload: qrPayload,
          );
        }
      } catch (e) {
        debugPrint('Tesseract.js browser OCR attempt failed: $e');
      }
    }

    final rawAiKey = const String.fromEnvironment('FINPILOT_AI_API_KEY', defaultValue: '');
    final rawGeminiKey = const String.fromEnvironment('FINPILOT_GEMINI_API_KEY', defaultValue: '');
    final geminiKey = storageService?.getString('ai_backend_api_key') ??
        (rawAiKey.isNotEmpty ? rawAiKey : rawGeminiKey);
    final azureKey = storageService?.getString('azure_doc_intel_key') ??
        const String.fromEnvironment('AZURE_DOCUMENT_INTELLIGENCE_KEY', defaultValue: '');
    final azureEndpoint = storageService?.getString('azure_doc_intel_endpoint') ??
        const String.fromEnvironment('AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT', defaultValue: '');

    // Attempt 2: Optional Azure Document Intelligence if user explicitly configured endpoint & key
    if (azureKey.isNotEmpty && azureEndpoint.isNotEmpty) {
      try {
        if (onProgress != null) onProgress('Connecting to Document Intelligence...', 0.4);
        final baseUri = kIsWeb ? Uri.base : Uri.parse('http://localhost:8088');
        final analyzeUri = baseUri.resolve('/api/analyze-receipt');
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        final Map<String, String> headers = {'Content-Type': 'application/json'};
        if (azureKey.isNotEmpty) headers['X-Azure-Key'] = azureKey;
        if (azureEndpoint.isNotEmpty) headers['X-Azure-Endpoint'] = azureEndpoint;

        final resp = await http
            .post(
              analyzeUri,
              headers: headers,
              body: jsonEncode({
                'base64Image': base64Image,
                'apiKey': azureKey,
                'endpoint': azureEndpoint,
              }),
            )
            .timeout(const Duration(seconds: 35));

        if (resp.statusCode == 200) {
          final resJson = jsonDecode(resp.body) as Map<String, dynamic>;
          if (resJson['isSuccess'] == true && resJson['data'] != null) {
            final parsed = _parseAzureReceiptData(
              resJson['data'] as Map<String, dynamic>,
              fileName,
              qrPayload: qrPayload,
            );
            if (parsed.isSuccess) {
              return parsed;
            }
          }
        }
      } catch (_) {}
    }

    // Attempt 3: Gemini Vision if key available in user settings
    if (geminiKey.isNotEmpty) {
      try {
        if (onProgress != null) onProgress('Analyzing receipt with Gemini Vision...', 0.5);
        final geminiResult = await _callGeminiVision(
          bytes,
          geminiKey,
          fileName,
          qrPayload: qrPayload,
        );
        if (geminiResult.isSuccess) {
          return geminiResult;
        }
      } catch (_) {}
    }

    // Attempt 4: If QR payload was found with meaningful fields (UPI or GST invoice)
    if (qrPayload != null && qrPayload.isFound) {
      final data = ReceiptParserService.parseReceiptText(
        '',
        fileName: fileName,
        qrPayload: qrPayload,
      );
      return ReceiptOcrResult.success(
        rawText: qrPayload.rawText,
        data: data,
        qrPayload: qrPayload,
      );
    }

    // Clean, user-friendly fallback
    return const ReceiptOcrResult.failure(
      'No readable text could be recognized from this receipt. Please ensure good lighting and clear alignment, or enter details in the editable preview below.',
      errorType: OcrErrorType.emptyResult,
    );
  }

  /// Call Gemini Vision API for rich image text transcription and receipt parsing
  Future<ReceiptOcrResult> _callGeminiVision(
    Uint8List bytes,
    String apiKey,
    String fileName, {
    ReceiptQrPayload? qrPayload,
  }) async {
    try {
      final mimeType = fileName.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
      );

      final prompt = '''
You are an expert OCR receipt transcription engine. Read this receipt image and transcribe all visible text line-by-line exactly as printed on the receipt.
Do not omit the store name, date, invoice number, itemized list, taxes, GSTIN, discounts, or total amount.
Output only the raw transcribed receipt text line by line.
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {'mime_type': mimeType, 'data': base64Image},
              },
            ],
          },
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 1024},
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final transcribedText = parts[0]['text'] as String? ?? '';
            if (transcribedText.trim().isNotEmpty) {
              final receiptData = ReceiptParserService.parseReceiptText(
                transcribedText,
                fileName: fileName,
                qrPayload: qrPayload,
              );
              return ReceiptOcrResult.success(
                rawText: transcribedText,
                data: receiptData,
                qrPayload: qrPayload,
              );
            }
          }
        }
        return const ReceiptOcrResult.failure(
          'Gemini Vision analyzed image but could not find legible text lines.',
          errorType: OcrErrorType.emptyResult,
        );
      }

      if (response.statusCode == 413) {
        return const ReceiptOcrResult.failure(
          'Image payload too large for Gemini Vision (HTTP 413).',
          errorType: OcrErrorType.payloadTooLarge,
          httpStatusCode: 413,
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ReceiptOcrResult.failure(
          'Gemini Vision API key invalid or unauthorized (HTTP ${response.statusCode}). Please update in Settings.',
          errorType: OcrErrorType.unauthorized,
          httpStatusCode: response.statusCode,
        );
      }
      if (response.statusCode == 429) {
        return const ReceiptOcrResult.failure(
          'Gemini Vision quota exceeded (HTTP 429). Please wait a moment or check your Google AI account.',
          errorType: OcrErrorType.rateLimited,
          httpStatusCode: 429,
        );
      }

      return ReceiptOcrResult.failure(
        'Gemini OCR returned status code ${response.statusCode}',
        errorType: OcrErrorType.serverError,
        httpStatusCode: response.statusCode,
      );
    } on TimeoutException {
      return const ReceiptOcrResult.failure(
        'Gemini Vision request timed out.',
        errorType: OcrErrorType.timeout,
      );
    } catch (e) {
      return ReceiptOcrResult.failure(
        'Gemini Vision OCR error: $e',
        errorType: OcrErrorType.networkError,
      );
    }
  }

  ReceiptOcrResult _parseAzureReceiptData(
    Map<String, dynamic> data,
    String fileName, {
    ReceiptQrPayload? qrPayload,
  }) {
    var merchant = (data['merchant'] as String?)?.trim() ?? '';
    // If merchant wasn't identified by Azure but QR has UPI payee name
    if (merchant.isEmpty &&
        qrPayload != null &&
        qrPayload.upiPayeeName != null &&
        qrPayload.upiPayeeName!.isNotEmpty) {
      merchant = qrPayload.upiPayeeName!;
    }

    final rawDate = data['date'] as String?;
    DateTime date = DateTime.now();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        date = DateTime.parse(rawDate);
      } catch (_) {}
    }

    var total = (data['total'] as num?)?.toDouble() ?? 0.0;
    if (total <= 0 &&
        qrPayload != null &&
        qrPayload.upiAmount != null &&
        qrPayload.upiAmount! > 0) {
      total = qrPayload.upiAmount!;
    }

    final subtotal = (data['subtotal'] as num?)?.toDouble();
    final tax = (data['tax'] as num?)?.toDouble();
    final currency = (data['currency'] as String?) ?? 'INR';
    final rawText = (data['rawText'] as String?) ?? '';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.90;
    final isTotalUncertain = data['isTotalUncertain'] as bool? ?? (total <= 0);

    final rawItems = data['lineItems'] as List<dynamic>? ?? [];
    final List<ReceiptLineItem> lineItems = [];
    for (final it in rawItems) {
      if (it is Map<String, dynamic>) {
        final name = (it['name'] as String?) ??
            (it['description'] as String?) ??
            'Item';
        final price = (it['price'] as num?)?.toDouble() ??
            (it['totalPrice'] as num?)?.toDouble() ??
            0.0;
        final qty = (it['quantity'] as num?)?.toInt() ?? 1;
        lineItems.add(ReceiptLineItem(
          name: name,
          price: price,
          quantity: qty > 0 ? qty : 1,
        ));
      }
    }

    // Determine category
    var category = ReceiptSuggestionService.suggestCategory(merchant);
    if (category == 'Other' && lineItems.isNotEmpty) {
      final combinedItems = lineItems.map((e) => e.name).join(' ');
      category = ReceiptSuggestionService.suggestCategory(combinedItems);
    }
    if (category == 'Other' && rawText.isNotEmpty) {
      category = ReceiptSuggestionService.suggestCategory(rawText);
    }
    if (category == 'Other') {
      category = 'Food & Dining';
    }

    // Determine payment method
    var paymentMethod = ReceiptSuggestionService.suggestPaymentMethod(rawText);
    if (qrPayload != null && qrPayload.type == QrPayloadType.upi) {
      paymentMethod = 'UPI';
    }

    final receiptData = ReceiptData(
      merchant: merchant,
      date: date,
      total: total,
      tax: tax,
      subtotal: subtotal,
      category: category,
      paymentMethod: paymentMethod,
      currency: currency,
      lineItems: lineItems,
      rawText: rawText,
      confidence: confidence,
      isTotalUncertain: isTotalUncertain,
      qrPayload: qrPayload,
    );

    return ReceiptOcrResult.success(
      rawText: rawText,
      data: receiptData,
      qrPayload: qrPayload,
    );
  }
}
