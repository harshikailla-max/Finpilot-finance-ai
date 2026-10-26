import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'tesseract_ocr_models.dart';

@JS('finpilotOcr')
external JSObject? get _finpilotOcr;

@JS('finpilotOcr.recognize')
external JSPromise<JSObject> _recognizeJs(JSString base64, JSFunction progress);

class TesseractOcrService {
  static bool get isSupported {
    return _finpilotOcr != null;
  }

  static Future<TesseractResult> recognize({
    required Uint8List bytes,
    void Function(String status, double progress)? onProgress,
  }) async {
    try {
      final base64Uri = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      void onProg(JSAny status, JSAny progress) {
        if (onProgress != null) {
          final s = status.dartify()?.toString() ?? 'processing';
          final pNum = progress.dartify();
          final p = (pNum is num) ? pNum.toDouble() : 0.0;
          onProgress(s, p);
        }
      }

      final promise = _recognizeJs(base64Uri.toJS, onProg.toJS);
      final jsObj = await promise.toDart;
      final dartMap = jsObj.dartify() as Map<Object?, Object?>?;

      if (dartMap == null) {
        return const TesseractResult.failure('Null response from browser OCR');
      }

      final isSuccess = dartMap['isSuccess'] == true;
      final text = dartMap['text']?.toString() ?? '';
      final confNum = dartMap['confidence'];
      final confidence = (confNum is num) ? confNum.toDouble() : 0.0;
      final errMsg = dartMap['errorMessage']?.toString();

      return TesseractResult(
        isSuccess: isSuccess,
        text: text,
        confidence: confidence,
        errorMessage: errMsg,
      );
    } catch (e) {
      return TesseractResult.failure('Browser OCR error: $e');
    }
  }
}
