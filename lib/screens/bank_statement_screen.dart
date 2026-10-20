import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../models/statement_analysis_models.dart';
import '../providers/finance_provider.dart';
import '../services/receipt_ocr_service.dart';
import '../services/statement_analysis_service.dart';
import '../services/storage_service.dart';
import '../services/transaction_categorization_service.dart';
import '../utils/currency_formatter.dart';

class BankStatementScreen extends StatefulWidget {
  const BankStatementScreen({super.key});

  @override
  State<BankStatementScreen> createState() => _BankStatementScreenState();
}

class _BankStatementScreenState extends State<BankStatementScreen> {
  // Theme palette matching FinPilot AI luxury fintech aesthetic
  static const Color bgDark = Color(0xFF081120);
  static const Color cardDark = Color(0xFF10192B);
  static const Color cardLight = Color(0xFF152238);
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color cyanAccent = Color(0xFF4CC9F0);
  static const Color successGreen = Color(0xFF2DD4A8);
  static const Color warningOrange = Color(0xFFFFB86B);
  static const Color dangerRed = Color(0xFFFF6B81);
  static const Color textMuted = Color(0xFF9AA4B2);

  late final UniversalStatementAnalyzer _analyzer;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  String _loadingMessage = 'Reading Statement...';
  StatementAnalysisResult? _currentResult;
  bool _importSuccessful = false;
  int _lastImportedCount = 0;

  List<ImportHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    _analyzer = UniversalStatementAnalyzer(
      ocrService: ReceiptOcrService(storageService: storage),
    );
    _loadImportHistory();
  }

  void _loadImportHistory() {
    try {
      final storage = Provider.of<StorageService>(context, listen: false);
      final raw = storage.getString('statement_import_history');
      if (raw != null) {
        setState(() {
          _history = ImportHistoryItem.decodeList(raw);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveImportHistory(ImportHistoryItem item) async {
    try {
      final storage = Provider.of<StorageService>(context, listen: false);
      _history.insert(0, item);
      await storage.setString(
        'statement_import_history',
        ImportHistoryItem.encodeList(_history),
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // Pick file across platforms
  Future<void> _pickStatementFile({List<String>? allowedExtensions}) async {
    try {
      // 1. If user clicked IMAGE, use ImagePicker for optimal Web/Mobile gallery experience
      final isImageOnly = allowedExtensions != null &&
          allowedExtensions.isNotEmpty &&
          allowedExtensions.every((ext) =>
              ['png', 'jpg', 'jpeg', 'webp'].contains(ext.toLowerCase()));

      if (isImageOnly) {
        final picked = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 95,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (bytes.isEmpty) {
          _showSnackbar('Could not read image data. Please try another image.');
          return;
        }
        await _processFileBytes(picked.name, bytes);
        return;
      }

      // 2. For documents (PDF, Excel, CSV), use FilePicker with fallback to FileType.any
      PlatformFile? file;
      try {
        file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: allowedExtensions ??
              ['pdf', 'xlsx', 'xls', 'csv', 'png', 'jpg', 'jpeg', 'webp'],
        );
      } catch (e) {
        debugPrint(
          'FilePicker custom extension failed, falling back to any: $e',
        );
        file = await FilePicker.pickFile(type: FileType.any);
      }

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        _showSnackbar('Could not read file data. Please try another file.');
        return;
      }

      await _processFileBytes(file.name, bytes);
    } catch (e) {
      _showSnackbar('Unable to select file: $e');
    }
  }

  Future<void> _processFileBytes(String fileName, Uint8List bytes) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'FinPilot AI is parsing $fileName...';
      _importSuccessful = false;
      _currentResult = null;
    });

    try {
      final finance = Provider.of<FinanceProvider>(context, listen: false);

      final analysis = await _analyzer.analyzeStatement(
        fileName: fileName,
        bytes: bytes,
        existingTransactions: finance.transactions,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _currentResult = analysis;
      });

      if (analysis.isScannedPdfDetected) {
        _showSnackbar(
          'Scanned PDF detected. Text extraction produced limited characters.',
        );
      } else if (analysis.transactions.isEmpty) {
        _showSnackbar(
          analysis.parsingWarning ?? 'No transactions detected in this file.',
        );
      } else {
        _showSnackbar(
          '${analysis.totalCount} transactions detected from $fileName',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackbar('Failed to parse statement: $e');
    }
  }

  void _loadDemoData() {
    final now = DateTime.now();
    final demoTransactions = [
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 1, 10, 0),
        merchant: 'Salary Credit',
        description: 'NEFT CR-SALARY-TECH CORP INDIA',
        amount: 85000.0,
        type: TransactionType.income,
        category: 'Income',
        paymentMethod: 'Bank Transfer',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 99,
          amount: 99,
          date: 98,
          category: 99,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 2, 19, 30),
        merchant: 'Swiggy',
        description: 'UPI/382914/Swiggy Order/Bangalore',
        amount: 540.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 98,
          amount: 99,
          date: 96,
          category: 96,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 3, 9, 15),
        merchant: 'Uber',
        description: 'UPI-UBER-RIDES-IN-83921',
        amount: 320.0,
        type: TransactionType.expense,
        category: 'Transport',
        paymentMethod: 'UPI',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 96,
          amount: 98,
          date: 95,
          category: 95,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 4, 14, 0),
        merchant: 'Amazon',
        description: 'POS 4012 AMAZON RETAIL MUMBAI',
        amount: 2450.0,
        type: TransactionType.expense,
        category: 'Shopping',
        paymentMethod: 'Credit Card',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 95,
          amount: 97,
          date: 94,
          category: 92,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 5, 11, 20),
        merchant: 'Zepto',
        description: 'UPI/Zepto Grocery Delivery/8421',
        amount: 590.0,
        type: TransactionType.expense,
        category: 'Groceries',
        paymentMethod: 'UPI',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 97,
          amount: 98,
          date: 95,
          category: 96,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 7, 16, 45),
        merchant: 'Electricity Board',
        description: 'BILLDESK-BESCOM-ELECTRICITY-BILL',
        amount: 1850.0,
        type: TransactionType.expense,
        category: 'Bills',
        paymentMethod: 'Bank Transfer',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 94,
          amount: 98,
          date: 92,
          category: 95,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 8, 20, 0),
        merchant: 'Netflix',
        description: 'RECURRING NETFLIX ENTERTAINMENT',
        amount: 649.0,
        type: TransactionType.expense,
        category: 'Entertainment',
        paymentMethod: 'Credit Card',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 98,
          amount: 99,
          date: 96,
          category: 98,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 10, 12, 10),
        merchant: 'Apollo Pharmacy',
        description: 'POS APOLLO PHARMACY HEALTHCARE',
        amount: 820.0,
        type: TransactionType.expense,
        category: 'Health',
        paymentMethod: 'UPI',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 96,
          amount: 98,
          date: 95,
          category: 95,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 12, 10, 30),
        merchant: 'House Rent',
        description: 'IMPS-RENT TRANSFER-LANDLORD',
        amount: 25000.0,
        type: TransactionType.expense,
        category: 'Housing',
        paymentMethod: 'Bank Transfer',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 92,
          amount: 99,
          date: 94,
          category: 95,
        ),
      ),
      ParsedStatementTransaction(
        id: const Uuid().v4(),
        date: DateTime(now.year, now.month, 15, 18, 0),
        merchant: 'Freelance Design',
        description: 'IMPS CR-FREELANCE DESIGN CLIENT',
        amount: 15000.0,
        type: TransactionType.income,
        category: 'Income',
        paymentMethod: 'Bank Transfer',
        source: 'PDF',
        confidence: const ConfidenceScores(
          merchant: 95,
          amount: 98,
          date: 94,
          category: 96,
        ),
      ),
    ];

    double inc = 0;
    double exp = 0;
    final Map<String, double> breakdown = {};
    for (final t in demoTransactions) {
      if (t.type == TransactionType.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
        breakdown[t.category] = (breakdown[t.category] ?? 0) + t.amount;
      }
    }

    final demoResult = StatementAnalysisResult(
      fileName: 'September_Statement_2026.pdf',
      format: StatementFormat.pdf,
      transactions: demoTransactions,
      totalIncome: inc,
      totalExpense: exp,
      netCashFlow: inc - exp,
      duplicateCount: 0,
      summaryInsight:
          'Your September cash flow is positive by \u20B9${(inc - exp).toStringAsFixed(0)}. Housing & Rent and Shopping are your largest expenditures.',
      spendingBreakdown: breakdown,
    );

    setState(() {
      _currentResult = demoResult;
      _importSuccessful = false;
    });

    _showSnackbar(
      'Loaded demonstration bank statement with 10 structured transactions.',
    );
  }

  Future<void> _confirmAndImportTransactions() async {
    if (_currentResult == null) return;

    final selected = _currentResult!.transactions
        .where((t) => t.selected)
        .toList();

    if (selected.isEmpty) {
      _showSnackbar('Please select at least one transaction to import.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage =
          'Importing ${selected.length} transactions into FinPilot...';
    });

    try {
      final finance = Provider.of<FinanceProvider>(context, listen: false);

      for (final pt in selected) {
        final tx = pt.toFinanceTransaction();
        await finance.addTransaction(tx);
      }

      // Record in history
      final historyItem = ImportHistoryItem(
        id: const Uuid().v4(),
        fileName: _currentResult!.fileName,
        importedAt: DateTime.now(),
        transactionCount: selected.length,
        totalIncome: selected
            .where((t) => t.type == TransactionType.income)
            .fold(0.0, (s, t) => s + t.amount),
        totalExpense: selected
            .where((t) => t.type == TransactionType.expense)
            .fold(0.0, (s, t) => s + t.amount),
        format: _currentResult!.format.name.toUpperCase(),
      );

      await _saveImportHistory(historyItem);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _importSuccessful = true;
        _lastImportedCount = selected.length;
      });

      _showSnackbar(
        '${selected.length} transactions imported into FinPilot successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackbar('Import failed: $e');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: cardLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // Edit transaction modal
  void _editTransaction(ParsedStatementTransaction tx) {
    final merchantCtrl = TextEditingController(text: tx.merchant);
    final amountCtrl = TextEditingController(
      text: tx.amount.toStringAsFixed(2),
    );
    String cat = tx.category;
    TransactionType type = tx.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Transaction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: merchantCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Merchant / Description',
                      labelStyle: const TextStyle(color: textMuted),
                      filled: true,
                      fillColor: cardLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Amount (\u20B9)',
                      labelStyle: const TextStyle(color: textMuted),
                      filled: true,
                      fillColor: cardLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TransactionType>(
                          value: type,
                          dropdownColor: cardLight,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            labelStyle: const TextStyle(color: textMuted),
                            filled: true,
                            fillColor: cardLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: TransactionType.expense,
                              child: Text(
                                'Expense',
                                style: TextStyle(color: dangerRed),
                              ),
                            ),
                            DropdownMenuItem(
                              value: TransactionType.income,
                              child: Text(
                                'Income',
                                style: TextStyle(color: successGreen),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => type = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value:
                              TransactionCategorizationService.allCategories
                                  .contains(cat)
                              ? cat
                              : 'Other',
                          dropdownColor: cardLight,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: const TextStyle(color: textMuted),
                            filled: true,
                            fillColor: cardLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: TransactionCategorizationService.allCategories
                              .map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => cat = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final parsedAmt =
                            double.tryParse(amountCtrl.text.trim()) ??
                            tx.amount;
                        setState(() {
                          tx.merchant = merchantCtrl.text.trim();
                          tx.amount = parsedAmt;
                          tx.category = cat;
                          tx.type = type;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statement Intelligence',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Universal bank statement parser & analyzer',
              style: TextStyle(color: textMuted, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showHistoryModal,
            icon: const Icon(Icons.history_rounded, color: cyanAccent),
            tooltip: 'Import History',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
                child: _importSuccessful
                    ? _buildImportSuccessView()
                    : _currentResult != null &&
                          _currentResult!.transactions.isNotEmpty
                    ? _buildPreviewSection()
                    : _buildUploadSection(),
              ),
            ),
    );
  }

  // ============================================================
  // LOADING VIEW
  // ============================================================
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  primaryPurple.withValues(alpha: 0.25),
                  cyanAccent.withValues(alpha: 0.2),
                ],
              ),
              border: Border.all(color: cyanAccent.withValues(alpha: 0.4)),
            ),
            child: const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(cyanAccent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _loadingMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analyzing rows, categories, and duplicate records...',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UPLOAD SECTION (Initial Screen)
  // ============================================================
  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                primaryPurple.withValues(alpha: 0.3),
                cyanAccent.withValues(alpha: 0.08),
                cardDark,
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [primaryPurple, cyanAccent],
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Bank Statement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Upload a statement in almost any format. FinPilot will organize your transactions automatically.',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Supported formats badge strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cyanAccent.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: cyanAccent,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SUPPORTED FORMATS: PDF \u2022 Images \u2022 Screenshots \u2022 Excel \u2022 CSV',
                        style: TextStyle(
                          color: cyanAccent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 4 Format Cards Grid
        const Text(
          'Select Format or Upload Directly',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFormatCard(
                icon: Icons.picture_as_pdf_rounded,
                title: 'PDF',
                subtitle: 'Bank statement PDF',
                color: dangerRed,
                onTap: () => _pickStatementFile(allowedExtensions: ['pdf']),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormatCard(
                icon: Icons.photo_camera_rounded,
                title: 'IMAGE',
                subtitle: 'Screenshot / JPG / PNG',
                color: cyanAccent,
                onTap: () => _pickStatementFile(
                  allowedExtensions: ['png', 'jpg', 'jpeg'],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFormatCard(
                icon: Icons.table_chart_rounded,
                title: 'EXCEL',
                subtitle: 'XLSX / XLS',
                color: successGreen,
                onTap: () =>
                    _pickStatementFile(allowedExtensions: ['xlsx', 'xls']),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormatCard(
                icon: Icons.description_rounded,
                title: 'CSV',
                subtitle: 'Spreadsheet data',
                color: primaryPurple,
                onTap: () => _pickStatementFile(allowedExtensions: ['csv']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Primary Upload Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => _pickStatementFile(),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 6,
              shadowColor: primaryPurple.withValues(alpha: 0.4),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryPurple, cyanAccent],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Upload Statement',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Test Demo Data Button
        Center(
          child: TextButton.icon(
            onPressed: _loadDemoData,
            icon: const Icon(
              Icons.science_rounded,
              color: cyanAccent,
              size: 16,
            ),
            label: const Text(
              'Load Sample Statement Demo Data',
              style: TextStyle(
                color: cyanAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
        _buildHowItWorksCard(),
      ],
    );
  }

  Widget _buildFormatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // IMPORT PREVIEW SECTION
  // ============================================================
  Widget _buildPreviewSection() {
    final result = _currentResult!;
    final selectedCount = result.transactions.where((t) => t.selected).length;
    final duplicates = result.transactions.where((t) => t.isDuplicate).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statement Analysis Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryPurple.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'STATEMENT ANALYSIS',
                      style: TextStyle(
                        color: cyanAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _currentResult = null),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: textMuted,
                      size: 20,
                    ),
                    tooltip: 'Cancel & Re-upload',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Metrics Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Detected',
                      '${result.totalCount}',
                      cyanAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Income',
                      CurrencyFormatter.format(result.totalIncome),
                      successGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Expenses',
                      CurrencyFormatter.format(result.totalExpense),
                      dangerRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cardLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Cash Flow:',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                    Text(
                      '${result.netCashFlow >= 0 ? '+' : ''}${CurrencyFormatter.format(result.netCashFlow)}',
                      style: TextStyle(
                        color: result.netCashFlow >= 0
                            ? successGreen
                            : warningOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Duplicate Banner if detected
        if (duplicates.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: warningOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: warningOrange.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: warningOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${duplicates.length} possible duplicate transactions found',
                      style: const TextStyle(
                        color: warningOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Duplicates have been automatically unselected to prevent double-counting.',
                  style: TextStyle(color: textMuted, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (final d in duplicates) {
                            d.selected = false;
                          }
                        });
                      },
                      child: const Text(
                        'Skip All Duplicates',
                        style: TextStyle(color: cyanAccent, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (final d in duplicates) {
                            d.selected = true;
                          }
                        });
                      },
                      child: const Text(
                        'Include Anyway',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Transactions Table Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transactions (${result.totalCount})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    final allSelected = result.transactions.every(
                      (t) => t.selected,
                    );
                    setState(() {
                      for (final t in result.transactions) {
                        t.selected = !allSelected;
                      }
                    });
                  },
                  child: Text(
                    result.transactions.every((t) => t.selected)
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(color: cyanAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Transaction List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: result.transactions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final tx = result.transactions[index];
            return _buildTransactionRow(tx);
          },
        ),
        const SizedBox(height: 24),

        // Bottom Import Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$selectedCount transactions ready to import',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${result.totalCount - selectedCount} skipped',
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selectedCount > 0
                      ? _confirmAndImportTransactions
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Import $selectedCount Transactions',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: cardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(ParsedStatementTransaction tx) {
    final isIncome = tx.type == TransactionType.income;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tx.selected ? cardDark : cardDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tx.isDuplicate
              ? warningOrange.withValues(alpha: 0.4)
              : (tx.selected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: tx.selected,
            activeColor: cyanAccent,
            checkColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: (val) {
              setState(() {
                tx.selected = val ?? false;
              });
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => _editTransaction(tx),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx.merchant.isNotEmpty ? tx.merchant : tx.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tx.selected ? Colors.white : textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
                        style: TextStyle(
                          color: isIncome ? successGreen : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(tx.date),
                        style: const TextStyle(color: textMuted, fontSize: 11),
                      ),
                      const Text(
                        ' \u2022 ',
                        style: TextStyle(color: textMuted, fontSize: 10),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cardLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tx.category,
                          style: const TextStyle(
                            color: cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Confidence pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tx.confidence.hasLowConfidence
                              ? warningOrange.withValues(alpha: 0.15)
                              : successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tx.confidence.hasLowConfidence
                              ? 'Review'
                              : '${tx.confidence.amount}% conf',
                          style: TextStyle(
                            color: tx.confidence.hasLowConfidence
                                ? warningOrange
                                : successGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (tx.isDuplicate) ...[
                    const SizedBox(height: 4),
                    Text(
                      tx.duplicateReason,
                      style: const TextStyle(
                        color: warningOrange,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _editTransaction(tx),
            icon: const Icon(Icons.edit_outlined, color: textMuted, size: 16),
            tooltip: 'Edit transaction',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // IMPORT SUCCESS & AI ANALYSIS VIEW
  // ============================================================
  Widget _buildImportSuccessView() {
    final result = _currentResult!;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: successGreen.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: successGreen.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: successGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: successGreen,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '\u2713 STATEMENT ANALYZED & IMPORTED',
                      style: TextStyle(
                        color: successGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$_lastImportedCount Transactions',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.fileName,
                style: const TextStyle(color: textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Total Income',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(result.totalIncome),
                        style: const TextStyle(
                          color: successGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Column(
                    children: [
                      const Text(
                        'Total Expenses',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(result.totalExpense),
                        style: const TextStyle(
                          color: dangerRed,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Column(
                    children: [
                      const Text(
                        'Net Cash Flow',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(result.netCashFlow),
                        style: const TextStyle(
                          color: cyanAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Statement Insights Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryPurple.withValues(alpha: 0.15), cardDark],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: primaryPurple,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'STATEMENT INSIGHTS',
                    style: TextStyle(
                      color: primaryPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '"${result.summaryInsight}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'SPENDING BREAKDOWN',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...result.spendingBreakdown.entries.map((entry) {
                final pct = result.totalExpense > 0
                    ? (entry.value / result.totalExpense)
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${CurrencyFormatter.format(entry.value)} (${(pct * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: cardLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            cyanAccent,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentResult = null;
                    _importSuccessful = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Import Another',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Go to Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // IMPORT HISTORY MODAL
  // ============================================================
  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Import History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_history.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No statements imported yet.',
                          style: TextStyle(color: textMuted, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: _history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final item = _history[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryPurple.withValues(
                                          alpha: 0.25,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.format,
                                        style: const TextStyle(
                                          color: cyanAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.transactionCount} transactions',
                                      style: const TextStyle(
                                        color: textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('dd MMM yyyy, HH:mm')
                                          .format(item.importedAt),
                                      style: const TextStyle(
                                        color: textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'Income: ${CurrencyFormatter.format(item.totalIncome)}',
                                      style: const TextStyle(
                                        color: successGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      'Expense: ${CurrencyFormatter.format(item.totalExpense)}',
                                      style: const TextStyle(
                                        color: dangerRed,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHowItWorksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: cyanAccent,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'HOW THE INTELLIGENCE CENTER WORKS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '1. Upload PDF, image screenshot, Excel (.xlsx), or CSV bank statement.',
            style: TextStyle(color: textMuted, fontSize: 11.5),
          ),
          SizedBox(height: 6),
          Text(
            '2. FinPilot automatically identifies columns, amounts, dates, and Dr/Cr indicators.',
            style: TextStyle(color: textMuted, fontSize: 11.5),
          ),
          SizedBox(height: 6),
          Text(
            '3. Intelligent categorization engine extracts clean merchants and categories.',
            style: TextStyle(color: textMuted, fontSize: 11.5),
          ),
          SizedBox(height: 6),
          Text(
            '4. Probable duplicates with your existing transactions are detected and highlighted.',
            style: TextStyle(color: textMuted, fontSize: 11.5),
          ),
          SizedBox(height: 6),
          Text(
            '5. Review, adjust, and confirm to update your Dashboard, Budgets, and AI Insights.',
            style: TextStyle(color: textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
