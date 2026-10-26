import 'dart:typed_data';
import 'tesseract_ocr_models.dart';

class TesseractOcrService {
  static bool get isSupported => false;

  static Future<TesseractResult> recognize({
    required Uint8List bytes,
    void Function(String status, double progress)? onProgress,
  }) async {
    return const TesseractResult.failure('Tesseract.js is only available in browser environments.');
  }
}
