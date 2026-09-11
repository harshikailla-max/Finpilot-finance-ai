import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../providers/finance_provider.dart';
import '../services/receipt_suggestion_service.dart';
import '../utils/currency_formatter.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  // Theme palette
  static const Color bgDark = Color(0xFF081120);
  static const Color cardDark = Color(0xFF10192B);
  static const Color cardLight = Color(0xFF152238);
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color cyanAccent = Color(0xFF4CC9F0);
  static const Color successGreen = Color(0xFF2DD4A8);
  static const Color warningOrange = Color(0xFFFFB86B);
  static const Color textMuted = Color(0xFF9AA4B2);

  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  // Image state - bytes only for complete cross-platform safety
  Uint8List? _receiptBytes;
  String? _receiptFileName;

  // Controllers
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Form State
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food & Dining';
  String _selectedPaymentMethod = 'UPI';

  bool _isSaving = false;
  bool _showSavedResult = false;
  ReceiptInsight? _lastInsight;
  FinanceTransaction? _savedTransaction;

  @override
  void initState() {
    super.initState();
    _merchantController.addListener(_onMerchantChanged);
  }

  @override
  void dispose() {
    _merchantController.removeListener(_onMerchantChanged);
    _merchantController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onMerchantChanged() {
    final text = _merchantController.text;
    if (text.trim().isEmpty) return;

    final suggestedCat = ReceiptSuggestionService.suggestCategory(text);
    final suggestedPay = ReceiptSuggestionService.suggestPaymentMethod(text);

    if (suggestedCat != 'Other' && suggestedCat != _selectedCategory) {
      setState(() {
        _selectedCategory = suggestedCat;
      });
    }
    if (suggestedPay != _selectedPaymentMethod) {
      setState(() {
        _selectedPaymentMethod = suggestedPay;
      });
    }
  }

  // Pick Image from Gallery or Web File Dialog
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _receiptBytes = bytes;
        _receiptFileName = file.name;
        _showSavedResult = false;
      });
    } catch (e) {
      _showSnackbar('Unable to select image. Please try again.');
    }
  }

  void _removeImage() {
    setState(() {
      _receiptBytes = null;
      _receiptFileName = null;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: primaryPurple,
              onPrimary: Colors.white,
              surface: cardDark,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: bgDark),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _confirmAndAddExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      _showSnackbar('Please enter a valid amount greater than 0.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final finance = Provider.of<FinanceProvider>(context, listen: false);
      final merchant = _merchantController.text.trim();
      final notes = _notesController.text.trim();

      final newTransaction = FinanceTransaction(
        id: const Uuid().v4(),
        title: merchant.isNotEmpty ? merchant : 'Receipt Expense',
        amount: amount,
        category: _selectedCategory,
        type: TransactionType.expense,
        date: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        merchant: merchant,
        note: notes.isNotEmpty ? notes : 'Smart receipt scan',
        source: 'Receipt',
        createdAt: DateTime.now(),
      );

      // Generate AI-style financial insight using real financial records
      final insight = ReceiptSuggestionService.generateInsight(
        amount: amount,
        category: _selectedCategory,
        merchant: merchant,
        finance: finance,
      );

      // Save directly to FinanceProvider
      await finance.addTransaction(newTransaction);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _showSavedResult = true;
        _lastInsight = insight;
        _savedTransaction = newTransaction;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showSnackbar('Failed to record expense: $e');
    }
  }

  void _resetForNewReceipt() {
    setState(() {
      _receiptBytes = null;
      _receiptFileName = null;
      _showSavedResult = false;
      _lastInsight = null;
      _savedTransaction = null;
      _merchantController.clear();
      _amountController.clear();
      _notesController.clear();
      _selectedDate = DateTime.now();
      _selectedCategory = 'Food & Dining';
      _selectedPaymentMethod = 'UPI';
    });
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: cardLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Receipt',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              'Turn any receipt into a tracked expense.',
              style: TextStyle(color: textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _showSavedResult && _lastInsight != null && _savedTransaction != null
              ? _buildSavedResultView(_lastInsight!, _savedTransaction!)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagePickerSection(),
                    const SizedBox(height: 24),
                    _buildFormSection(finance),
                  ],
                ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE PICKER & PREVIEW SECTION
  // ============================================================
  Widget _buildImagePickerSection() {
    if (_receiptBytes == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryPurple.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: primaryPurple.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primaryPurple.withValues(alpha: 0.35),
                    cyanAccent.withValues(alpha: 0.2),
                  ],
                ),
                border: Border.all(color: primaryPurple.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: cyanAccent, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Capture your spending',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a receipt and we\'ll help you turn it into a clean expense record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPickerButton(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload Receipt',
                  isPrimary: true,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                if (!kIsWeb &&
                    (defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.iOS)) ...[
                  const SizedBox(width: 12),
                  _buildPickerButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    isPrimary: false,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    // Receipt Image Preview
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cyanAccent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cyanAccent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: successGreen.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: successGreen, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Ready to record',
                        style: TextStyle(color: successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (_receiptFileName != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _receiptFileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.refresh_rounded, color: cyanAccent, size: 16),
                  label: const Text('Replace', style: TextStyle(color: cyanAccent, fontSize: 12)),
                ),
                IconButton(
                  onPressed: _removeImage,
                  icon: const Icon(Icons.close_rounded, color: textMuted, size: 18),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: Container(
              height: 220,
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.4),
              child: Image.memory(
                _receiptBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isPrimary
              ? const LinearGradient(colors: [primaryPurple, cyanAccent])
              : null,
          color: isPrimary ? null : cardLight,
          border: isPrimary ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: primaryPurple.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORM SECTION
  // ============================================================
  Widget _buildFormSection(FinanceProvider finance) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: cyanAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Expense Details',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Merchant
            _buildFieldLabel('Merchant / Store', isRequired: true),
            TextFormField(
              controller: _merchantController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'e.g. Starbucks, Swiggy, Amazon',
                prefixIcon: Icons.storefront_rounded,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter the merchant name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Amount
            _buildFieldLabel('Amount', isRequired: true),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: _inputDecoration(
                hintText: '0.00',
                prefixIcon: Icons.currency_rupee_rounded,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter the expense amount';
                }
                final parsed = double.tryParse(val.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category Selector
            _buildFieldLabel('Category', isRequired: true),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: cardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: cardLight,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: cyanAccent),
                  items: ReceiptSuggestionService.categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(_getCategoryIcon(cat), color: cyanAccent, size: 18),
                          const SizedBox(width: 10),
                          Text(cat, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date & Payment Method Row
            Row(
              children: [
                // Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Date', isRequired: true),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                          decoration: BoxDecoration(
                            color: cardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: cyanAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(_selectedDate),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Payment Method
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Payment Method'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: cardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPaymentMethod,
                            isExpanded: true,
                            dropdownColor: cardLight,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: cyanAccent),
                            items: ReceiptSuggestionService.paymentMethods.map((pay) {
                              return DropdownMenuItem<String>(
                                value: pay,
                                child: Text(pay, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedPaymentMethod = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            _buildFieldLabel('Notes (Optional)'),
            TextFormField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'Add context or item details...',
                prefixIcon: Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 26),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _confirmAndAddExpense,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 6,
                  shadowColor: primaryPurple.withValues(alpha: 0.5),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [primaryPurple, cyanAccent]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Confirm & Add Expense',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
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
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SAVED RESULT & AI INSIGHT CARD
  // ============================================================
  Widget _buildSavedResultView(ReceiptInsight insight, FinanceTransaction tx) {
    return Column(
      children: [
        // Success Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: successGreen.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: successGreen.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: successGreen.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: successGreen, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'RECEIPT ANALYZED \u2713',
                      style: TextStyle(color: successGreen, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                CurrencyFormatter.format(tx.amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tx.merchant.isNotEmpty ? tx.merchant : tx.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: cardLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getCategoryIcon(tx.category), color: cyanAccent, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      tx.category,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Text(' \u2022 ', style: TextStyle(color: textMuted)),
                    Text(
                      tx.paymentMethod,
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 14),

              // Budget Impact bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Budget Impact', style: TextStyle(color: textMuted, fontSize: 12)),
                  Text(
                    '${CurrencyFormatter.format(tx.amount)} / ${CurrencyFormatter.format(insight.budgetImpact.monthlyTarget)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (insight.budgetImpact.percentageOfTarget / 100).clamp(0.0, 1.0),
                  backgroundColor: cardLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    insight.budgetImpact.isExceeding ? warningOrange : cyanAccent,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // AI Insight Card
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
              colors: [
                primaryPurple.withValues(alpha: 0.15),
                cardDark,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: primaryPurple, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'AI INSIGHT',
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
                '"${insight.headline}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MONTHLY ${insight.categoryName.toUpperCase()}',
                            style: const TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(insight.monthlyCategorySpend),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TREND',
                            style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insight.trendPercentage >= 0
                                ? '+${insight.trendPercentage.toStringAsFixed(0)}% vs last mo'
                                : '${insight.trendPercentage.toStringAsFixed(0)}% vs last mo',
                            style: TextStyle(
                              color: insight.trendPercentage > 15 ? warningOrange : successGreen,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cyanAccent.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECOMMENDATION',
                      style: TextStyle(color: cyanAccent, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"${insight.recommendation}"',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetForNewReceipt,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Record Another', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================
  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          if (isRequired)
            const Text(' *', style: TextStyle(color: warningOrange, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: cyanAccent, size: 20),
      filled: true,
      fillColor: cardLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: cyanAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: warningOrange, width: 1.5),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant_rounded;
      case 'Groceries':
        return Icons.local_grocery_store_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Bills':
        return Icons.receipt_rounded;
      case 'Entertainment':
        return Icons.movie_rounded;
      case 'Health':
        return Icons.medical_services_rounded;
      case 'Education':
        return Icons.school_rounded;
      case 'Travel':
        return Icons.flight_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}