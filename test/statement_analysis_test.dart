import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:finpilot_ai/models/finance_transaction.dart';
import 'package:finpilot_ai/models/statement_analysis_models.dart';
import 'package:finpilot_ai/services/statement_analysis_service.dart';

void main() {
  group('Statement Analysis - Date & Amount Parsers', () {
    final analyzer = UniversalStatementAnalyzer();

    test('Date & amount parsers parse various formats via CSV analyzer', () async {
      const csvData = '''Date,Narration,Withdrawal,Deposit,Balance
15/10/2026,Swiggy Bangalore,480.00,,45210.50
16-10-2026,Salary Credit Corp,,85000.00,130210.50
17 Oct 2026,Netflix Mumbai,649.00,,129561.50
2026-10-18,Zepto Quick Grocery,320.00,,129241.50
19/10/2026 14:30:00,Uber India Ride,290.00,,128951.50
''';

      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final result = await analyzer.analyzeStatement(
        fileName: 'bank_statement.csv',
        bytes: bytes,
        existingTransactions: [],
      );

      expect(result.transactions.length, equals(5));

      // Swiggy expense
      expect(result.transactions[0].merchant, contains('Swiggy'));
      expect(result.transactions[0].amount, equals(480.0));
      expect(result.transactions[0].type, equals(TransactionType.expense));
      expect(result.transactions[0].date.year, equals(2026));
      expect(result.transactions[0].date.month, equals(10));
      expect(result.transactions[0].date.day, equals(15));

      // Salary income
      expect(result.transactions[1].amount, equals(85000.0));
      expect(result.transactions[1].type, equals(TransactionType.income));

      // Netflix expense with textual month
      expect(result.transactions[2].merchant, contains('Netflix'));
      expect(result.transactions[2].amount, equals(649.0));
      expect(result.transactions[2].date.day, equals(17));

      // Zepto expense
      expect(result.transactions[3].amount, equals(320.0));
      expect(result.transactions[3].date.day, equals(18));

      // Uber expense with timestamp
      expect(result.transactions[4].merchant, contains('Uber'));
      expect(result.transactions[4].amount, equals(290.0));
      expect(result.transactions[4].date.day, equals(19));
    });
  });

  group('Statement Analysis - Excel (.xlsx) Parser', () {
    test('SpreadsheetStatementAnalyzer parses Excel sheets with DateCellValue & numbers', () async {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Header row
      sheet.appendRow([
        TextCellValue('Txn Date'),
        TextCellValue('Narration'),
        TextCellValue('Debit'),
        TextCellValue('Credit'),
        TextCellValue('Closing Balance'),
      ]);

      // Row 1: Swiggy order
      sheet.appendRow([
        DateCellValue(year: 2026, month: 10, day: 12),
        TextCellValue('UPI/3241285/Swiggy Order Bangalore'),
        DoubleCellValue(540.0),
        null,
        DoubleCellValue(42150.0),
      ]);

      // Row 2: Salary credit
      sheet.appendRow([
        DateCellValue(year: 2026, month: 10, day: 14),
        TextCellValue('ACH/Salary Credit/Acme Corp'),
        null,
        DoubleCellValue(92000.0),
        DoubleCellValue(134150.0),
      ]);

      // Row 3: Amazon purchase with TextCellValue date
      sheet.appendRow([
        TextCellValue('15/10/2026'),
        TextCellValue('Amazon India Retail Mumbai'),
        DoubleCellValue(1850.0),
        null,
        DoubleCellValue(132300.0),
      ]);

      final encoded = excel.encode();
      expect(encoded, isNotNull);
      final bytes = Uint8List.fromList(encoded!);

      final analyzer = SpreadsheetStatementAnalyzer();
      final result = await analyzer.analyze('hdfc_statement.xlsx', bytes);

      expect(result.transactions.length, equals(3));
      expect(result.transactions[0].merchant, contains('Swiggy'));
      expect(result.transactions[0].amount, equals(540.0));
      expect(result.transactions[0].type, equals(TransactionType.expense));
      expect(result.transactions[0].date.year, equals(2026));
      expect(result.transactions[0].date.month, equals(10));
      expect(result.transactions[0].date.day, equals(12));

      expect(result.transactions[1].amount, equals(92000.0));
      expect(result.transactions[1].type, equals(TransactionType.income));

      expect(result.transactions[2].merchant, contains('Amazon'));
      expect(result.transactions[2].amount, equals(1850.0));
      expect(result.transactions[2].type, equals(TransactionType.expense));
    });

    test('SpreadsheetStatementAnalyzer handles multi-row account header offset', () async {
      final excel = Excel.createExcel();
      final sheet = excel['AccountStatement'];

      // Simulate 5 rows of bank info / metadata before table
      sheet.appendRow([TextCellValue('HDFC BANK LIMITED')]);
      sheet.appendRow([TextCellValue('Account No: 50100234567890')]);
      sheet.appendRow([TextCellValue('Customer Name: Harshita K')]);
      sheet.appendRow([TextCellValue('IFSC Code: HDFC0001234')]);
      sheet.appendRow([TextCellValue('')]);

      // Actual Table Header at Row 5
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Transaction Details'),
        TextCellValue('Withdrawal Amt'),
        TextCellValue('Deposit Amt'),
        TextCellValue('Balance'),
      ]);

      // Data Rows
      sheet.appendRow([
        TextCellValue('05/10/2026'),
        TextCellValue('UPI-UBER-TRIP-7429'),
        DoubleCellValue(380.0),
        null,
        DoubleCellValue(25400.0),
      ]);

      final encoded = excel.encode()!;
      final analyzer = SpreadsheetStatementAnalyzer();
      final result = await analyzer.analyze(
        'account_statement.xlsx',
        Uint8List.fromList(encoded),
      );

      expect(result.transactions.length, equals(1));
      expect(result.transactions.first.merchant, contains('Uber'));
      expect(result.transactions.first.amount, equals(380.0));
    });
  });

  group('Statement Analysis - PDF Parser', () {
    test('PdfStatementAnalyzer extracts transactions and picks transaction amount over balance', () async {
      // Build a genuine PDF using Syncfusion PdfDocument
      final document = PdfDocument();
      final page = document.pages.add();

      final text = StringBuffer()
        ..writeln('STATE BANK OF INDIA - ACCOUNT STATEMENT')
        ..writeln('Date Narration Withdrawal Deposit Balance')
        ..writeln('10/10/2026 UPI/Swiggy/0987654321 450.00 48,250.00')
        ..writeln('12/10/2026 SALARY CREDIT 75,000.00 1,23,250.00')
        ..writeln('15 Oct 2026 NETFLIX ENTERTAINMENT 649.00 1,22,601.00');

      final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
      page.graphics.drawString(text.toString(), font);

      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      final analyzer = PdfStatementAnalyzer();
      final result = await analyzer.analyze('sbi_statement.pdf', bytes);

      expect(result.transactions.isNotEmpty, isTrue);
      expect(result.transactions.length, equals(3));

      // Transaction 1: Swiggy expense 450.00, NOT the balance 48250.00!
      expect(result.transactions[0].merchant, contains('Swiggy'));
      expect(result.transactions[0].amount, equals(450.0));
      expect(result.transactions[0].type, equals(TransactionType.expense));

      // Transaction 2: Salary credit 75000.00
      expect(result.transactions[1].amount, equals(75000.0));

      // Transaction 3: Netflix 649.00 (with textual month)
      expect(result.transactions[2].merchant, contains('Netflix'));
      expect(result.transactions[2].amount, equals(649.0));
    });

    test('PdfStatementAnalyzer buffers multi-line transaction rows', () async {
      final document = PdfDocument();
      final page = document.pages.add();

      final text = StringBuffer()
        ..writeln('HDFC BANK - ACCOUNT STATEMENT')
        ..writeln('01/10/2026')
        ..writeln('UPI-3241285-SWIGGY BANGALORE')
        ..writeln('REF: 000098765432 520.00 45,000.00')
        ..writeln('04/10/2026')
        ..writeln('UBER TRIP MUMBAI')
        ..writeln('AUTO DEBIT 340.00 44,660.00');

      final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
      page.graphics.drawString(text.toString(), font);

      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      final analyzer = PdfStatementAnalyzer();
      final result = await analyzer.analyze('hdfc_multiline.pdf', bytes);

      expect(result.transactions.length, equals(2));
      expect(result.transactions[0].merchant, contains('Swiggy'));
      expect(result.transactions[0].amount, equals(520.0));
      expect(result.transactions[1].merchant, contains('Uber'));
      expect(result.transactions[1].amount, equals(340.0));
    });
  });

  group('Statement Analysis - Image Parser & Universal Routing', () {
    test('UniversalStatementAnalyzer routes images to ImageStatementAnalyzer', () async {
      final analyzer = UniversalStatementAnalyzer();
      // Dummy small 1x1 png bytes
      final dummyPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
      ]);

      final result = await analyzer.analyzeStatement(
        fileName: 'screenshot.png',
        bytes: dummyPngBytes,
        existingTransactions: [],
      );

      expect(result.format, equals(StatementFormat.image));
    });
  });
}
