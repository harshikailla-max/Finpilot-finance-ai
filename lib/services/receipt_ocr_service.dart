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

    // 3. Optimize image dimensions & compress before transmission to eliminate HTTP 413
    final optimized = ImageOptimizationService.optimizeForOcr(bytes);
    debugPrint(
      'ReceiptOcrService: Prepared image payload ${optimized.optimizedWidth}x${optimized.optimizedHeight} '
      '(${(optimized.optimizedByteSize / 1024).toStringAsFixed(1)} KB) from original '
      '${optimized.originalWidth}x${optimized.originalHeight} (${(optimized.originalByteSize / 1024).toStringAsFixed(1)} KB)',
    );

    // 4. Image File Text Extraction via Vision/OCR Service
    return _extractImageText(optimized.bytes, fileName, qrPayload: qrPayload);
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

  /// Extracts text from image bytes using configured Gemini Vision or OCR.space API
  Future<ReceiptOcrResult> _extractImageText(
    Uint8List bytes,
    String fileName, {
    ReceiptQrPayload? qrPayload,
  }) async {
    final rawAiKey = const String.fromEnvironment('FINPILOT_AI_API_KEY', defaultValue: '');
    final rawGeminiKey = const String.fromEnvironment('FINPILOT_GEMINI_API_KEY', defaultValue: '');
    final geminiKey = storageService?.getString('ai_backend_api_key') ??
        (rawAiKey.isNotEmpty ? rawAiKey : rawGeminiKey);
    final ocrKey = storageService?.getString('ocr_api_key') ??
        const String.fromEnvironment('FINPILOT_OCR_API_KEY', defaultValue: '');
    final azureKey = storageService?.getString('azure_doc_intel_key') ??
        const String.fromEnvironment('AZURE_DOCUMENT_INTELLIGENCE_KEY', defaultValue: '');
    final azureEndpoint = storageService?.getString('azure_doc_intel_endpoint') ??
        const String.fromEnvironment('AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT', defaultValue: '');

    ReceiptOcrResult? lastFailure;

    // Attempt 0: Azure Document Intelligence prebuilt-receipt model via /api/analyze-receipt
    try {
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
              if (azureKey.isNotEmpty) 'apiKey': azureKey,
              if (azureEndpoint.isNotEmpty) 'endpoint': azureEndpoint,
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
      } else if (resp.statusCode == 413) {
        lastFailure = const ReceiptOcrResult.failure(
          'Receipt image payload exceeds server/Azure limit (HTTP 413). Please retake a closer or cropped photo.',
          errorType: OcrErrorType.payloadTooLarge,
          httpStatusCode: 413,
        );
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        lastFailure = ReceiptOcrResult.failure(
          'Azure Document Intelligence authentication failed (HTTP ${resp.statusCode}). Please verify your endpoint and API key.',
          errorType: OcrErrorType.unauthorized,
          httpStatusCode: resp.statusCode,
        );
      } else if (resp.statusCode == 429) {
        lastFailure = const ReceiptOcrResult.failure(
          'Azure Document Intelligence request quota exceeded (HTTP 429). The F0 tier allows 20 calls/min. Please wait a moment.',
          errorType: OcrErrorType.rateLimited,
          httpStatusCode: 429,
        );
      }
    } catch (_) {
      // Azure endpoint unreachable, fall through to OCR proxy
    }

    // Attempt 1: Server-side OCR reverse proxy if available
    try {
      final baseUri = kIsWeb ? Uri.base : Uri.parse('http://localhost:8088');
      final ocrProxyUri = baseUri.resolve('/api/ocr');
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final resp = await http
          .post(
            ocrProxyUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'base64Image': base64Image}),
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200) {
        final resJson = jsonDecode(resp.body) as Map<String, dynamic>;
        if (resJson['isSuccess'] == true && resJson['ocrResult'] != null) {
          final parsed = _parseOcrSpaceResponse(
            resJson['ocrResult'] as Map<String, dynamic>,
            fileName,
            qrPayload: qrPayload,
          );
          if (parsed.isSuccess) {
            return parsed;
          }
        }
      } else if (resp.statusCode == 413) {
        lastFailure = const ReceiptOcrResult.failure(
          'Image payload too large for OCR server (HTTP 413). Please retake a closer or cropped photo.',
          errorType: OcrErrorType.payloadTooLarge,
          httpStatusCode: 413,
        );
      }
    } catch (_) {
      // Server-side OCR proxy not available or running standalone, fall through
    }

    // Attempt 1: Gemini Vision if key available
    if (geminiKey.isNotEmpty) {
      final geminiResult = await _callGeminiVision(
        bytes,
        geminiKey,
        fileName,
        qrPayload: qrPayload,
      );
      if (geminiResult.isSuccess) {
        return geminiResult;
      }
      lastFailure = geminiResult;
    }

    // Attempt 2: OCR.space API (Cross-platform OCR engine)
    final ocrSpaceResult = await _callOcrSpace(
      bytes,
      ocrKey.isNotEmpty ? ocrKey : 'K89815161288957',
      fileName,
      qrPayload: qrPayload,
    );
    if (ocrSpaceResult.isSuccess) {
      return ocrSpaceResult;
    }
    lastFailure = ocrSpaceResult;

    // 3. Fallback: If OCR failed, but QR payload was found with meaningful fields (UPI or GST invoice)
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

    return lastFailure;
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

  /// Call OCR.space engine with optimized payload and robust diagnostic error mapping
  Future<ReceiptOcrResult> _callOcrSpace(
    Uint8List bytes,
    String apiKey,
    String fileName, {
    ReceiptQrPayload? qrPayload,
  }) async {
    // Defensive check: enforce 1024 KB ceiling
    if (bytes.lengthInBytes > 1024 * 1024) {
      return ReceiptOcrResult.failure(
        'Receipt image size (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB) exceeds the 1024 KB server limit. Please crop to receipt boundaries.',
        errorType: OcrErrorType.payloadTooLarge,
        httpStatusCode: 413,
      );
    }

    try {
      final url = Uri.parse('https://api.ocr.space/parse/image');

      http.Response response;

      // 1. Prefer Multipart Upload: avoids 33% base64 encoding bloat
      try {
        final request = http.MultipartRequest('POST', url);
        request.headers['apikey'] = apiKey;
        request.fields['language'] = 'eng';
        request.fields['isOverlayRequired'] = 'false';
        request.fields['detectOrientation'] = 'true';
        request.fields['scale'] = 'true';
        request.fields['OCREngine'] = '2';
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName.isNotEmpty ? fileName : 'receipt.jpg',
          ),
        );

        final streamed =
            await request.send().timeout(const Duration(seconds: 22));
        response = await http.Response.fromStream(streamed);
      } catch (multipartError) {
        debugPrint(
          'Multipart upload failed or was blocked by browser ($multipartError). Falling back to base64...',
        );
        // 2. Fallback to base64 post (safe because bytes <= 800 KB)
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        response = await http
            .post(
              url,
              headers: {'apikey': apiKey},
              body: {
                'base64Image': base64Image,
                'language': 'eng',
                'isOverlayRequired': 'false',
                'detectOrientation': 'true',
                'scale': 'true',
                'OCREngine': '2',
              },
            )
            .timeout(const Duration(seconds: 22));
      }

      if (response.statusCode == 200) {
        final jsonResult = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseOcrSpaceResponse(
          jsonResult,
          fileName,
          qrPayload: qrPayload,
        );
      }

      // Handle non-200 HTTP statuses with exact diagnostic labels
      if (response.statusCode == 413) {
        return const ReceiptOcrResult.failure(
          'OCR server rejected upload: Payload Too Large (HTTP 413). FinPilot automatically compressed the image, but the upstream server rejected it. Please crop closer.',
          errorType: OcrErrorType.payloadTooLarge,
          httpStatusCode: 413,
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ReceiptOcrResult.failure(
          'OCR service authentication failed (HTTP ${response.statusCode}). Please verify your OCR or Gemini API key in Settings.',
          errorType: response.statusCode == 401
              ? OcrErrorType.unauthorized
              : OcrErrorType.forbidden,
          httpStatusCode: response.statusCode,
        );
      }
      if (response.statusCode == 429) {
        return const ReceiptOcrResult.failure(
          'OCR service rate limit reached (HTTP 429). Please wait a moment before retrying, or configure your Gemini API key in Settings.',
          errorType: OcrErrorType.rateLimited,
          httpStatusCode: 429,
        );
      }
      if (response.statusCode >= 500) {
        return ReceiptOcrResult.failure(
          'OCR provider is experiencing temporary server errors (HTTP ${response.statusCode}). Please retry or enter manually.',
          errorType: OcrErrorType.serverError,
          httpStatusCode: response.statusCode,
        );
      }

      return ReceiptOcrResult.failure(
        'OCR service unavailable (HTTP ${response.statusCode})',
        errorType: OcrErrorType.serverError,
        httpStatusCode: response.statusCode,
      );
    } on TimeoutException {
      return const ReceiptOcrResult.failure(
        'OCR request timed out. Please check your internet connection and retry.',
        errorType: OcrErrorType.timeout,
      );
    } catch (e) {
      return ReceiptOcrResult.failure(
        'Unable to reach OCR service ($e). Please check your internet connection or enter expense manually.',
        errorType: OcrErrorType.networkError,
      );
    }
  }

  ReceiptOcrResult _parseOcrSpaceResponse(
    Map<String, dynamic> jsonResult,
    String fileName, {
    ReceiptQrPayload? qrPayload,
  }) {
    if (jsonResult['IsErroredOnProcessing'] == true ||
        jsonResult['error'] != null) {
      final errDetails = jsonResult['ErrorMessage']?.toString() ??
          jsonResult['error']?.toString() ??
          'OCR processing error';

      if (errDetails.toLowerCase().contains('limit reached') ||
          errDetails.contains('E557')) {
        return const ReceiptOcrResult.failure(
          'OCR engine free tier monthly request quota has been reached. Please configure your own Google Gemini API key or OCR key in Settings for unlimited scans.',
          errorType: OcrErrorType.rateLimited,
          httpStatusCode: 429,
        );
      }
      if (errDetails.toLowerCase().contains('file size') ||
          errDetails.contains('E413') ||
          errDetails.toLowerCase().contains('large')) {
        return const ReceiptOcrResult.failure(
          'Image payload too large for OCR engine (HTTP 413). Please crop the image closer to the receipt text.',
          errorType: OcrErrorType.payloadTooLarge,
          httpStatusCode: 413,
        );
      }
      return ReceiptOcrResult.failure(
        errDetails,
        errorType: OcrErrorType.serverError,
      );
    }

    final parsedResults = jsonResult['ParsedResults'] as List<dynamic>?;
    if (parsedResults != null && parsedResults.isNotEmpty) {
      final text = parsedResults[0]['ParsedText'] as String? ?? '';
      if (text.trim().length >= 4) {
        final receiptData = ReceiptParserService.parseReceiptText(
          text,
          fileName: fileName,
          qrPayload: qrPayload,
        );
        return ReceiptOcrResult.success(
          rawText: text,
          data: receiptData,
          qrPayload: qrPayload,
        );
      }
    }

    return const ReceiptOcrResult.failure(
      'No text could be extracted from this image. Please ensure the receipt is legible or enter details manually.',
      errorType: OcrErrorType.emptyResult,
    );
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
