class TesseractResult {
  final bool isSuccess;
  final String text;
  final double confidence;
  final String? errorMessage;

  const TesseractResult({
    required this.isSuccess,
    required this.text,
    this.confidence = 0.0,
    this.errorMessage,
  });

  const TesseractResult.failure(String message)
      : isSuccess = false,
        text = '',
        confidence = 0.0,
        errorMessage = message;
}
