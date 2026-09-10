import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../providers/finance_provider.dart';

class BankStatementScreen extends StatefulWidget {
  const BankStatementScreen({super.key});

  @override
  State<BankStatementScreen> createState() =>
      _BankStatementScreenState();
}

class _BankStatementScreenState
    extends State<BankStatementScreen> {
  static const Color background = Color(0xFF07111F);
  static const Color card = Color(0xFF101D30);
  static const Color card2 = Color(0xFF16263D);
  static const Color purple = Color(0xFF5B4BFF);
  static const Color cyan = Color(0xFF4CC9F0);
  static const Color green = Color(0xFF35D07F);
  static const Color red = Color(0xFFFF6B6B);

  bool _loading = false;
  String _fileName = '';
  List<BankStatementTransaction> _transactions = [];

  @override
  Widget build(BuildContext context) {
    final selected = _transactions
        .where((t) => t.selected)
        .toList();

    final income = selected
        .where(
          (t) => t.type == BankStatementType.income,
        )
        .fold<double>(
          0,
          (sum, t) => sum + t.amount,
        );

    final expenses = selected
        .where(
          (t) => t.type == BankStatementType.expense,
        )
        .fold<double>(
          0,
          (sum, t) => sum + t.amount,
        );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bank Statement Reader',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Import transactions automatically',
              style: TextStyle(
                color: Color(0xFF9AA9BC),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? _loadingView()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  30,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _hero(),
                    const SizedBox(height: 18),
                    _importSection(),
                    if (_transactions.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _summary(
                        income,
                        expenses,
                        selected.length,
                      ),
                      const SizedBox(height: 22),
                      _transactionHeader(),
                      const SizedBox(height: 12),
                      _transactionList(),
                      const SizedBox(height: 22),
                      _importButton(selected.length),
                    ],
                    const SizedBox(height: 20),
                    _info(),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor:
                  AlwaysStoppedAnimation<Color>(cyan),
            ),
          ),
          SizedBox(height: 22),
          Text(
            'Reading Statement...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'FinPilot AI is processing your file',
            style: TextStyle(
              color: Color(0xFF9AA9BC),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            purple.withValues(alpha: 0.28),
            cyan.withValues(alpha: 0.08),
            card,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(17),
                  gradient: const LinearGradient(
                    colors: [
                      purple,
                      cyan,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Statement Import',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Automatically detect income, expenses and categories.',
                      style: TextStyle(
                        color: Color(0xFF9AA9BC),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: cyan,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _fileName.isEmpty
                        ? 'Upload a CSV statement or test with demo data.'
                        : _fileName,
                    style: const TextStyle(
                      color: Color(0xFF9AA9BC),
                      fontSize: 11,
                    ),
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
  // IMPORT SECTION
  // ============================================================

  Widget _importSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'IMPORT STATEMENT',
          style: TextStyle(
            color: Color(0xFF9AA9BC),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                Icons.upload_file_rounded,
                'Upload CSV',
                'Bank statement',
                purple,
                _pickCsv,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                Icons.science_rounded,
                'Demo Data',
                'Test feature',
                cyan,
                _loadDemo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    color.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 23,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF9AA9BC),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILE PICKER
  // ============================================================

  Future<void> _pickCsv() async {
    try {
      final PlatformFile? file =
          await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (file == null) {
        return;
      }

      setState(() {
        _loading = true;
        _transactions = [];
        _fileName = file.name;
      });

      final bytes = await file.readAsBytes();

      final content = utf8.decode(
        bytes,
        allowMalformed: true,
      );

      final rows = _parseCsv(content);

      final parsed =
          <BankStatementTransaction>[];

      for (final row in rows) {
        if (row.isEmpty) {
          continue;
        }

        if (_isHeader(row.join(' '))) {
          continue;
        }

        final transaction = _parseRow(row);

        if (transaction != null) {
          parsed.add(transaction);
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _transactions = parsed;
        _loading = false;
      });

      if (parsed.isEmpty) {
        _showMessage(
          'No valid transactions found.',
        );
      } else {
        _showMessage(
          '${parsed.length} transactions detected.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Could not read CSV file.',
      );
    }
  }

  // ============================================================
  // SIMPLE CSV PARSER
  // ============================================================

  List<List<String>> _parseCsv(String text) {
    final result = <List<String>>[];

    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }

      result.add(_parseCsvLine(line));
    }

    return result;
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();

    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (insideQuotes &&
            i + 1 < line.length &&
            line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' &&
          !insideQuotes) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    values.add(buffer.toString().trim());

    return values;
  }

  // ============================================================
  // ROW PARSER
  // ============================================================

  BankStatementTransaction? _parseRow(
    List<String> values,
  ) {
    DateTime? date;
    int dateIndex = -1;

    for (int i = 0; i < values.length; i++) {
      final parsed = _parseDate(values[i]);

      if (parsed != null) {
        date = parsed;
        dateIndex = i;
        break;
      }
    }

    if (date == null) {
      return null;
    }

    double? amount;

    for (final value in values) {
      final parsed = _parseAmount(value);

      if (parsed != null && parsed > 0) {
        amount = parsed;
      }
    }

    if (amount == null || amount <= 0) {
      return null;
    }

    final descriptions = <String>[];

    for (int i = 0; i < values.length; i++) {
      if (i == dateIndex) {
        continue;
      }

      final value = values[i].trim();

      if (value.isEmpty) {
        continue;
      }

      if (_parseAmount(value) != null) {
        continue;
      }

      if (_isHeader(value)) {
        continue;
      }

      descriptions.add(value);
    }

    final description =
        descriptions.isEmpty
            ? 'Bank Transaction'
            : descriptions.join(' ');

    final completeText =
        values.join(' ');

    return BankStatementTransaction(
      id: const Uuid().v4(),
      title: description,
      amount: amount,
      date: date,
      category:
          _detectCategory(description),
      type:
          _detectType(completeText),
      merchant:
          _detectMerchant(description),
      paymentMethod:
          _detectPaymentMethod(completeText),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime? _parseDate(String value) {
    final text = value.trim();

    final match = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$',
    ).firstMatch(text);

    if (match == null) {
      return null;
    }

    final day =
        int.tryParse(match.group(1)!) ?? 0;

    final month =
        int.tryParse(match.group(2)!) ?? 0;

    var year =
        int.tryParse(match.group(3)!) ?? 0;

    if (year < 100) {
      year += 2000;
    }

    if (day <= 0 ||
        month <= 0 ||
        year <= 0) {
      return null;
    }

    try {
      final date =
          DateTime(year, month, day);

      if (date.year != year ||
          date.month != month ||
          date.day != day) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // AMOUNT
  // ============================================================

  double? _parseAmount(String value) {
    var text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    text = text
        .replaceAll('₹', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .replaceAll('INR', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(text);
  }

  // ============================================================
  // TYPE
  // ============================================================

  BankStatementType _detectType(
    String text,
  ) {
    final value =
        text.toLowerCase();

    const incomeWords = [
      'salary',
      'credit',
      'credited',
      'deposit',
      'freelance',
      'bonus',
      'scholarship',
      'refund',
      'dividend',
      'received',
      'neft cr',
      'imps cr',
      'upi cr',
    ];

    for (final word in incomeWords) {
      if (value.contains(word)) {
        return BankStatementType.income;
      }
    }

    return BankStatementType.expense;
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  String _detectCategory(
    String text,
  ) {
    final value =
        text.toLowerCase();

    if (_containsAny(value, [
      'swiggy',
      'zomato',
      'restaurant',
      'food',
      'dominos',
      'pizza',
      'mcdonald',
      'starbucks',
      'blinkit',
      'zepto',
      'bigbasket',
      'grocery',
      'groceries',
    ])) {
      return 'Food';
    }

    if (_containsAny(value, [
      'uber',
      'ola',
      'rapido',
      'metro',
      'bus',
      'fuel',
      'petrol',
      'diesel',
      'parking',
      'transport',
    ])) {
      return 'Transport';
    }

    if (_containsAny(value, [
      'amazon',
      'flipkart',
      'myntra',
      'zara',
      'shopping',
      'clothing',
      'mall',
      'retail',
    ])) {
      return 'Shopping';
    }

    if (_containsAny(value, [
      'electricity',
      'water bill',
      'gas bill',
      'internet',
      'wifi',
      'mobile bill',
      'recharge',
      'insurance',
      'bill',
    ])) {
      return 'Bills';
    }

    if (_containsAny(value, [
      'netflix',
      'spotify',
      'prime video',
      'hotstar',
      'movie',
      'cinema',
      'entertainment',
      'youtube premium',
    ])) {
      return 'Entertainment';
    }

    if (_containsAny(value, [
      'hospital',
      'pharmacy',
      'medicine',
      'medical',
      'doctor',
      'clinic',
      'health',
    ])) {
      return 'Health';
    }

    if (_containsAny(value, [
      'college',
      'school',
      'education',
      'course',
      'udemy',
      'coursera',
      'books',
      'exam',
    ])) {
      return 'Education';
    }

    if (_containsAny(value, [
      'salary',
      'freelance',
      'business',
      'investment',
      'bonus',
      'scholarship',
      'dividend',
      'interest',
    ])) {
      return 'Income';
    }

    return 'Other';
  }

  // ============================================================
  // MERCHANT
  // ============================================================

  String _detectMerchant(
    String text,
  ) {
    final value =
        text.toLowerCase();

    const merchants = {
      'swiggy': 'Swiggy',
      'zomato': 'Zomato',
      'amazon': 'Amazon',
      'flipkart': 'Flipkart',
      'uber': 'Uber',
      'ola': 'Ola',
      'rapido': 'Rapido',
      'blinkit': 'Blinkit',
      'zepto': 'Zepto',
      'myntra': 'Myntra',
      'netflix': 'Netflix',
      'spotify': 'Spotify',
      'zara': 'Zara',
      'dominos': 'Dominos',
      'starbucks': 'Starbucks',
      'mcdonald': "McDonald's",
      'dmart': 'DMart',
      'reliance': 'Reliance',
    };

    for (final entry
        in merchants.entries) {
      if (value.contains(entry.key)) {
        return entry.value;
      }
    }

    return '';
  }

  // ============================================================
  // PAYMENT METHOD
  // ============================================================

  String _detectPaymentMethod(
    String text,
  ) {
    final value =
        text.toLowerCase();

    if (value.contains('upi')) {
      return 'UPI';
    }

    if (value.contains('credit')) {
      return 'Credit Card';
    }

    if (value.contains('debit')) {
      return 'Debit Card';
    }

    if (value.contains('cash')) {
      return 'Cash';
    }

    return 'Bank';
  }

  // ============================================================
  // HEADER DETECTION
  // ============================================================

  bool _isHeader(String value) {
    final text =
        value.toLowerCase();

    const words = [
      'date',
      'description',
      'narration',
      'amount',
      'debit',
      'credit',
      'balance',
      'transaction',
      'particulars',
      'remarks',
    ];

    int matches = 0;

    for (final word in words) {
      if (text.contains(word)) {
        matches++;
      }
    }

    return matches >= 2;
  }

  // ============================================================
  // CONTAINS ANY
  // ============================================================

  bool _containsAny(
    String value,
    List<String> words,
  ) {
    for (final word in words) {
      if (value.contains(word)) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // DEMO DATA
  // ============================================================

  void _loadDemo() {
    final now = DateTime.now();

    setState(() {
      _fileName = 'FinPilot Demo Statement';

      _transactions = [
        _demo(
          'Monthly Salary',
          65000,
          1,
          'Income',
          BankStatementType.income,
          '',
          'Bank',
          now,
        ),
        _demo(
          'UPI-SWIGGY',
          450,
          2,
          'Food',
          BankStatementType.expense,
          'Swiggy',
          'UPI',
          now,
        ),
        _demo(
          'UPI-UBER',
          280,
          3,
          'Transport',
          BankStatementType.expense,
          'Uber',
          'UPI',
          now,
        ),
        _demo(
          'NETFLIX SUBSCRIPTION',
          649,
          5,
          'Entertainment',
          BankStatementType.expense,
          'Netflix',
          'Credit Card',
          now,
        ),
        _demo(
          'AMAZON INDIA',
          2200,
          7,
          'Shopping',
          BankStatementType.expense,
          'Amazon',
          'Credit Card',
          now,
        ),
        _demo(
          'ELECTRICITY BILL',
          1500,
          10,
          'Bills',
          BankStatementType.expense,
          'Electricity Board',
          'Bank',
          now,
        ),
        _demo(
          'UPI-ZEPTO',
          1250,
          12,
          'Food',
          BankStatementType.expense,
          'Zepto',
          'UPI',
          now,
        ),
        _demo(
          'FREELANCE PROJECT',
          12000,
          15,
          'Income',
          BankStatementType.income,
          '',
          'Bank',
          now,
        ),
        _demo(
          'ZARA INDIA',
          4000,
          18,
          'Shopping',
          BankStatementType.expense,
          'Zara',
          'Debit Card',
          now,
        ),
      ];
    });

    _showMessage(
      'Demo statement loaded.',
    );
  }

  BankStatementTransaction _demo(
    String title,
    double amount,
    int day,
    String category,
    BankStatementType type,
    String merchant,
    String payment,
    DateTime now,
  ) {
    return BankStatementTransaction(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      date: DateTime(
        now.year,
        now.month,
        day,
      ),
      category: category,
      type: type,
      merchant: merchant,
      paymentMethod: payment,
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _summary(
    double income,
    double expenses,
    int selected,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'STATEMENT SUMMARY',
          style: TextStyle(
            color: Color(0xFF9AA9BC),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Income',
                '₹${_money(income)}',
                Icons.arrow_downward_rounded,
                green,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _summaryCard(
                'Expenses',
                '₹${_money(expenses)}',
                Icons.arrow_upward_rounded,
                red,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _summaryCard(
                'Selected',
                '$selected',
                Icons.check_circle_rounded,
                cyan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9AA9BC),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRANSACTION HEADER
  // ============================================================

  Widget _transactionHeader() {
    final allSelected =
        _transactions.isNotEmpty &&
        _transactions.every(
          (t) => t.selected,
        );

    return Row(
      children: [
        const Expanded(
          child: Text(
            'DETECTED TRANSACTIONS',
            style: TextStyle(
              color: Color(0xFF9AA9BC),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              for (final transaction
                  in _transactions) {
                transaction.selected =
                    !allSelected;
              }
            });
          },
          child: Text(
            allSelected
                ? 'Deselect All'
                : 'Select All',
            style: const TextStyle(
              color: cyan,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TRANSACTION LIST
  // ============================================================

  Widget _transactionList() {
    return Column(
      children: [
        for (final transaction
            in _transactions)
          Padding(
            padding:
                const EdgeInsets.only(
              bottom: 10,
            ),
            child:
                _transactionCard(
              transaction,
            ),
          ),
      ],
    );
  }

  Widget _transactionCard(
    BankStatementTransaction transaction,
  ) {
    final isIncome =
        transaction.type ==
            BankStatementType.income;

    final color =
        isIncome ? green : red;

    return GestureDetector(
      onTap: () {
        setState(() {
          transaction.selected =
              !transaction.selected;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: transaction.selected
              ? card
              : card.withValues(alpha: 0.45),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: transaction.selected
                ? color.withValues(alpha: 0.20)
                : Colors.white.withValues(
                    alpha: 0.05,
                  ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    color.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Icon(
                isIncome
                    ? Icons
                        .arrow_downward_rounded
                    : Icons
                        .arrow_upward_rounded,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${transaction.category} • ${_date(transaction.date)}',
                    style: const TextStyle(
                      color: Color(0xFF9AA9BC),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}₹${_money(transaction.amount)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: transaction.selected
                        ? cyan
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: transaction.selected
                          ? cyan
                          : const Color(
                              0xFF536278,
                            ),
                    ),
                  ),
                  child: transaction.selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 13,
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // IMPORT BUTTON
  // ============================================================

  Widget _importButton(int count) {
    return GestureDetector(
      onTap:
          count > 0 ? _importTransactions : null,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          vertical: 17,
        ),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(18),
          gradient: count > 0
              ? const LinearGradient(
                  colors: [
                    purple,
                    cyan,
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.grey,
                    Colors.grey,
                  ],
                ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.download_done_rounded,
              color: Colors.white,
              size: 21,
            ),
            const SizedBox(width: 8),
            Text(
              count > 0
                  ? 'IMPORT $count TRANSACTIONS'
                  : 'SELECT TRANSACTIONS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // IMPORT TO FINPILOT
  // ============================================================

  Future<void> _importTransactions() async {
    final selected =
        _transactions
            .where(
              (t) => t.selected,
            )
            .toList();

    if (selected.isEmpty) {
      _showMessage(
        'Select at least one transaction.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final finance =
          context.read<FinanceProvider>();

      for (final transaction
          in selected) {
        final item =
            FinanceTransaction(
          id: const Uuid().v4(),
          title: transaction.title,
          amount: transaction.amount,
          category: transaction.category,
          type: transaction.type ==
                  BankStatementType.income
              ? TransactionType.income
              : TransactionType.expense,
          date: transaction.date,
          paymentMethod:
              transaction.paymentMethod,
          note:
              'Imported from bank statement',
          merchant:
              transaction.merchant,
          isRecurring: false,
          createdAt: DateTime.now(),
        );

        await finance.addTransaction(item);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _transactions = [];
        _fileName = '';
      });

      _showMessage(
        '${selected.length} transactions imported successfully.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Import failed: $e',
      );
    }
  }

  // ============================================================
  // INFO
  // ============================================================

  Widget _info() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card.withValues(alpha: 0.65),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: cyan,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'HOW IT WORKS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '1. Upload a CSV bank statement.',
            style: TextStyle(
              color: Color(0xFF9AA9BC),
              fontSize: 11,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '2. FinPilot detects dates, amounts and descriptions.',
            style: TextStyle(
              color: Color(0xFF9AA9BC),
              fontSize: 11,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '3. Transactions are automatically categorized.',
            style: TextStyle(
              color: Color(0xFF9AA9BC),
              fontSize: 11,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '4. Select and import them into FinPilot.',
            style: TextStyle(
              color: Color(0xFF9AA9BC),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _money(double value) {
    if (value == value.roundToDouble()) {
      return value
          .toInt()
          .toString()
          .replaceAllMapped(
            RegExp(
              r'(\d)(?=(\d{3})+(?!\d))',
            ),
            (match) =>
                '${match[1]},',
          );
    }

    return value.toStringAsFixed(2);
  }

  String _date(DateTime date) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        backgroundColor: card2,
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ================================================================
// ENUM
// ================================================================

enum BankStatementType {
  income,
  expense,
}

// ================================================================
// BANK TRANSACTION MODEL
// ================================================================

class BankStatementTransaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final BankStatementType type;
  final String merchant;
  final String paymentMethod;

  bool selected;

  BankStatementTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
    required this.merchant,
    required this.paymentMethod,
    this.selected = true,
  });
}