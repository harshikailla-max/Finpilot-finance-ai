import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../providers/finance_provider.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() =>
      _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // IMAGE / OCR STATE
  // ============================================================

  File? _receiptImage;
  bool _isScanning = false;
  bool _hasScanned = false;

  String _rawText = '';
  String _aiInsight = '';

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _merchantController =
      TextEditingController();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _dateController =
      TextEditingController();

  final TextEditingController _noteController =
      TextEditingController();

  // ============================================================
  // FORM STATE
  // ============================================================

  String _selectedCategory = 'Other';

  final List<String> _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Other',
  ];

  // ============================================================
  // COLORS
  // ============================================================

  static const Color background = Color(0xFF050914);
  static const Color card = Color(0xFF0D1528);
  static const Color purple = Color(0xFF5B4BFF);
  static const Color cyan = Color(0xFF4CC9F0);
  static const Color white = Colors.white;
  static const Color secondaryText = Color(0xFF9AA4B2);

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ============================================================
  // SELECT BILL
  // ============================================================

  Future<void> _chooseBill() async {
    if (kIsWeb) {
      _showMessage(
        'Bill scanning is available on Android and iOS. '
        'Please run FinPilot AI on a mobile device.',
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) return;

      await _processImage(image);
    } catch (e) {
      _showMessage(
        'Unable to select the bill. Please try again.',
      );
    }
  }

  // ============================================================
  // PROCESS BILL
  // ============================================================

  Future<void> _processImage(XFile image) async {
    if (kIsWeb) {
      _showMessage(
        'Bill OCR currently works on Android and iOS.',
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _hasScanned = false;
      _aiInsight = '';
    });

    try {
      final File file = File(image.path);

      setState(() {
        _receiptImage = file;
      });

      final InputImage inputImage =
          InputImage.fromFilePath(image.path);

      final TextRecognizer textRecognizer =
          TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      await textRecognizer.close();

      if (!mounted) return;

      final String text = recognizedText.text;

      if (text.trim().isEmpty) {
        setState(() {
          _isScanning = false;
          _hasScanned = false;
        });

        _showMessage(
          'No readable text was found. Please select a clearer bill.',
        );

        return;
      }

      setState(() {
        _rawText = text;
        _hasScanned = true;
        _isScanning = false;
      });

      _extractReceiptData(text);
      _generateAIInsight();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isScanning = false;
      });

      _showMessage(
        'Could not read this bill. Try a clearer image.',
      );
    }
  }

  // ============================================================
  // EXTRACT ALL BILL DATA
  // ============================================================

  void _extractReceiptData(String text) {
    final String merchant = _extractMerchant(text);
    final String amount = _extractAmount(text);
    final String date = _extractDate(text);
    final String category = _detectCategory(text);

    _merchantController.text = merchant;
    _amountController.text = amount;
    _dateController.text = date;

    setState(() {
      _selectedCategory = category;
    });
  }

  // ============================================================
  // MERCHANT DETECTION
  // ============================================================

  String _extractMerchant(String text) {
    final String lower = text.toLowerCase();

    const List<String> knownMerchants = [
      'swiggy',
      'zomato',
      'amazon',
      'flipkart',
      'uber',
      'ola',
      'blinkit',
      'zepto',
      'myntra',
      'dominos',
      'domino',
      'mcdonald',
      'starbucks',
      'netflix',
      'decathlon',
      'reliance',
      'dmart',
      'big bazaar',
      'zara',
      'pizza hut',
      'kfc',
      'ajio',
      'apollo',
    ];

    for (final String merchant in knownMerchants) {
      if (lower.contains(merchant)) {
        return merchant
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}'
                    '${word.substring(1)}',
            )
            .join(' ');
      }
    }

    final List<String> lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (int i = 0; i < lines.length && i < 8; i++) {
      final String line = lines[i];

      final bool containsNumber =
          RegExp(r'\d').hasMatch(line);

      final bool looksLikeAmount = RegExp(
        r'(₹|rs\.?|inr)\s*\d+',
        caseSensitive: false,
      ).hasMatch(line);

      if (!containsNumber &&
          !looksLikeAmount &&
          line.length >= 3 &&
          line.length <= 40) {
        return line;
      }
    }

    return 'Receipt Expense';
  }

  // ============================================================
  // AMOUNT DETECTION
  // ============================================================

  String _extractAmount(String text) {
    // ----------------------------------------------------------
    // PRIORITY 1: TOTAL
    // ----------------------------------------------------------

    final RegExp totalRegex = RegExp(
      r'(grand\s*total|total\s*amount|amount\s*payable|'
      r'net\s*amount|total)'
      r'.{0,25}?'
      r'(?:₹|rs\.?|inr)?\s*'
      r'([0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
      dotAll: true,
    );

    final Match? totalMatch =
        totalRegex.firstMatch(text);

    if (totalMatch != null) {
      final String? amount = totalMatch.group(2);

      if (amount != null) {
        return _cleanAmount(amount);
      }
    }

    // ----------------------------------------------------------
    // PRIORITY 2: CURRENCY AMOUNT
    // ----------------------------------------------------------

    final RegExp currencyRegex = RegExp(
      r'(?:₹|rs\.?|inr)\s*'
      r'([0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );

    final Iterable<Match> currencyMatches =
        currencyRegex.allMatches(text);

    if (currencyMatches.isNotEmpty) {
      final Match match = currencyMatches.last;

      final String? amount = match.group(1);

      if (amount != null) {
        return _cleanAmount(amount);
      }
    }

    // ----------------------------------------------------------
    // PRIORITY 3: LARGEST REASONABLE NUMBER
    // ----------------------------------------------------------

    final List<double> amounts = [];

    final RegExp numberRegex = RegExp(
      r'\b\d{1,7}(?:[.,]\d{1,2})?\b',
    );

    for (final Match match
        in numberRegex.allMatches(text)) {
      final String value = match.group(0)!;

      final double? parsed = double.tryParse(
        value.replaceAll(',', ''),
      );

      if (parsed != null &&
          parsed > 10 &&
          parsed < 1000000) {
        amounts.add(parsed);
      }
    }

    if (amounts.isNotEmpty) {
      amounts.sort();
      return amounts.last.toStringAsFixed(2);
    }

    return '';
  }

  String _cleanAmount(String value) {
    final String cleaned = value.replaceAll(',', '');

    final double? amount =
        double.tryParse(cleaned);

    if (amount == null) {
      return value;
    }

    return amount.toStringAsFixed(2);
  }

  // ============================================================
  // DATE DETECTION
  // ============================================================

  String _extractDate(String text) {
    // DD/MM/YYYY

    final RegExp ddmmyyyy = RegExp(
      r'\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})\b',
    );

    final Match? match1 =
        ddmmyyyy.firstMatch(text);

    if (match1 != null) {
      return '${match1.group(1)!.padLeft(2, '0')}/'
          '${match1.group(2)!.padLeft(2, '0')}/'
          '${match1.group(3)}';
    }

    // YYYY/MM/DD

    final RegExp yyyymmdd = RegExp(
      r'\b(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})\b',
    );

    final Match? match2 =
        yyyymmdd.firstMatch(text);

    if (match2 != null) {
      return '${match2.group(3)!.padLeft(2, '0')}/'
          '${match2.group(2)!.padLeft(2, '0')}/'
          '${match2.group(1)}';
    }

    // No date detected

    final DateTime now = DateTime.now();

    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';
  }

  // ============================================================
  // CATEGORY DETECTION
  // ============================================================

  String _detectCategory(String text) {
    final String lower = text.toLowerCase();

    // FOOD

    if (_containsAny(lower, [
      'swiggy',
      'zomato',
      'restaurant',
      'food',
      'cafe',
      'coffee',
      'pizza',
      'burger',
      'kfc',
      'mcdonald',
      'domino',
      'starbucks',
      'bakery',
    ])) {
      return 'Food';
    }

    // TRANSPORT

    if (_containsAny(lower, [
      'uber',
      'ola',
      'rapido',
      'taxi',
      'cab',
      'fuel',
      'petrol',
      'diesel',
      'metro',
      'bus',
      'parking',
    ])) {
      return 'Transport';
    }

    // SHOPPING

    if (_containsAny(lower, [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'zara',
      'shopping',
      'clothing',
      'fashion',
      'mall',
      'dmart',
      'reliance',
      'supermarket',
    ])) {
      return 'Shopping';
    }

    // BILLS

    if (_containsAny(lower, [
      'electricity',
      'water bill',
      'gas bill',
      'internet',
      'wifi',
      'mobile recharge',
      'broadband',
      'bill',
    ])) {
      return 'Bills';
    }

    // ENTERTAINMENT

    if (_containsAny(lower, [
      'netflix',
      'prime video',
      'spotify',
      'movie',
      'cinema',
      'pvr',
      'inox',
      'entertainment',
      'game',
    ])) {
      return 'Entertainment';
    }

    // HEALTH

    if (_containsAny(lower, [
      'hospital',
      'clinic',
      'pharmacy',
      'medical',
      'medicine',
      'doctor',
      'health',
      'apollo',
    ])) {
      return 'Health';
    }

    // EDUCATION

    if (_containsAny(lower, [
      'college',
      'university',
      'school',
      'course',
      'education',
      'book',
      'stationery',
      'udemy',
      'coursera',
    ])) {
      return 'Education';
    }

    return 'Other';
  }

  bool _containsAny(
    String text,
    List<String> keywords,
  ) {
    for (final String keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // AI INSIGHT
  // ============================================================

  void _generateAIInsight() {
    final String amountText = _amountController.text
        .trim()
        .replaceAll(',', '');

    final double? amount =
        double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      setState(() {
        _aiInsight =
            'Add a valid bill amount to generate your spending insight.';
      });

      return;
    }

    final String category = _selectedCategory;
    final String merchant =
        _merchantController.text.trim();

    String insight;

    if (amount >= 10000) {
      insight =
          'This is a high-value expense. '
          'FinPilot AI recommends reviewing whether '
          'this purchase was planned and necessary.';
    } else if (amount >= 5000) {
      insight =
          'This is a significant '
          '${category.toLowerCase()} expense. '
          'Consider checking your monthly budget '
          'before making similar purchases.';
    } else if (amount >= 2000) {
      insight =
          'This ${category.toLowerCase()} purchase '
          'is moderate in size. Keep an eye on similar '
          'expenses to stay within your monthly budget.';
    } else if (amount >= 1000) {
      insight =
          'This expense looks manageable, but repeated '
          'purchases of this type could affect your '
          'monthly savings.';
    } else {
      insight =
          'This is a relatively small expense. '
          'Tracking these purchases helps FinPilot AI '
          'identify your spending patterns over time.';
    }

    if (merchant.isNotEmpty) {
      insight = '$insight\n\n'
          'Merchant: $merchant\n'
          'Category: $category\n'
          'Amount: ₹${amount.toStringAsFixed(2)}';
    }

    setState(() {
      _aiInsight = insight;
    });
  }

  // ============================================================
  // PARSE DATE
  // ============================================================

  DateTime _parseReceiptDate() {
    final String value =
        _dateController.text.trim();

    final RegExp regex = RegExp(
      r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$',
    );

    final Match? match =
        regex.firstMatch(value);

    if (match != null) {
      final int? day =
          int.tryParse(match.group(1)!);

      final int? month =
          int.tryParse(match.group(2)!);

      final int? year =
          int.tryParse(match.group(3)!);

      if (day != null &&
          month != null &&
          year != null) {
        final DateTime date =
            DateTime(year, month, day);

        if (date.year == year &&
            date.month == month &&
            date.day == day) {
          return date;
        }
      }
    }

    return DateTime.now();
  }

  // ============================================================
  // ADD TO EXPENSES
  // ============================================================

  Future<void> _saveExpense() async {
    final String merchant =
        _merchantController.text.trim();

    final String amountText =
        _amountController.text
            .trim()
            .replaceAll(',', '');

    final double? amount =
        double.tryParse(amountText);

    if (merchant.isEmpty) {
      _showMessage(
        'Please enter the merchant name.',
      );
      return;
    }

    if (amount == null || amount <= 0) {
      _showMessage(
        'Please enter a valid amount.',
      );
      return;
    }

    final DateTime transactionDate =
        _parseReceiptDate();

    final FinanceTransaction transaction =
        FinanceTransaction(
      id: const Uuid().v4(),
      title: merchant,
      amount: amount,
      category: _selectedCategory,
      type: TransactionType.expense,
      date: transactionDate,
      paymentMethod: 'UPI',
      note: _noteController.text.trim().isEmpty
          ? 'Added using AI Bill Scanner'
          : _noteController.text.trim(),
      merchant: merchant,
      isRecurring: false,
      createdAt: DateTime.now(),
    );

    try {
      await context
          .read<FinanceProvider>()
          .addTransaction(transaction);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              const Color(0xFF121C31),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '₹${amount.toStringAsFixed(2)} '
                  'expense added successfully!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      _showMessage(
        'Could not add expense. Please try again.',
      );
    }
  }

  // ============================================================
  // SCAN ANOTHER BILL
  // ============================================================

  void _scanAgain() {
    setState(() {
      _receiptImage = null;
      _hasScanned = false;
      _isScanning = false;
      _rawText = '';
      _aiInsight = '';

      _merchantController.clear();
      _amountController.clear();
      _dateController.clear();
      _noteController.clear();

      _selectedCategory = 'Other';
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            const Color(0xFF121C31),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,

        title: const Text(
          'AI Bill Scanner',
          style: TextStyle(
            color: white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: white,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        actions: [
          if (_hasScanned)
            IconButton(
              tooltip: 'Scan another bill',
              icon: const Icon(
                Icons.refresh_rounded,
                color: cyan,
              ),
              onPressed: _scanAgain,
            ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            30,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              _buildHeader(),

              const SizedBox(height: 22),

              if (_receiptImage == null &&
                  !_isScanning)
                _buildScannerOptions(),

              if (_isScanning)
                _buildScanningView(),

              if (_receiptImage != null &&
                  !_isScanning)
                _buildReceiptPreview(),

              if (_hasScanned &&
                  !_isScanning) ...[
                const SizedBox(height: 24),

                _buildDetectedBadge(),

                const SizedBox(height: 18),

                _buildForm(),

                const SizedBox(height: 20),

                _buildAIInsight(),

                const SizedBox(height: 24),

                _buildDetectedText(),

                const SizedBox(height: 28),

                _buildSaveButton(),

                const SizedBox(height: 14),

                _buildScanAgainButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),

        gradient: LinearGradient(
          colors: [
            purple.withValues(alpha: 0.20),
            cyan.withValues(alpha: 0.08),
          ],
        ),

        border: Border.all(
          color: purple.withValues(alpha: 0.20),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: const LinearGradient(
                colors: [
                  purple,
                  cyan,
                ],
              ),

              boxShadow: [
                BoxShadow(
                  color:
                      purple.withValues(alpha: 0.30),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),

            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan & Track',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Upload a bill and let AI extract '
                  'your expense automatically',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCANNER OPTIONS
  // ============================================================

  Widget _buildScannerOptions() {
    return Column(
      children: [
        Container(
          width: double.infinity,

          padding:
              const EdgeInsets.symmetric(
            vertical: 38,
            horizontal: 20,
          ),

          decoration: BoxDecoration(
            color: card,
            borderRadius:
                BorderRadius.circular(26),

            border: Border.all(
              color:
                  Colors.white.withValues(alpha: 0.08),
            ),
          ),

          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color:
                      purple.withValues(alpha: 0.12),

                  border: Border.all(
                    color:
                        purple.withValues(alpha: 0.25),
                  ),
                ),

                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: purple,
                  size: 42,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Scan Your Bill',
                style: TextStyle(
                  color: white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Upload a bill or receipt and FinPilot AI '
                'will extract the expense details for you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              _buildOptionButton(
                icon: Icons.upload_file_rounded,
                label: 'SCAN BILL',
                color: purple,
                onTap: _chooseBill,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        _buildInfoCard(),
      ],
    );
  }

  // ============================================================
  // SCAN BUTTON
  // ============================================================

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: double.infinity,
        height: 58,

        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(17),

          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0.08),
            ],
          ),

          border: Border.all(
            color:
                color.withValues(alpha: 0.30),
          ),
        ),

        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              color: color,
              size: 21,
            ),

            const SizedBox(width: 8),

            Text(
              label,
              style: const TextStyle(
                color: white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: cyan.withValues(alpha: 0.05),

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color:
              cyan.withValues(alpha: 0.12),
        ),
      ),

      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: cyan,
            size: 20,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'FinPilot AI detects the merchant, '
              'total amount, date and category, '
              'then provides a smart spending insight '
              'before adding it to your expenses.',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCANNING VIEW
  // ============================================================

  Widget _buildScanningView() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(35),

      decoration: BoxDecoration(
        color: card,

        borderRadius:
            BorderRadius.circular(26),

        border: Border.all(
          color:
              purple.withValues(alpha: 0.18),
        ),
      ),

      child: Column(
        children: [
          const SizedBox(height: 10),

          Container(
            width: 80,
            height: 80,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color:
                  purple.withValues(alpha: 0.12),
            ),

            child: const Center(
              child:
                  CircularProgressIndicator(
                color: cyan,
                strokeWidth: 3,
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Analyzing Bill...',
            style: TextStyle(
              color: white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'FinPilot AI is extracting transaction details',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 20),

          LinearProgressIndicator(
            minHeight: 4,

            borderRadius:
                BorderRadius.circular(10),

            backgroundColor:
                Colors.white.withValues(alpha: 0.06),

            valueColor:
                const AlwaysStoppedAnimation<Color>(
              cyan,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BILL PREVIEW
  // ============================================================

  Widget _buildReceiptPreview() {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(24),

      child: Container(
        width: double.infinity,
        height: 280,

        decoration: BoxDecoration(
          color: card,
          borderRadius:
              BorderRadius.circular(24),
        ),

        child: Stack(
          fit: StackFit.expand,

          children: [
            Image.file(
              _receiptImage!,
              fit: BoxFit.cover,
            ),

            Positioned(
              top: 14,
              right: 14,

              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),

                decoration: BoxDecoration(
                  color:
                      Colors.black.withValues(alpha: 0.65),

                  borderRadius:
                      BorderRadius.circular(20),
                ),

                child: const Row(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                      size: 16,
                    ),

                    SizedBox(width: 6),

                    Text(
                      'Bill loaded',
                      style: TextStyle(
                        color: white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETECTED BADGE
  // ============================================================

  Widget _buildDetectedBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),

      decoration: BoxDecoration(
        color:
            Colors.greenAccent.withValues(alpha: 0.07),

        borderRadius:
            BorderRadius.circular(14),

        border: Border.all(
          color:
              Colors.greenAccent.withValues(alpha: 0.15),
        ),
      ),

      child: const Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: Colors.greenAccent,
            size: 18,
          ),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              'AI detected your bill details. '
              'Review them before adding to expenses.',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORM
  // ============================================================

  Widget _buildForm() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _buildSectionTitle(
          'REVIEW BILL',
          Icons.edit_note_rounded,
        ),

        const SizedBox(height: 14),

        _buildTextField(
          controller: _merchantController,
          label: 'Merchant',
          hint: 'Enter merchant name',
          icon: Icons.storefront_rounded,
        ),

        const SizedBox(height: 13),

        _buildTextField(
          controller: _amountController,
          label: 'Amount',
          hint: 'Enter amount',
          icon: Icons.currency_rupee_rounded,
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),

        const SizedBox(height: 13),

        _buildTextField(
          controller: _dateController,
          label: 'Date',
          hint: 'DD/MM/YYYY',
          icon: Icons.calendar_month_rounded,
        ),

        const SizedBox(height: 13),

        _buildCategoryDropdown(),

        const SizedBox(height: 13),

        _buildTextField(
          controller: _noteController,
          label: 'Note',
          hint: 'Optional note',
          icon: Icons.notes_rounded,
          maxLines: 3,
        ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: cyan,
          size: 19,
        ),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(
            color: white,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: card,

        borderRadius:
            BorderRadius.circular(17),

        border: Border.all(
          color:
              Colors.white.withValues(alpha: 0.07),
        ),
      ),

      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,

        style: const TextStyle(
          color: white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),

        decoration: InputDecoration(
          labelText: label,
          hintText: hint,

          labelStyle: const TextStyle(
            color: secondaryText,
            fontSize: 12,
          ),

          hintStyle: const TextStyle(
            color: Color(0xFF596477),
            fontSize: 13,
          ),

          prefixIcon: Icon(
            icon,
            color: purple,
            size: 20,
          ),

          border: InputBorder.none,

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY DROPDOWN
  // ============================================================

  Widget _buildCategoryDropdown() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 3,
      ),

      decoration: BoxDecoration(
        color: card,

        borderRadius:
            BorderRadius.circular(17),

        border: Border.all(
          color:
              Colors.white.withValues(alpha: 0.07),
        ),
      ),

      child: Row(
        children: [
          const Icon(
            Icons.category_rounded,
            color: purple,
            size: 20,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,

                dropdownColor:
                    const Color(0xFF111B30),

                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: secondaryText,
                ),

                style: const TextStyle(
                  color: white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),

                items: _categories
                    .map(
                      (category) =>
                          DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),

                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedCategory = value;
                  });

                  _generateAIInsight();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AI INSIGHT
  // ============================================================

  Widget _buildAIInsight() {
    if (_aiInsight.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(22),

        gradient: LinearGradient(
          colors: [
            purple.withValues(alpha: 0.18),
            cyan.withValues(alpha: 0.07),
          ],
        ),

        border: Border.all(
          color:
              purple.withValues(alpha: 0.22),
        ),

        boxShadow: [
          BoxShadow(
            color:
                purple.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      purple.withValues(alpha: 0.18),
                ),

                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: cyan,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'FINPILOT AI INSIGHT',
                  style: TextStyle(
                    color: white,
                    fontSize: 12,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            _aiInsight,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OCR TEXT
  // ============================================================

  Widget _buildDetectedText() {
    if (_rawText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: card,

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color:
              Colors.white.withValues(alpha: 0.07),
        ),
      ),

      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
        ),

        iconColor: cyan,
        collapsedIconColor: secondaryText,

        title: const Text(
          'View detected bill text',
          style: TextStyle(
            color: white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),

        leading: const Icon(
          Icons.text_snippet_rounded,
          color: cyan,
        ),

        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16,
            ),

            child: Align(
              alignment: Alignment.centerLeft,

              child: Text(
                _rawText,
                style: const TextStyle(
                  color: secondaryText,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADD TO EXPENSES BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _saveExpense,

      child: Container(
        width: double.infinity,
        height: 58,

        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(18),

          gradient: const LinearGradient(
            colors: [
              purple,
              Color(0xFF745CFF),
              cyan,
            ],
          ),

          boxShadow: [
            BoxShadow(
              color:
                  purple.withValues(alpha: 0.28),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),

        child: const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.add_task_rounded,
              color: white,
              size: 21,
            ),

            SizedBox(width: 9),

            Text(
              'ADD TO EXPENSES',
              style: TextStyle(
                color: white,
                fontSize: 13,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SCAN ANOTHER BILL
  // ============================================================

  Widget _buildScanAgainButton() {
    return GestureDetector(
      onTap: _scanAgain,

      child: Container(
        width: double.infinity,
        height: 52,

        decoration: BoxDecoration(
          color:
              Colors.white.withValues(alpha: 0.04),

          borderRadius:
              BorderRadius.circular(17),

          border: Border.all(
            color:
                Colors.white.withValues(alpha: 0.08),
          ),
        ),

        child: const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.document_scanner_rounded,
              color: cyan,
              size: 19,
            ),

            SizedBox(width: 8),

            Text(
              'SCAN ANOTHER BILL',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}