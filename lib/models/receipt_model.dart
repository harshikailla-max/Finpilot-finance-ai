import '../services/receipt_qr_service.dart';

class ReceiptLineItem {
  final String name;
  final double price;
  final int quantity;

  const ReceiptLineItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) =>
      ReceiptLineItem(
        name: json['name'] as String? ?? 'Item',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  ReceiptLineItem copyWith({String? name, double? price, int? quantity}) {
    return ReceiptLineItem(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }
}

class ReceiptData {
  final String merchant;
  final DateTime date;
  final double total;
  final double? tax;
  final double? subtotal;
  final String category;
  final String paymentMethod;
  final String currency;
  final List<ReceiptLineItem> lineItems;
  final String rawText;
  final double confidence;
  final bool isTotalUncertain;
  final bool isDateDetected;
  final String? invoiceNumber;
  final String? gstin;
  final ReceiptQrPayload? qrPayload;

  const ReceiptData({
    required this.merchant,
    required this.date,
    required this.total,
    this.tax,
    this.subtotal,
    required this.category,
    required this.paymentMethod,
    this.currency = 'INR',
    this.lineItems = const [],
    this.rawText = '',
    this.confidence = 0.85,
    this.isTotalUncertain = false,
    this.isDateDetected = true,
    this.invoiceNumber,
    this.gstin,
    this.qrPayload,
  });

  ReceiptData copyWith({
    String? merchant,
    DateTime? date,
    double? total,
    double? tax,
    double? subtotal,
    String? category,
    String? paymentMethod,
    String? currency,
    List<ReceiptLineItem>? lineItems,
    String? rawText,
    double? confidence,
    bool? isTotalUncertain,
    bool? isDateDetected,
    String? invoiceNumber,
    String? gstin,
    ReceiptQrPayload? qrPayload,
  }) {
    return ReceiptData(
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      total: total ?? this.total,
      tax: tax ?? this.tax,
      subtotal: subtotal ?? this.subtotal,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      currency: currency ?? this.currency,
      lineItems: lineItems ?? this.lineItems,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
      isTotalUncertain: isTotalUncertain ?? this.isTotalUncertain,
      isDateDetected: isDateDetected ?? this.isDateDetected,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      gstin: gstin ?? this.gstin,
      qrPayload: qrPayload ?? this.qrPayload,
    );
  }

  Map<String, dynamic> toJson() => {
        'merchant': merchant,
        'date': date.toIso8601String(),
        'total': total,
        'tax': tax,
        'subtotal': subtotal,
        'category': category,
        'paymentMethod': paymentMethod,
        'currency': currency,
        'lineItems': lineItems.map((e) => e.toJson()).toList(),
        'rawText': rawText,
        'confidence': confidence,
        'isTotalUncertain': isTotalUncertain,
        'invoiceNumber': invoiceNumber,
        'gstin': gstin,
        'qrPayload': qrPayload?.toJson(),
      };

  factory ReceiptData.fromJson(Map<String, dynamic> json) => ReceiptData(
        merchant: json['merchant'] as String? ?? '',
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : DateTime.now(),
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        tax: (json['tax'] as num?)?.toDouble(),
        subtotal: (json['subtotal'] as num?)?.toDouble(),
        category: json['category'] as String? ?? 'Food & Dining',
        paymentMethod: json['paymentMethod'] as String? ?? 'UPI',
        currency: json['currency'] as String? ?? 'INR',
        lineItems: (json['lineItems'] as List<dynamic>?)
                ?.map((e) =>
                    ReceiptLineItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        rawText: json['rawText'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
        isTotalUncertain: json['isTotalUncertain'] as bool? ?? false,
        invoiceNumber: json['invoiceNumber'] as String?,
        gstin: json['gstin'] as String?,
      );
}

enum ReceiptScanStatus {
  idle,
  loadingImage,
  decodingQr,
  recognizingText,
  parsingFields,
  success,
  emptyOrError,
}

enum OcrErrorType {
  none,
  payloadTooLarge, // HTTP 413
  unauthorized, // HTTP 401
  forbidden, // HTTP 403
  rateLimited, // HTTP 429 or quota exceeded
  serverError, // HTTP 500, 502, 503
  timeout,
  networkError,
  emptyResult,
  unreadable,
}

class ReceiptOcrResult {
  final bool isSuccess;
  final String rawText;
  final ReceiptData? data;
  final String? errorMessage;
  final ReceiptQrPayload? qrPayload;
  final OcrErrorType errorType;
  final int? httpStatusCode;

  const ReceiptOcrResult({
    required this.isSuccess,
    this.rawText = '',
    this.data,
    this.errorMessage,
    this.qrPayload,
    this.errorType = OcrErrorType.none,
    this.httpStatusCode,
  });

  const ReceiptOcrResult.failure(
    String message, {
    OcrErrorType errorType = OcrErrorType.unreadable,
    int? httpStatusCode,
    ReceiptQrPayload? qrPayload,
  }) : this(
          isSuccess: false,
          errorMessage: message,
          errorType: errorType,
          httpStatusCode: httpStatusCode,
          qrPayload: qrPayload,
        );

  const ReceiptOcrResult.success({
    required String rawText,
    required ReceiptData data,
    ReceiptQrPayload? qrPayload,
  }) : this(
          isSuccess: true,
          rawText: rawText,
          data: data,
          qrPayload: qrPayload,
          errorType: OcrErrorType.none,
        );
}
