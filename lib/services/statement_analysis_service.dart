import 'dart:convert';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../models/statement_analysis_models.dart';
import 'receipt_ocr_service.dart';
import 'transaction_categorization_service.dart';

abstract class StatementAnalysisService {
  Future<StatementAnalysisResult> analyzeStatement({
    required String fileName,
    required Uint8List bytes,
    required List<FinanceTransaction> existingTransactions,
  });
}

class UniversalStatementAnalyzer implements StatementAnalysisService {
  final ReceiptOcrService? ocrService;
  late final PdfStatementAnalyzer _pdfAnalyzer;
  late final SpreadsheetStatementAnalyzer _spreadsheetAnalyzer;
  late final CsvStatementAnalyzer _csvAnalyzer;
  late final ImageStatementAnalyzer _imageAnalyzer;

  UniversalStatementAnalyzer({this.ocrService}) {
    _pdfAnalyzer = PdfStatementAnalyzer(ocrService: ocrService);
    _spreadsheetAnalyzer = SpreadsheetStatementAnalyzer();
    _csvAnalyzer = CsvStatementAnalyzer();
    _imageAnalyzer = ImageStatementAnalyzer(ocrService: ocrService);
  }

  @override
  Future<StatementAnalysisResult> analyzeStatement({
    required String fileName,
    required Uint8List bytes,
    required List<FinanceTransaction> existingTransactions,
  }) async {
    final lowerName = fileName.toLowerCase();

    StatementAnalysisResult result;

    if (lowerName.endsWith('.pdf')) {
      result = await _pdfAnalyzer.analyze(fileName, bytes);
    } else if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
      result = await _spreadsheetAnalyzer.analyze(fileName, bytes);
    } else if (lowerName.endsWith('.csv')) {
      result = await _csvAnalyzer.analyze(fileName, bytes);
    } else if (lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp')) {
      result = await _imageAnalyzer.analyze(fileName, bytes);
    } else {
      // Default try CSV if unknown text-based, else PDF
      result = await _csvAnalyzer.analyze(fileName, bytes);
    }

    // Run duplicate detection against existing transactions
    _detectDuplicates(result.transactions, existingTransactions);

    return result;
  }

  void _detectDuplicates(
    List<ParsedStatementTransaction> candidates,
    List<FinanceTransaction> existing,
  ) {
    for (final candidate in candidates) {
      for (final ex in existing) {
        final dateDiff = (candidate.date.difference(ex.date).inDays).abs();
        final amountDiff = (candidate.amount - ex.amount).abs();

        if (dateDiff <= 1 && amountDiff < 0.01) {
          final candMerchant = candidate.merchant.toLowerCase();
          final exMerchant = ex.merchant.toLowerCase();
          final exTitle = ex.title.toLowerCase();

          if (candMerchant.contains(exMerchant) ||
              exMerchant.contains(candMerchant) ||
              candMerchant.contains(exTitle) ||
              candidate.description.toLowerCase().contains(exTitle)) {
            candidate.isDuplicate = true;
            candidate.duplicateReason =
                'Matches existing ${ex.merchant.isNotEmpty ? ex.merchant : ex.title} on ${DateFormat('dd MMM').format(ex.date)} (\u20B9${ex.amount.toStringAsFixed(0)})';
            candidate.selected =
                false; // Deselect duplicate by default for safety
            break;
          }
        }
      }
    }
  }
}

// ================================================================
// PDF STATEMENT ANALYZER (Syncfusion Pure Dart + OCR fallback)
// ================================================================
class PdfStatementAnalyzer {
  final ReceiptOcrService? ocrService;
  PdfStatementAnalyzer({this.ocrService});

  Future<StatementAnalysisResult> analyze(
    String fileName,
    Uint8List bytes,
  ) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String extractedText = extractor.extractText();
      final int pageCount = document.pages.count;
      document.dispose();

      // Check if scanned / image-based PDF
      final isScanned = extractedText.trim().length < 40 && pageCount > 0;

      if (isScanned) {
        if (ocrService != null) {
          try {
            final ocrResult = await ocrService!.processReceiptBytes(
              bytes: bytes,
              fileName: fileName,
            );
            if (ocrResult.isSuccess && ocrResult.rawText.trim().length >= 40) {
              return _parseFromText(
                fileName: fileName,
                rawText: ocrResult.rawText,
                source: 'PDF (OCR)',
                isScanned: true,
              );
            }
          } catch (e) {
            debugPrint('Scanned PDF OCR attempt failed: $e');
          }
        }
        return _buildScannedPdfFallback(fileName, pageCount);
      }

      return _parseFromText(
        fileName: fileName,
        rawText: extractedText,
        source: 'PDF',
        isScanned: false,
      );
    } catch (e) {
      return StatementAnalysisResult(
        fileName: fileName,
        format: StatementFormat.pdf,
        transactions: [],
        totalIncome: 0,
        totalExpense: 0,
        netCashFlow: 0,
        duplicateCount: 0,
        summaryInsight: 'Unable to parse PDF structure: $e',
        spendingBreakdown: {},
        parsingWarning:
            'Unable to read this PDF. Please ensure it is not password protected.',
      );
    }
  }

  StatementAnalysisResult _buildScannedPdfFallback(String fileName, int pages) {
    return StatementAnalysisResult(
      fileName: fileName,
      format: StatementFormat.pdf,
      transactions: [],
      totalIncome: 0,
      totalExpense: 0,
      netCashFlow: 0,
      duplicateCount: 0,
      summaryInsight:
          'Scanned statement detected ($pages pages). Text extraction produced insufficient characters. Please upload an original digital e-statement PDF directly from your bank app.',
      spendingBreakdown: {},
      isScannedPdfDetected: true,
      parsingWarning:
          'Scanned statement detected. For highest accuracy, download and upload the original digital e-statement directly from your bank netbanking or mobile app.',
    );
  }

  StatementAnalysisResult _parseFromText({
    required String fileName,
    required String rawText,
    required String source,
    required bool isScanned,
  }) {
    final lines = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');

    final transactions = <ParsedStatementTransaction>[];

    // Method 1: Assemble multi-line transaction blocks
    // In bank statements, each transaction row begins with a date.
    final dateStartPattern = RegExp(
      r'^\s*(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}[-\s/](?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[-\s/]\d{2,4}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{2,4})\b',
      caseSensitive: false,
    );

    final blocks = <List<String>>[];
    List<String>? currentBlock;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (dateStartPattern.hasMatch(line)) {
        if (currentBlock != null && currentBlock.isNotEmpty) {
          blocks.add(currentBlock);
        }
        currentBlock = [line];
      } else {
        if (currentBlock != null) {
          currentBlock.add(line);
        }
      }
    }
    if (currentBlock != null && currentBlock.isNotEmpty) {
      blocks.add(currentBlock);
    }

    for (final block in blocks) {
      final joinedLine = block.join(' ');
      final tx = _parseTextLine(joinedLine, source: source);
      if (tx != null) {
        transactions.add(tx);
      }
    }

    // Method 2: If block assembly caught 0 transactions, fallback to line-by-line scanning
    if (transactions.isEmpty) {
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        final tx = _parseTextLine(line, source: source);
        if (tx != null) {
          transactions.add(tx);
        }
      }
    }

    if (transactions.isEmpty) {
      return StatementAnalysisResult(
        fileName: fileName,
        format: StatementFormat.pdf,
        transactions: [],
        totalIncome: 0,
        totalExpense: 0,
        netCashFlow: 0,
        duplicateCount: 0,
        summaryInsight: 'No transactions found in this PDF.',
        spendingBreakdown: {},
        parsingWarning:
            'FinPilot AI extracted text from this document but could not find formatted transaction rows. Please ensure this is an official bank account statement.',
      );
    }

    return _buildResult(
      fileName: fileName,
      format: StatementFormat.pdf,
      transactions: transactions,
      isScanned: isScanned,
    );
  }

  ParsedStatementTransaction? _parseTextLine(
    String line, {
    required String source,
  }) {
    // Look for date anywhere in line: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, DD MMM YYYY, MMM DD, YYYY
    final dateMatch = RegExp(
      r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}[-\s/](?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[-\s/]\d{2,4}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(line);

    if (dateMatch == null) return null;

    final parsedDate = _parseFlexibleDate(dateMatch.group(0)!);
    if (parsedDate == null) return null;

    final lineWithoutDate = line.replaceFirst(dateMatch.group(0)!, ' ');

    // Look for currency / amounts: e.g. 1,500.00 or 1,23,250.00 or 520.50
    final amountMatches = RegExp(
      r'(?:INR|Rs\.?|₹)?\s*\b([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\b',
    ).allMatches(lineWithoutDate);

    if (amountMatches.isEmpty) return null;

    // Filter valid candidate financial amounts
    final validAmounts = <double>[];
    for (final match in amountMatches) {
      final str = match.group(1)?.replaceAll(',', '');
      if (str == null) continue;
      // Filter out long integers (phone numbers >= 10 digits, UTR/ref numbers >= 7 digits without decimal)
      if (!str.contains('.') && str.length >= 7) continue;
      final val = double.tryParse(str);
      if (val != null && val > 0 && val < 500000000) {
        validAmounts.add(val);
      }
    }

    if (validAmounts.isEmpty) return null;

    // In bank statements with multiple numbers on a row (e.g. [Withdrawal/Deposit] [Closing Balance]):
    // The closing balance is the LAST amount on the row.
    // The transaction amount is the FIRST valid financial amount!
    double amount = validAmounts.first;
    if (validAmounts.length >= 2) {
      // If the line has 0.00 as the first number (e.g. empty withdrawal column), take the next
      if (amount <= 0 && validAmounts.length > 2) {
        amount = validAmounts[1];
      }
    }

    if (amount <= 0) return null;

    // Clean narration / merchant
    final description = line
        .replaceAll(dateMatch.group(0)!, '')
        .replaceAll(RegExp(r'(?:INR|Rs\.?|₹)?\s*[0-9,]+\.[0-9]{2}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (description.length < 2) return null;

    final type = TransactionCategorizationService.detectType(line);
    final merchant = TransactionCategorizationService.extractMerchant(
      description,
    );
    final category = TransactionCategorizationService.detectCategory(
      '$merchant $description',
      type: type,
    );
    final paymentMethod = TransactionCategorizationService.detectPaymentMethod(
      line,
    );

    return ParsedStatementTransaction(
      id: const Uuid().v4(),
      date: parsedDate,
      merchant: merchant,
      description: description,
      amount: amount,
      type: type,
      category: category,
      paymentMethod: paymentMethod,
      source: source,
      confidence: const ConfidenceScores(
        merchant: 94,
        amount: 98,
        date: 96,
        category: 92,
      ),
    );
  }
}

// ================================================================
// EXCEL SPREADSHEET ANALYZER (excel_plus - Cross Platform)
// ================================================================
class SpreadsheetStatementAnalyzer {
  Future<StatementAnalysisResult> analyze(
    String fileName,
    Uint8List bytes,
  ) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      final transactions = <ParsedStatementTransaction>[];

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty) continue;

        int headerRowIndex = -1;
        int dateCol = -1;
        int descCol = -1;
        int debitCol = -1;
        int creditCol = -1;
        int amountCol = -1;
        int typeCol = -1;
        int balanceCol = -1;

        // Scan first 40 rows to find header row
        for (int r = 0; r < sheet.rows.length && r < 40; r++) {
          final row = sheet.rows[r];
          final rowTexts = row
              .map((cell) => _extractCellText(cell).toLowerCase())
              .toList();

          int foundDate = -1;
          int foundDesc = -1;
          int foundDebit = -1;
          int foundCredit = -1;
          int foundAmount = -1;
          int foundType = -1;
          int foundBalance = -1;

          for (int c = 0; c < rowTexts.length; c++) {
            final text = rowTexts[c];
            if (text.isEmpty) continue;

            if (text.contains('balance') || text.contains('bal')) {
              foundBalance = c;
              continue; // Do not treat balance column as transaction amount
            }

            if ((text.contains('date') ||
                    text.contains('txn dt') ||
                    text.contains('val dt') ||
                    text.contains('posting date')) &&
                foundDate == -1) {
              foundDate = c;
            }

            if ((text.contains('narration') ||
                    text.contains('desc') ||
                    text.contains('particular') ||
                    text.contains('details') ||
                    text.contains('remark') ||
                    text.contains('payee')) &&
                foundDesc == -1) {
              foundDesc = c;
            }

            if ((text.contains('debit') ||
                    text.contains('withdrawal') ||
                    text == 'dr' ||
                    text.contains('dr amt') ||
                    text.contains('spent')) &&
                foundDebit == -1) {
              foundDebit = c;
            }

            if ((text.contains('credit') ||
                    text.contains('deposit') ||
                    text == 'cr' ||
                    text.contains('cr amt') ||
                    text.contains('received')) &&
                foundCredit == -1) {
              foundCredit = c;
            }

            if ((text.contains('amount') || text == 'amt') &&
                foundAmount == -1) {
              foundAmount = c;
            }

            if ((text == 'type' ||
                    text.contains('dr/cr') ||
                    text.contains('cr/dr') ||
                    text.contains('mode')) &&
                foundType == -1) {
              foundType = c;
            }
          }

          if (foundDate != -1 &&
              (foundDesc != -1 ||
                  foundDebit != -1 ||
                  foundCredit != -1 ||
                  foundAmount != -1)) {
            headerRowIndex = r;
            dateCol = foundDate;
            descCol = foundDesc;
            debitCol = foundDebit;
            creditCol = foundCredit;
            amountCol = foundAmount;
            typeCol = foundType;
            balanceCol = foundBalance;
            break;
          }
        }

        // Fallback: If no explicit header row, detect columns from first 15 data rows
        if (headerRowIndex == -1 && sheet.rows.isNotEmpty) {
          final colDateCounts = <int, int>{};
          final colNumCounts = <int, int>{};
          final colTextCounts = <int, int>{};

          for (int r = 0; r < sheet.rows.length && r < 15; r++) {
            final row = sheet.rows[r];
            for (int c = 0; c < row.length; c++) {
              final cell = row[c];
              if (cell == null) continue;
              final d = _extractCellDate(cell);
              if (d != null) colDateCounts[c] = (colDateCounts[c] ?? 0) + 1;
              final a = _extractCellAmount(cell);
              if (a != null && a > 0) colNumCounts[c] = (colNumCounts[c] ?? 0) + 1;
              final t = _extractCellText(cell);
              if (t.length > 3 && d == null && a == null) {
                colTextCounts[c] = (colTextCounts[c] ?? 0) + 1;
              }
            }
          }

          if (colDateCounts.isNotEmpty) {
            dateCol = colDateCounts.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;
          }
          if (colTextCounts.isNotEmpty) {
            descCol = colTextCounts.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;
          }
          if (colNumCounts.isNotEmpty) {
            amountCol = colNumCounts.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;
          }
          headerRowIndex = -1; // Process from row 0
        }

        if (dateCol == -1) {
          dateCol = 0;
          if (descCol == -1) descCol = 1;
          if (amountCol == -1) amountCol = 2;
        }

        // Iterate data rows
        for (int r = headerRowIndex + 1; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          if (row.isEmpty) continue;

          // Date
          DateTime? date;
          if (dateCol != -1 && dateCol < row.length) {
            date = _extractCellDate(row[dateCol]);
          }
          if (date == null) continue;

          // Description / Narration
          String description = 'Bank Transaction';
          if (descCol != -1 && descCol < row.length) {
            final val = _extractCellText(row[descCol]);
            if (val.isNotEmpty) description = val;
          }

          // Amount and Debit/Credit
          double amount = 0.0;
          TransactionType type = TransactionType.expense;

          if (debitCol != -1 && debitCol < row.length) {
            final debitVal = _extractCellAmount(row[debitCol]);
            if (debitVal != null && debitVal > 0) {
              amount = debitVal;
              type = TransactionType.expense;
            }
          }

          if (creditCol != -1 && creditCol < row.length) {
            final creditVal = _extractCellAmount(row[creditCol]);
            if (creditVal != null && creditVal > 0) {
              amount = creditVal;
              type = TransactionType.income;
            }
          }

          if (amount <= 0 &&
              amountCol != -1 &&
              amountCol < row.length &&
              amountCol != balanceCol) {
            final amtVal = _extractCellAmount(row[amountCol]);
            if (amtVal != null && amtVal != 0) {
              amount = amtVal.abs();
              if (amtVal < 0) {
                type = TransactionType.expense;
              } else if (typeCol != -1 && typeCol < row.length) {
                final typeStr = _extractCellText(row[typeCol]).toLowerCase();
                if (typeStr.contains('cr') ||
                    typeStr.contains('credit') ||
                    typeStr.contains('deposit')) {
                  type = TransactionType.income;
                } else {
                  type = TransactionType.expense;
                }
              } else {
                type = TransactionCategorizationService.detectType(description);
              }
            }
          }

          if (amount <= 0 || amount > 1000000000) continue;

          final merchant = TransactionCategorizationService.extractMerchant(
            description,
          );
          final category = TransactionCategorizationService.detectCategory(
            '$merchant $description',
            type: type,
          );
          final paymentMethod =
              TransactionCategorizationService.detectPaymentMethod(description);

          transactions.add(
            ParsedStatementTransaction(
              id: const Uuid().v4(),
              date: date,
              merchant: merchant,
              description: description,
              amount: amount,
              type: type,
              category: category,
              paymentMethod: paymentMethod,
              source: 'Excel',
              confidence: const ConfidenceScores(
                merchant: 96,
                amount: 99,
                date: 98,
                category: 94,
              ),
            ),
          );
        }

        if (transactions.isNotEmpty) break;
      }

      if (transactions.isEmpty) {
        return StatementAnalysisResult(
          fileName: fileName,
          format: StatementFormat.excel,
          transactions: [],
          totalIncome: 0,
          totalExpense: 0,
          netCashFlow: 0,
          duplicateCount: 0,
          summaryInsight: 'No transactions found in this Excel sheet.',
          spendingBreakdown: {},
          parsingWarning:
              'Could not identify transaction rows. Please ensure your Excel sheet has columns for Date, Description, and Debit/Credit amounts.',
        );
      }

      return _buildResult(
        fileName: fileName,
        format: StatementFormat.excel,
        transactions: transactions,
      );
    } catch (e) {
      return StatementAnalysisResult(
        fileName: fileName,
        format: StatementFormat.excel,
        transactions: [],
        totalIncome: 0,
        totalExpense: 0,
        netCashFlow: 0,
        duplicateCount: 0,
        summaryInsight: 'Error reading Excel file: $e',
        spendingBreakdown: {},
        parsingWarning:
            'Unable to parse XLSX worksheet ($e). Please verify the file is not corrupted.',
      );
    }
  }

  static DateTime? _extractCellDate(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final val = cell.value;
    if (val is DateCellValue) {
      return val.asDateTimeLocal();
    }
    if (val is DateTimeCellValue) {
      return val.asDateTimeLocal();
    }
    if (val is IntCellValue) {
      final n = val.value;
      if (n >= 25000 && n <= 75000) {
        return DateTime(1899, 12, 30).add(Duration(days: n));
      }
    }
    if (val is DoubleCellValue) {
      final d = val.value;
      if (d >= 25000 && d <= 75000) {
        final ms = (d * 86400000).round();
        return DateTime(1899, 12, 30).add(Duration(milliseconds: ms));
      }
    }
    if (val is TextCellValue) {
      return _parseFlexibleDate(val.value.text);
    }
    return _parseFlexibleDate(val);
  }

  static double? _extractCellAmount(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final val = cell.value;
    if (val is DoubleCellValue) return val.value;
    if (val is IntCellValue) return val.value.toDouble();
    if (val is TextCellValue) return _parseAmount(val.value.text);
    return _parseAmount(val);
  }

  static String _extractCellText(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    if (val is TextCellValue) return val.value.text?.trim() ?? '';
    return val.toString().trim();
  }
}

// ================================================================
// CSV STATEMENT ANALYZER (Cross Platform)
// ================================================================
class CsvStatementAnalyzer {
  Future<StatementAnalysisResult> analyze(
    String fileName,
    Uint8List bytes,
  ) async {
    try {
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      final lines = content
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n');

      final rawRows = <List<String>>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        rawRows.add(_parseCsvLine(line));
      }

      if (rawRows.isEmpty) {
        return StatementAnalysisResult(
          fileName: fileName,
          format: StatementFormat.csv,
          transactions: [],
          totalIncome: 0,
          totalExpense: 0,
          netCashFlow: 0,
          duplicateCount: 0,
          summaryInsight: 'CSV file is empty',
          spendingBreakdown: {},
        );
      }

      int headerIndex = -1;
      int dateCol = -1;
      int descCol = -1;
      int debitCol = -1;
      int creditCol = -1;
      int amountCol = -1;
      int typeCol = -1;

      // Find header row
      for (int i = 0; i < rawRows.length && i < 25; i++) {
        final row = rawRows[i];
        for (int c = 0; c < row.length; c++) {
          final cell = row[c].toLowerCase().trim();
          if ((cell.contains('date') ||
                  cell.contains('txn date') ||
                  cell.contains('transaction date')) &&
              dateCol == -1) {
            dateCol = c;
          }
          if ((cell.contains('narration') ||
                  cell.contains('description') ||
                  cell.contains('details') ||
                  cell.contains('particular') ||
                  cell.contains('merchant')) &&
              descCol == -1) {
            descCol = c;
          }
          if ((cell.contains('debit') ||
                  cell.contains('withdrawal') ||
                  cell.contains('dr')) &&
              debitCol == -1) {
            debitCol = c;
          }
          if ((cell.contains('credit') ||
                  cell.contains('deposit') ||
                  cell.contains('cr')) &&
              creditCol == -1) {
            creditCol = c;
          }
          if (cell.contains('amount') && amountCol == -1) {
            amountCol = c;
          }
          if (cell.contains('type') && typeCol == -1) {
            typeCol = c;
          }
        }

        if (dateCol != -1 &&
            (descCol != -1 || amountCol != -1 || debitCol != -1)) {
          headerIndex = i;
          break;
        }
      }

      final transactions = <ParsedStatementTransaction>[];
      final startIndex = headerIndex != -1 ? headerIndex + 1 : 0;

      for (int i = startIndex; i < rawRows.length; i++) {
        final row = rawRows[i];
        if (row.isEmpty) continue;

        DateTime? date;
        if (dateCol != -1 && dateCol < row.length) {
          date = _parseFlexibleDate(row[dateCol]);
        } else {
          for (final cell in row) {
            final d = _parseFlexibleDate(cell);
            if (d != null) {
              date = d;
              break;
            }
          }
        }

        if (date == null) continue;

        String description = 'Bank Transaction';
        if (descCol != -1 && descCol < row.length) {
          description = row[descCol].trim();
        } else {
          for (int c = 0; c < row.length; c++) {
            if (c != dateCol &&
                _parseAmount(row[c]) == null &&
                row[c].trim().isNotEmpty) {
              description = row[c].trim();
              break;
            }
          }
        }

        double amount = 0.0;
        TransactionType type = TransactionType.expense;

        if (debitCol != -1 && debitCol < row.length) {
          final val = _parseAmount(row[debitCol]);
          if (val != null && val > 0) {
            amount = val;
            type = TransactionType.expense;
          }
        }

        if (creditCol != -1 && creditCol < row.length) {
          final val = _parseAmount(row[creditCol]);
          if (val != null && val > 0) {
            amount = val;
            type = TransactionType.income;
          }
        }

        if (amount <= 0 && amountCol != -1 && amountCol < row.length) {
          final val = _parseAmount(row[amountCol]);
          if (val != null && val > 0) {
            amount = val;
            type = TransactionCategorizationService.detectType(
              typeCol != -1 && typeCol < row.length
                  ? '${row[typeCol]} $description'
                  : description,
            );
          }
        }

        // Fallback amount search if columns didn't match
        if (amount <= 0) {
          for (final cell in row) {
            final val = _parseAmount(cell);
            if (val != null && val > 0 && val < 50000000) {
              amount = val;
              type = TransactionCategorizationService.detectType(row.join(' '));
              break;
            }
          }
        }

        if (amount <= 0) continue;

        final merchant = TransactionCategorizationService.extractMerchant(
          description,
        );
        final category = TransactionCategorizationService.detectCategory(
          '$merchant $description',
          type: type,
        );
        final paymentMethod =
            TransactionCategorizationService.detectPaymentMethod(description);

        transactions.add(
          ParsedStatementTransaction(
            id: const Uuid().v4(),
            date: date,
            merchant: merchant,
            description: description,
            amount: amount,
            type: type,
            category: category,
            paymentMethod: paymentMethod,
            source: 'CSV',
            confidence: const ConfidenceScores(
              merchant: 98,
              amount: 99,
              date: 99,
              category: 95,
            ),
          ),
        );
      }

      return _buildResult(
        fileName: fileName,
        format: StatementFormat.csv,
        transactions: transactions,
      );
    } catch (e) {
      return StatementAnalysisResult(
        fileName: fileName,
        format: StatementFormat.csv,
        transactions: [],
        totalIncome: 0,
        totalExpense: 0,
        netCashFlow: 0,
        duplicateCount: 0,
        summaryInsight: 'Error reading CSV: $e',
        spendingBreakdown: {},
        parsingWarning: 'Could not parse CSV statement.',
      );
    }
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (insideQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' && !insideQuotes) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString().trim());
    return values;
  }
}

// ================================================================
// IMAGE / SCREENSHOT STATEMENT ANALYZER (OCR Pipeline + Vision)
// ================================================================
class ImageStatementAnalyzer {
  final ReceiptOcrService? ocrService;
  ImageStatementAnalyzer({this.ocrService});

  Future<StatementAnalysisResult> analyze(
    String fileName,
    Uint8List bytes,
  ) async {
    final service = ocrService ?? ReceiptOcrService();
    final ocrResult = await service.processReceiptBytes(
      bytes: bytes,
      fileName: fileName,
    );

    if (!ocrResult.isSuccess && ocrResult.rawText.trim().isEmpty) {
      return StatementAnalysisResult(
        fileName: fileName,
        format: StatementFormat.image,
        transactions: [],
        totalIncome: 0,
        totalExpense: 0,
        netCashFlow: 0,
        duplicateCount: 0,
        summaryInsight:
            'FinPilot AI was unable to detect legible text in this image.',
        spendingBreakdown: {},
        parsingWarning: ocrResult.errorMessage ??
            'Could not extract text from this image. Please ensure the screenshot or receipt is clear and well-lit.',
      );
    }

    final transactions = <ParsedStatementTransaction>[];

    // Method A: Check if rawText contains multiple transaction rows (screenshot of transaction list)
    if (ocrResult.rawText.trim().isNotEmpty) {
      final pdfHelper = PdfStatementAnalyzer();
      final lines = ocrResult.rawText
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n');

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        final tx = pdfHelper._parseTextLine(line, source: 'Image OCR');
        if (tx != null) {
          transactions.add(tx);
        }
      }
    }

    // Method B: If no multi-line list was parsed, check if single receipt/payment data was recognized
    if (transactions.isEmpty && ocrResult.data != null) {
      final data = ocrResult.data!;
      if (data.total > 0) {
        final txDate = data.date;
        final merchant =
            data.merchant.isNotEmpty ? data.merchant : 'Receipt Merchant';
        final desc = data.lineItems.isNotEmpty
            ? data.lineItems.map((i) => i.name).join(', ')
            : '$merchant Payment';
        final type = TransactionCategorizationService.detectType(
          '$merchant $desc',
        );
        final category =
            data.category.isNotEmpty ? data.category : 'Shopping';
        final paymentMethod =
            data.paymentMethod.isNotEmpty ? data.paymentMethod : 'UPI';

        transactions.add(
          ParsedStatementTransaction(
            id: const Uuid().v4(),
            date: txDate,
            merchant: merchant,
            description: desc,
            amount: data.total,
            type: type,
            category: category,
            paymentMethod: paymentMethod,
            source: 'Image OCR',
            confidence: const ConfidenceScores(
              merchant: 96,
              amount: 98,
              date: 95,
              category: 94,
            ),
          ),
        );
      }
    }

    // Method C: QR fallback if QR contained payment data
    final qr = ocrResult.qrPayload;
    if (transactions.isEmpty && qr != null && qr.isFound) {
      final qrAmt = qr.upiAmount ?? qr.invoiceAmount;
      if (qrAmt != null && qrAmt > 0) {
        final merchant = qr.upiPayeeName ?? 'UPI Merchant';
        final type = TransactionType.expense;
        final cat = TransactionCategorizationService.detectCategory(
          merchant,
          type: type,
        );

        transactions.add(
          ParsedStatementTransaction(
            id: const Uuid().v4(),
            date: DateTime.now(),
            merchant: merchant,
            description: 'UPI QR Payment to $merchant',
            amount: qrAmt,
            type: type,
            category: cat,
            paymentMethod: 'UPI',
            source: 'Image QR',
            confidence: const ConfidenceScores(
              merchant: 99,
              amount: 100,
              date: 95,
              category: 95,
            ),
          ),
        );
      }
    }

    if (transactions.isEmpty) {
      return StatementAnalysisResult(
        fileName: fileName,
        format: StatementFormat.image,
        transactions: [],
        totalIncome: 0,
        totalExpense: 0,
        netCashFlow: 0,
        duplicateCount: 0,
        summaryInsight: 'No transactions detected in this image.',
        spendingBreakdown: {},
        parsingWarning:
            'Text was extracted (${ocrResult.rawText.length} characters) but no transaction amounts or merchants could be recognized. Please upload a full bank statement or clear payment screenshot.',
      );
    }

    return _buildResult(
      fileName: fileName,
      format: StatementFormat.image,
      transactions: transactions,
    );
  }
}

// ================================================================
// SHARED UTILITIES & INSIGHT GENERATOR
// ================================================================
StatementAnalysisResult _buildResult({
  required String fileName,
  required StatementFormat format,
  required List<ParsedStatementTransaction> transactions,
  bool isScanned = false,
  String? parsingWarning,
}) {
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  final Map<String, double> spendingBreakdown = {};

  for (final t in transactions) {
    if (t.type == TransactionType.income) {
      totalIncome += t.amount;
    } else {
      totalExpense += t.amount;
      spendingBreakdown[t.category] =
          (spendingBreakdown[t.category] ?? 0.0) + t.amount;
    }
  }

  final netCashFlow = totalIncome - totalExpense;

  // Find top spending category
  String topCat = 'None';
  double topCatAmount = 0.0;
  spendingBreakdown.forEach((cat, amt) {
    if (amt > topCatAmount) {
      topCatAmount = amt;
      topCat = cat;
    }
  });

  // Food delivery spend
  final foodSpend = spendingBreakdown['Food & Dining'] ?? 0.0;

  // Build AI Summary Insight
  final insightsBuffer = StringBuffer();
  if (netCashFlow >= 0) {
    insightsBuffer.write(
      'Your cash flow is positive by \u20B9${netCashFlow.toStringAsFixed(0)}. ',
    );
  } else {
    insightsBuffer.write(
      'Your expenses exceeded income by \u20B9${(-netCashFlow).toStringAsFixed(0)} in this statement. ',
    );
  }

  if (topCat != 'None') {
    insightsBuffer.write(
      '$topCat was your highest spending category (\u20B9${topCatAmount.toStringAsFixed(0)}). ',
    );
  }

  if (foodSpend > 0) {
    insightsBuffer.write(
      'You spent \u20B9${foodSpend.toStringAsFixed(0)} on dining and food delivery. ',
    );
  }

  return StatementAnalysisResult(
    fileName: fileName,
    format: format,
    transactions: transactions,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    netCashFlow: netCashFlow,
    duplicateCount: 0,
    summaryInsight: insightsBuffer.toString().trim(),
    spendingBreakdown: spendingBreakdown,
    isScannedPdfDetected: isScanned,
    parsingWarning: parsingWarning,
  );
}

DateTime? _parseFlexibleDate(dynamic rawValue) {
  if (rawValue == null) return null;
  if (rawValue is DateTime) return rawValue;

  if (rawValue is DateCellValue) {
    return rawValue.asDateTimeLocal();
  }
  if (rawValue is DateTimeCellValue) {
    return rawValue.asDateTimeLocal();
  }
  if (rawValue is num) {
    if (rawValue >= 25000 && rawValue <= 75000) {
      final ms = (rawValue.toDouble() * 86400000).round();
      return DateTime(1899, 12, 30).add(Duration(milliseconds: ms));
    }
  }

  var text = rawValue.toString().trim();
  if (text.isEmpty) return null;

  // Try numeric Excel serial in string form
  final numVal = double.tryParse(text);
  if (numVal != null && numVal >= 25000 && numVal <= 75000) {
    final ms = (numVal * 86400000).round();
    return DateTime(1899, 12, 30).add(Duration(milliseconds: ms));
  }

  // Try direct ISO8601 parsing e.g. "2026-10-15T00:00:00.000Z"
  final iso = DateTime.tryParse(text);
  if (iso != null && iso.year >= 1990 && iso.year <= 2050) {
    return DateTime(iso.year, iso.month, iso.day);
  }

  // Strip trailing time e.g. "15/10/2026 14:30:00" -> "15/10/2026"
  text = text
      .replaceAll(
        RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?(?:\.\d+)?(?:\s*(?:AM|PM|am|pm))?\b'),
        '',
      )
      .trim();

  // Pattern 1: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY (or 2 digit year)
  final m1 = RegExp(
    r'\b(\d{1,2})[/\.-](\d{1,2})[/\.-](\d{2,4})\b',
  ).firstMatch(text);
  if (m1 != null) {
    final day = int.tryParse(m1.group(1)!) ?? 0;
    final month = int.tryParse(m1.group(2)!) ?? 0;
    var year = int.tryParse(m1.group(3)!) ?? 0;
    if (year < 100) year += (year >= 70 ? 1900 : 2000);
    if (day.inRange(1, 31) &&
        month.inRange(1, 12) &&
        year.inRange(1990, 2050)) {
      return DateTime(year, month, day);
    }
  }

  // Pattern 2: YYYY-MM-DD or YYYY/MM/DD
  final m2 = RegExp(
    r'\b(\d{4})[/\.-](\d{1,2})[/\.-](\d{1,2})\b',
  ).firstMatch(text);
  if (m2 != null) {
    final year = int.tryParse(m2.group(1)!) ?? 0;
    final month = int.tryParse(m2.group(2)!) ?? 0;
    final day = int.tryParse(m2.group(3)!) ?? 0;
    if (day.inRange(1, 31) &&
        month.inRange(1, 12) &&
        year.inRange(1990, 2050)) {
      return DateTime(year, month, day);
    }
  }

  // Pattern 3: Textual month - DD MMM YYYY (e.g. 15 Oct 2026, 15-Oct-2026, 15 October 2026)
  final m3 = RegExp(
    r'\b(\d{1,2})[-\s/]([A-Za-z]{3,9})[-\s/](\d{2,4})\b',
  ).firstMatch(text);
  if (m3 != null) {
    final day = int.tryParse(m3.group(1)!) ?? 0;
    final monthStr = m3.group(2)!.toLowerCase();
    var year = int.tryParse(m3.group(3)!) ?? 0;
    if (year < 100) year += (year >= 70 ? 1900 : 2000);
    final month = _monthNameToNum(monthStr);
    if (month != null &&
        day.inRange(1, 31) &&
        year.inRange(1990, 2050)) {
      return DateTime(year, month, day);
    }
  }

  // Pattern 4: Textual month - MMM DD, YYYY (e.g. Oct 15, 2026 or October 15, 2026)
  final m4 = RegExp(
    r'\b([A-Za-z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{2,4})\b',
  ).firstMatch(text);
  if (m4 != null) {
    final monthStr = m4.group(1)!.toLowerCase();
    final day = int.tryParse(m4.group(2)!) ?? 0;
    var year = int.tryParse(m4.group(3)!) ?? 0;
    if (year < 100) year += (year >= 70 ? 1900 : 2000);
    final month = _monthNameToNum(monthStr);
    if (month != null &&
        day.inRange(1, 31) &&
        year.inRange(1990, 2050)) {
      return DateTime(year, month, day);
    }
  }

  return null;
}

int? _monthNameToNum(String str) {
  if (str.length < 3) return null;
  final sub = str.substring(0, 3).toLowerCase();
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  return months[sub];
}

double? _parseAmount(dynamic rawValue) {
  if (rawValue == null) return null;
  if (rawValue is DoubleCellValue) return rawValue.value;
  if (rawValue is IntCellValue) return rawValue.value.toDouble();
  if (rawValue is num) return rawValue.toDouble();

  var text = rawValue.toString().trim();
  if (text.isEmpty) return null;

  // Detect negative format e.g. (1,500.00) or -1500.00
  final isAccountingNegative =
      (text.startsWith('(') && text.endsWith(')')) || text.startsWith('-');

  text = text
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll('₹', '')
      .replaceAll('Rs.', '')
      .replaceAll('Rs', '')
      .replaceAll('INR', '')
      .replaceAll(',', '')
      .replaceAll('+', '')
      .replaceAll('-', '')
      .trim();

  // Strip Dr / Cr suffix or prefix
  text = text
      .replaceAll(RegExp(r'\s*(?:Dr|Cr|dr|cr)$'), '')
      .replaceAll(RegExp(r'^(?:Dr|Cr|dr|cr)\s*'), '')
      .trim();

  final parsed = double.tryParse(text);
  if (parsed == null) return null;
  return isAccountingNegative ? -parsed : parsed;
}

extension IntRange on int {
  bool inRange(int min, int max) => this >= min && this <= max;
}
