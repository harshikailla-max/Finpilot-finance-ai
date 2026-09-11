import 'dart:convert';
import 'finance_transaction.dart';

enum StatementFormat { pdf, image, excel, csv }

class ConfidenceScores {
  final int merchant;
  final int amount;
  final int date;
  final int category;

  const ConfidenceScores({
    this.merchant = 95,
    this.amount = 98,
    this.date = 96,
    this.category = 92,
  });

  bool get hasLowConfidence =>
      merchant < 80 || amount < 80 || date < 80 || category < 80;

  Map<String, dynamic> toJson() => {
        'merchant': merchant,
        'amount': amount,
        'date': date,
        'category': category,
      };

  factory ConfidenceScores.fromJson(Map<String, dynamic> json) =>
      ConfidenceScores(
        merchant: json['merchant'] as int? ?? 90,
        amount: json['amount'] as int? ?? 90,
        date: json['date'] as int? ?? 90,
        category: json['category'] as int? ?? 90,
      );
}

class ParsedStatementTransaction {
  final String id;
  DateTime date;
  String merchant;
  String description;
  double amount;
  TransactionType type;
  String category;
  String paymentMethod;
  String referenceId;
  ConfidenceScores confidence;
  bool isDuplicate;
  String duplicateReason;
  bool selected;
  String notes;
  String source;

  ParsedStatementTransaction({
    required this.id,
    required this.date,
    required this.merchant,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    this.paymentMethod = 'Bank Transfer',
    this.referenceId = '',
    this.confidence = const ConfidenceScores(),
    this.isDuplicate = false,
    this.duplicateReason = '',
    this.selected = true,
    this.notes = '',
    this.source = 'Bank Statement',
  });

  FinanceTransaction toFinanceTransaction() {
    return FinanceTransaction(
      id: id,
      title: merchant.isNotEmpty ? merchant : description,
      amount: amount,
      category: category,
      type: type,
      date: date,
      paymentMethod: paymentMethod,
      merchant: merchant,
      note: notes.isNotEmpty ? notes : (referenceId.isNotEmpty ? 'Ref: $referenceId' : description),
      source: source,
      createdAt: DateTime.now(),
    );
  }
}

class StatementAnalysisResult {
  final String fileName;
  final StatementFormat format;
  final List<ParsedStatementTransaction> transactions;
  final double totalIncome;
  final double totalExpense;
  final double netCashFlow;
  final int duplicateCount;
  final String summaryInsight;
  final Map<String, double> spendingBreakdown;
  final bool isScannedPdfDetected;
  final String? parsingWarning;

  StatementAnalysisResult({
    required this.fileName,
    required this.format,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
    required this.duplicateCount,
    required this.summaryInsight,
    required this.spendingBreakdown,
    this.isScannedPdfDetected = false,
    this.parsingWarning,
  });

  int get totalCount => transactions.length;
}

class ImportHistoryItem {
  final String id;
  final String fileName;
  final DateTime importedAt;
  final int transactionCount;
  final double totalIncome;
  final double totalExpense;
  final String format;

  ImportHistoryItem({
    required this.id,
    required this.fileName,
    required this.importedAt,
    required this.transactionCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.format,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'importedAt': importedAt.toIso8601String(),
        'transactionCount': transactionCount,
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'format': format,
      };

  factory ImportHistoryItem.fromJson(Map<String, dynamic> json) =>
      ImportHistoryItem(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        importedAt: DateTime.parse(json['importedAt'] as String),
        transactionCount: json['transactionCount'] as int,
        totalIncome: (json['totalIncome'] as num).toDouble(),
        totalExpense: (json['totalExpense'] as num).toDouble(),
        format: json['format'] as String? ?? 'CSV',
      );

  static String encodeList(List<ImportHistoryItem> items) =>
      jsonEncode(items.map((i) => i.toJson()).toList());

  static List<ImportHistoryItem> decodeList(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((i) => ImportHistoryItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
