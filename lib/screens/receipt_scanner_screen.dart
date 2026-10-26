import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../models/receipt_model.dart';
import '../providers/finance_provider.dart';
import '../services/image_optimization_service.dart';
import '../services/receipt_ocr_service.dart';
import '../services/receipt_qr_service.dart';
import '../services/receipt_suggestion_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/aura/aura_background.dart';
import '../widgets/aura/aura_glass_card.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late final ReceiptOcrService _ocrService;
  late final AnimationController _scannerAnimController;

  // Scanner state
  ReceiptScanStatus _scanStatus = ReceiptScanStatus.idle;
  String _statusMessage = '';
  double _ocrProgress = 0.0;
  String? _scanErrorMessage;
  OcrErrorType _ocrErrorType = OcrErrorType.none;
  int? _ocrStatusCode;

  // File & Image state
  Uint8List? _receiptBytes;
  Uint8List? _originalBytes;
  String? _receiptFileName;
  ReceiptQrPayload? _detectedQrPayload;
  bool _isTotalUncertain = false;
  String? _rawOcrText;

  // Form Controllers
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _subtotalController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Form State
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food & Dining';
  String _selectedPaymentMethod = 'UPI';
  List<ReceiptLineItem> _lineItems = [];

  // Saving state
  bool _isSaving = false;
  bool _showSavedResult = false;
  ReceiptInsight? _lastInsight;
  FinanceTransaction? _savedTransaction;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _ocrService = ReceiptOcrService(storageService: storage);

    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _merchantController.addListener(_onMerchantChanged);
  }

  @override
  void dispose() {
    _merchantController.removeListener(_onMerchantChanged);
    _merchantController.dispose();
    _amountController.dispose();
    _subtotalController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    _scannerAnimController.dispose();
    super.dispose();
  }

  void _onMerchantChanged() {
    final text = _merchantController.text.trim();
    if (text.isEmpty) return;

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

  // ============================================================
  // IMAGE & DOCUMENT PICKING
  // ============================================================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 92,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      _originalBytes = bytes;
      await _processFileBytes(bytes, file.name);
    } catch (e) {
      _showSnackbar('Unable to capture or select image: $e');
    }
  }

  Future<void> _pickDocumentFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      _originalBytes = bytes;
      await _processFileBytes(bytes, file.name);
    } catch (e) {
      _showSnackbar('Unable to open file: $e');
    }
  }

  // ============================================================
  // OCR & RECEIPT PARSING PIPELINE
  // ============================================================
  Future<void> _processFileBytes(Uint8List bytes, String fileName) async {
    // 1. Immediately resize/optimize large images to eliminate HTTP 413 and memory lag
    final optimized = ImageOptimizationService.optimizeForOcr(bytes);
    final displayBytes = optimized.bytes;

    setState(() {
      _receiptBytes = displayBytes;
      _receiptFileName = fileName;
      _scanStatus = ReceiptScanStatus.recognizingText;
      _statusMessage = 'Optimizing image for browser OCR...';
      _ocrProgress = 0.05;
      _scanErrorMessage = null;
      _showSavedResult = false;
      _detectedQrPayload = null;
      _isTotalUncertain = false;
      _rawOcrText = null;
    });

    _scannerAnimController.repeat(reverse: true);

    try {
      final result = await _ocrService.processReceiptBytes(
        bytes: displayBytes,
        fileName: fileName,
        onProgress: (status, progress) {
          if (!mounted) return;
          setState(() {
            _ocrProgress = progress.clamp(0.0, 1.0);
            final pct = (_ocrProgress * 100).toInt();
            String label = status;
            if (status.contains('tesseract') || status.contains('worker')) {
              label = 'Initializing OCR engine';
            } else if (status.contains('recogniz')) {
              label = 'Recognizing text';
            } else if (status.contains('optimiz') || status.contains('prepar')) {
              label = 'Optimizing image';
            } else if (status.contains('complete')) {
              label = 'Extracting details';
            }
            _statusMessage = '$label ($pct%)';
          });
        },
      );

      if (!mounted) return;
      _scannerAnimController.stop();

      if (result.isSuccess && result.data != null) {
        final data = result.data!;
        _detectedQrPayload = result.qrPayload;
        _isTotalUncertain = data.isTotalUncertain;
        _rawOcrText = result.rawText;
        _ocrErrorType = OcrErrorType.none;
        _ocrStatusCode = null;
        _populateFieldsFromReceipt(data);

        setState(() {
          _scanStatus = ReceiptScanStatus.success;
        });
      } else {
        setState(() {
          _scanStatus = ReceiptScanStatus.emptyOrError;
          _scanErrorMessage = result.errorMessage ??
              'No readable text could be detected from this receipt. Ensure the receipt is well-lit and legible, or enter details in the editable preview below.';
          _ocrErrorType = result.errorType;
          _ocrStatusCode = result.httpStatusCode;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _scannerAnimController.stop();
      setState(() {
        _scanStatus = ReceiptScanStatus.emptyOrError;
        _scanErrorMessage = 'Scanning failed: $e';
        _ocrErrorType = OcrErrorType.networkError;
      });
    }
  }

  void _populateFieldsFromReceipt(ReceiptData data) {
    // Never invent missing values. Only populate if detected.
    _merchantController.text = data.merchant;
    _amountController.text =
        data.total > 0 ? data.total.toStringAsFixed(2) : '';
    if (data.subtotal != null && data.subtotal! > 0) {
      _subtotalController.text = data.subtotal!.toStringAsFixed(2);
    } else {
      _subtotalController.clear();
    }
    if (data.tax != null && data.tax! > 0) {
      _taxController.text = data.tax!.toStringAsFixed(2);
    } else {
      _taxController.clear();
    }
    _selectedDate = data.date;
    _selectedCategory = data.category;
    _selectedPaymentMethod = data.paymentMethod;
    _lineItems = List.from(data.lineItems);

    if (_lineItems.isNotEmpty) {
      final summary =
          _lineItems.map((e) => '${e.quantity}x ${e.name}').join(', ');
      _notesController.text = summary.length > 80
          ? '${summary.substring(0, 77)}...'
          : summary;
    } else {
      _notesController.clear();
    }
  }

  // ============================================================
  // IMAGE READABILITY & TRANSFORMATION ACTIONS
  // ============================================================
  void _rotateImageClockwise() {
    if (_receiptBytes == null) return;
    final rotated = ReceiptQrService.rotateClockwise(_receiptBytes!);
    setState(() {
      _receiptBytes = rotated;
    });
    _showSnackbar('Image rotated 90°. Tap "Re-analyze" to re-run OCR.');
  }

  void _enhanceImageReadability() {
    if (_receiptBytes == null) return;
    final enhanced = ReceiptQrService.enhanceReadability(_receiptBytes!);
    setState(() {
      _receiptBytes = enhanced;
    });
    _showSnackbar('Contrast enhanced. Tap "Re-analyze" to re-run OCR.');
  }

  void _grayscaleImage() {
    if (_receiptBytes == null) return;
    final gray = ReceiptQrService.convertToGrayscale(_receiptBytes!);
    setState(() {
      _receiptBytes = gray;
    });
    _showSnackbar('Grayscale applied. Tap "Re-analyze" to re-run OCR.');
  }

  void _resetImage() {
    if (_originalBytes == null) return;
    setState(() {
      _receiptBytes = _originalBytes;
    });
    _showSnackbar('Image restored to original.');
  }

  void _reAnalyzeImage() {
    if (_receiptBytes == null || _receiptFileName == null) return;
    _processFileBytes(_receiptBytes!, _receiptFileName!);
  }

  void _proceedWithManualEntry() {
    setState(() {
      _scanStatus = ReceiptScanStatus.success;
      _scanErrorMessage = null;
    });
  }

  void _resetForNewReceipt() {
    setState(() {
      _receiptBytes = null;
      _originalBytes = null;
      _receiptFileName = null;
      _detectedQrPayload = null;
      _isTotalUncertain = false;
      _rawOcrText = null;
      _scanStatus = ReceiptScanStatus.idle;
      _statusMessage = '';
      _scanErrorMessage = null;
      _ocrErrorType = OcrErrorType.none;
      _ocrStatusCode = null;
      _showSavedResult = false;
      _lastInsight = null;
      _savedTransaction = null;
      _merchantController.clear();
      _amountController.clear();
      _subtotalController.clear();
      _taxController.clear();
      _notesController.clear();
      _selectedDate = DateTime.now();
      _selectedCategory = 'Food & Dining';
      _selectedPaymentMethod = 'UPI';
      _lineItems.clear();
    });
  }

  // ============================================================
  // DATE PICKER
  // ============================================================
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
              primary: AppColors.auroraViolet,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.secondaryBackground,
            ),
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

  // ============================================================
  // EXPENSE CONFIRMATION & SAVE
  // ============================================================
  Future<void> _confirmAndAddExpense() async {
    if (_isSaving || _showSavedResult) return; // Strict idempotency: prevent double submissions

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

      // Single authoritative save to FinanceProvider (atomic with rollback safety)
      final saved = await finance.addTransaction(newTransaction);
      if (!saved) {
        _showSnackbar('Transaction appears to be a duplicate and was ignored.');
        setState(() => _isSaving = false);
        return;
      }

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

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: AppColors.secondaryBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showFullReceiptModal() {
    if (_receiptBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 650),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.memory(_receiptBytes!, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRawOcrDialog() {
    if (_rawOcrText == null || _rawOcrText!.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        title: const Row(
          children: [
            Icon(Icons.text_snippet_rounded, color: AppColors.auroraCyan),
            SizedBox(width: 8),
            Text(
              'Raw OCR Diagnostics',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            _rawOcrText!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _rawOcrText!));
              Navigator.pop(ctx);
              _showSnackbar('Raw OCR text copied to clipboard.');
            },
            child: const Text('Copy Text',
                style: TextStyle(color: AppColors.auroraCyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: _showSavedResult &&
                          _lastInsight != null &&
                          _savedTransaction != null
                      ? _buildSavedResultView(_lastInsight!, _savedTransaction!)
                      : _buildActiveView(finance),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receipt Scanner',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Plan. Track. Grow. with intelligent OCR & QR',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          if (_rawOcrText != null && _rawOcrText!.isNotEmpty)
            IconButton(
              onPressed: _showRawOcrDialog,
              icon: const Icon(
                Icons.text_snippet_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              tooltip: 'Inspect Raw OCR Text',
            ),
          if (_receiptBytes != null && !_showSavedResult)
            IconButton(
              onPressed: _resetForNewReceipt,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.auroraCyan,
                size: 20,
              ),
              tooltip: 'Scan New Receipt',
            ),
        ],
      ),
    );
  }

  Widget _buildActiveView(FinanceProvider finance) {
    if (_scanStatus == ReceiptScanStatus.recognizingText) {
      return _buildScanningProgressView();
    }

    if (_scanStatus == ReceiptScanStatus.emptyOrError) {
      return _buildErrorStateView();
    }

    if (_receiptBytes == null || _scanStatus == ReceiptScanStatus.idle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScanHeroCard(),
          const SizedBox(height: 20),
          _buildScanningTipsCard(),
        ],
      );
    }

    // Editable review & confirm view
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReceiptPreviewBanner(),
        const SizedBox(height: 12),
        _buildImageEnhanceToolbar(),
        const SizedBox(height: 16),
        if (_detectedQrPayload != null && _detectedQrPayload!.isFound) ...[
          _buildQrPayloadCard(_detectedQrPayload!),
          const SizedBox(height: 16),
        ],
        if (_isTotalUncertain) ...[
          _buildUncertainTotalWarning(),
          const SizedBox(height: 16),
        ],
        _buildDetectedTotalHeroCard(),
        const SizedBox(height: 20),
        _buildFormSection(finance),
        const SizedBox(height: 20),
        if (_lineItems.isNotEmpty) ...[
          _buildLineItemsSection(),
          const SizedBox(height: 24),
        ],
        _buildActionButtons(),
        const SizedBox(height: 30),
      ],
    );
  }

  // ============================================================
  // SCAN HERO CARD (INITIAL STATE)
  // ============================================================
  Widget _buildScanHeroCard() {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return AuraGlassCard(
      level: AuraGlassLevel.level3,
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.auroraViolet.withValues(alpha: 0.45),
                  AppColors.auroraCyan.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: AppColors.auroraCyan.withValues(alpha: 0.35),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.receipt_long_rounded,
                color: AppColors.auroraCyan,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Capture & Scan Receipt',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload any paper receipt, UPI QR invoice, or store screenshot. FinPilot will read merchant, date, taxes, QR codes, and items.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isMobile) ...[
                _buildActionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  isPrimary: true,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 12),
              ],
              _buildActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                isPrimary: !isMobile,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.file_present_rounded,
                label: 'PDF / File',
                isPrimary: false,
                onTap: _pickDocumentFile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanningTipsCard() {
    final tips = [
      {
        'icon': Icons.light_mode_outlined,
        'title': 'Good Lighting & Focus',
        'desc': 'Keep receipt flat and avoid shadows over totals.',
      },
      {
        'icon': Icons.qr_code_scanner_rounded,
        'title': 'QR & Barcode Scanning',
        'desc': 'UPI QR codes & GST e-Invoices are decoded automatically.',
      },
      {
        'icon': Icons.picture_as_pdf_outlined,
        'title': 'Digital PDF Invoices',
        'desc': 'Supports direct e-bills from Swiggy, Amazon, Uber, Zomato.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BEST PRACTICES FOR OCR & QR SCANNING',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        ...tips.map(
          (t) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Icon(
                  t['icon'] as IconData,
                  color: AppColors.auroraCyan,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['title'] as String,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t['desc'] as String,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SCANNING IN PROGRESS ANIMATED VIEW
  // ============================================================
  Widget _buildScanningProgressView() {
    return AuraGlassCard(
      level: AuraGlassLevel.level4,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 260,
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.6),
                  child: _receiptBytes != null
                      ? Opacity(
                          opacity: 0.6,
                          child: Image.memory(
                            _receiptBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : null,
                ),
              ),
              AnimatedBuilder(
                animation: _scannerAnimController,
                builder: (context, _) {
                  return Positioned(
                    top: 260 * _scannerAnimController.value,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.auroraCyan,
                            AppColors.auroraViolet,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.auroraCyan.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              color: AppColors.auroraCyan,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Analyzing Receipt & QR Data',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusMessage,
            style: const TextStyle(color: AppColors.auroraCyan, fontSize: 12.5),
          ),
          if (_ocrProgress > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  value: _ocrProgress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.auroraCyan),
                  minHeight: 5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY / ERROR STATE VIEW
  // ============================================================
  Widget _buildErrorStateView() {
    IconData errorIcon;
    Color iconColor;
    String errorTitle;

    switch (_ocrErrorType) {
      case OcrErrorType.payloadTooLarge:
        errorIcon = Icons.photo_size_select_large_rounded;
        iconColor = AppColors.warningOrange;
        errorTitle = 'Image Payload Too Large (HTTP 413)';
        break;
      case OcrErrorType.unauthorized:
      case OcrErrorType.forbidden:
        errorIcon = Icons.lock_outline_rounded;
        iconColor = AppColors.auroraViolet;
        errorTitle = 'OCR Authentication Required';
        break;
      case OcrErrorType.rateLimited:
        errorIcon = Icons.speed_rounded;
        iconColor = AppColors.warningOrange;
        errorTitle = 'OCR Request Limit Reached';
        break;
      case OcrErrorType.timeout:
        errorIcon = Icons.timer_outlined;
        iconColor = AppColors.warningOrange;
        errorTitle = 'OCR Request Timed Out';
        break;
      case OcrErrorType.networkError:
        errorIcon = Icons.wifi_off_rounded;
        iconColor = AppColors.warningOrange;
        errorTitle = 'Network Connection Error';
        break;
      case OcrErrorType.serverError:
        errorIcon = Icons.cloud_off_rounded;
        iconColor = AppColors.warningOrange;
        errorTitle = 'OCR Service Unavailable';
        break;
      case OcrErrorType.emptyResult:
        errorIcon = Icons.text_snippet_outlined;
        iconColor = AppColors.warningOrange;
        errorTitle = 'No Text Recognized in Image';
        break;
      case OcrErrorType.unreadable:
      case OcrErrorType.none:
        errorIcon = Icons.document_scanner_rounded;
        iconColor = AppColors.warningOrange;
        errorTitle = 'No Legible Text or QR Code Detected';
        break;
    }

    return AuraGlassCard(
      level: AuraGlassLevel.level3,
      padding: const EdgeInsets.all(24),
      customBorderColor: iconColor.withValues(alpha: 0.4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.15),
            ),
            child: Icon(
              errorIcon,
              color: iconColor,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            errorTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _scanErrorMessage ??
                'We could not extract structured text from this image. Ensure the receipt is well-lit, not blurred, or rotate/enhance it.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (_ocrStatusCode != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                'HTTP Response Status: $_ocrStatusCode',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _reAnalyzeImage,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppColors.auroraCyan,
                ),
                label: const Text(
                  'Retry Scan',
                  style: TextStyle(color: AppColors.auroraCyan, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.auroraCyan.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(
                  Icons.photo_library_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Replace Image',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _proceedWithManualEntry,
                icon: const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Enter Manually',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.auroraViolet,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          if (_ocrErrorType == OcrErrorType.rateLimited ||
              _ocrErrorType == OcrErrorType.unauthorized ||
              _ocrErrorType == OcrErrorType.forbidden) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings_outlined,
                  size: 15, color: AppColors.auroraCyan),
              label: const Text(
                'Configure API Key in Settings',
                style: TextStyle(
                  color: AppColors.auroraCyan,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // PREVIEW BANNER & IMAGE ENHANCEMENT TOOLBAR
  // ============================================================
  Widget _buildReceiptPreviewBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showFullReceiptModal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 44,
                height: 44,
                color: Colors.black26,
                child: _receiptBytes != null
                    ? Image.memory(_receiptBytes!, fit: BoxFit.cover)
                    : const Icon(Icons.receipt, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _receiptFileName ?? 'Scanned Receipt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap thumbnail to view high-res preview',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _pickImage(ImageSource.gallery),
            child: const Text(
              'Retake',
              style: TextStyle(
                color: AppColors.auroraCyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageEnhanceToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolButton(
            icon: Icons.rotate_right_rounded,
            label: 'Rotate 90°',
            onTap: _rotateImageClockwise,
          ),
          _buildToolButton(
            icon: Icons.contrast_rounded,
            label: 'Enhance',
            onTap: _enhanceImageReadability,
          ),
          _buildToolButton(
            icon: Icons.filter_b_and_w_rounded,
            label: 'Grayscale',
            onTap: _grayscaleImage,
          ),
          _buildToolButton(
            icon: Icons.restore_rounded,
            label: 'Reset',
            onTap: _resetImage,
          ),
          _buildToolButton(
            icon: Icons.auto_awesome,
            label: 'Re-analyze',
            color: AppColors.auroraCyan,
            onTap: _reAnalyzeImage,
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? Colors.white70),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QR PAYLOAD & UNCERTAINTY CARDS
  // ============================================================
  Widget _buildQrPayloadCard(ReceiptQrPayload qr) {
    if (qr.type == QrPayloadType.upi) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.auroraViolet.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.auroraViolet.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: AppColors.auroraCyan, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'DECODED UPI QR CODE',
                  style: TextStyle(
                    color: AppColors.auroraCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Payment Request (Not Verified Paid)',
                    style: TextStyle(color: AppColors.warning, fontSize: 9.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (qr.upiPayeeVpa != null)
              Text('Payee VPA: ${qr.upiPayeeVpa}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
            if (qr.upiPayeeName != null)
              Row(
                children: [
                  Expanded(
                    child: Text('Payee Name: ${qr.upiPayeeName}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _merchantController.text = qr.upiPayeeName!;
                      });
                    },
                    child: const Text('Use as Merchant',
                        style: TextStyle(
                            color: AppColors.auroraCyan, fontSize: 11)),
                  ),
                ],
              ),
            if (qr.upiAmount != null && qr.upiAmount! > 0)
              Row(
                children: [
                  Text(
                    'QR Embedded Amount: ${CurrencyFormatter.format(qr.upiAmount!)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _amountController.text =
                            qr.upiAmount!.toStringAsFixed(2);
                      });
                    },
                    child: const Text('Use as Amount',
                        style: TextStyle(
                            color: AppColors.auroraCyan, fontSize: 11)),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            const Text(
              '⚠️ UPI QR codes contain payment destination details and do not confirm bank settlement. We never automatically initiate a payment.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      );
    }

    if (qr.type == QrPayloadType.gstEinvoice) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_outlined,
                    color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Text(
                  'GST e-INVOICE QR DETECTED',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (qr.invoiceNumber != null)
              Text('Invoice: ${qr.invoiceNumber}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            if (qr.sellerGstin != null)
              Text('Seller GSTIN: ${qr.sellerGstin}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            if (qr.invoiceAmount != null)
              Text('Total Value: ${CurrencyFormatter.format(qr.invoiceAmount!)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // Default payload display
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code, color: AppColors.auroraCyan, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Decoded Barcode: ${qr.rawText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: qr.rawText));
              _showSnackbar('Barcode payload copied safely.');
            },
            icon: const Icon(Icons.copy_rounded,
                size: 14, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildUncertainTotalWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.warningOrange.withValues(alpha: 0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.warningOrange, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AMOUNT VERIFICATION REQUIRED',
                  style: TextStyle(
                    color: AppColors.warningOrange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'No explicit "Grand Total" or "Net Amount" label was verified with high confidence. Please verify or edit the amount below before confirming.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO TOTAL CARD
  // ============================================================
  Widget _buildDetectedTotalHeroCard() {
    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.auroraViolet.withValues(alpha: 0.22),
            AppColors.cardBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.auroraViolet.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.auroraCyan,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'DETECTED TOTAL',
                    style: TextStyle(
                      color: AppColors.auroraCyan,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.format(parsedAmount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(_selectedCategory),
                  color: AppColors.auroraCyan,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedCategory,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
  // EDITABLE FORM SECTION
  // ============================================================
  Widget _buildFormSection(FinanceProvider finance) {
    return AuraGlassCard(
      level: AuraGlassLevel.level2,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.auroraCyan,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Review & Edit Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Merchant Field
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

            // Subtotal & Tax Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Subtotal'),
                      TextFormField(
                        controller: _subtotalController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration(
                          hintText: '0.00',
                          prefixIcon: Icons.receipt_long_rounded,
                        ),
                        onChanged: (val) {
                          final sub = double.tryParse(val.trim());
                          final tax = double.tryParse(_taxController.text.trim()) ?? 0.0;
                          if (sub != null && sub > 0 && (_amountController.text.trim().isEmpty || _amountController.text.trim() == '0.00')) {
                            _amountController.text = (sub + tax).toStringAsFixed(2);
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Tax (GST/VAT)'),
                      TextFormField(
                        controller: _taxController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration(
                          hintText: '0.00',
                          prefixIcon: Icons.percent_rounded,
                        ),
                        onChanged: (val) {
                          final sub = double.tryParse(_subtotalController.text.trim());
                          final tax = double.tryParse(val.trim()) ?? 0.0;
                          if (sub != null && sub > 0) {
                            _amountController.text = (sub + tax).toStringAsFixed(2);
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grand Total Amount Field
            _buildFieldLabel('Grand Total Amount', isRequired: true),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              decoration: _inputDecoration(
                hintText: '0.00',
                prefixIcon: Icons.currency_rupee_rounded,
              ),
              onChanged: (_) => setState(() {}),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Enter amount';
                }
                final parsed = double.tryParse(val.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Valid amount > 0';
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
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: AppColors.secondaryBackground,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.auroraCyan,
                  ),
                  items: ReceiptSuggestionService.categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(cat),
                            color: AppColors.auroraCyan,
                            size: 17,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            cat,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date & Payment Method Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Date', isRequired: true),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                color: AppColors.auroraCyan,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(_selectedDate),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                  ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Payment Method'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPaymentMethod,
                            isExpanded: true,
                            dropdownColor: AppColors.secondaryBackground,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.auroraCyan,
                            ),
                            items: ReceiptSuggestionService.paymentMethods.map((
                              pay,
                            ) {
                              return DropdownMenuItem<String>(
                                value: pay,
                                child: Text(
                                  pay,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPaymentMethod = val);
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
            _buildFieldLabel('Notes / Line Details'),
            TextFormField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: _inputDecoration(
                hintText: 'Add context or specific line details...',
                prefixIcon: Icons.notes_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EXTRACTED LINE ITEMS SECTION
  // ============================================================
  Widget _buildLineItemsSection() {
    return AuraGlassCard(
      level: AuraGlassLevel.level2,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXTRACTED LINE ITEMS (${_lineItems.length})',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEditLineItemDialog(null),
                icon: const Icon(
                  Icons.add,
                  size: 14,
                  color: AppColors.auroraCyan,
                ),
                label: const Text(
                  'Add Item',
                  style: TextStyle(color: AppColors.auroraCyan, fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_lineItems.length, (index) {
            final item = _lineItems[index];
            return InkWell(
              onTap: () => _showEditLineItemDialog(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.auroraViolet.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.quantity}x',
                        style: const TextStyle(
                          color: AppColors.auroraCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(item.price),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _showEditLineItemDialog(index),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: AppColors.auroraCyan,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _lineItems.removeAt(index);
                        });
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showEditLineItemDialog([int? index]) {
    final isEditing = index != null;
    final item = isEditing ? _lineItems[index] : null;

    final nameController = TextEditingController(text: item?.name ?? '');
    final qtyController =
        TextEditingController(text: (item?.quantity ?? 1).toString());
    final priceController = TextEditingController(
      text: item != null && item.price > 0 ? item.price.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
          title: Text(
            isEditing ? 'Edit Line Item' : 'Add Line Item',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Item Description', isRequired: true),
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: 'e.g. Masala Dosa',
                      prefixIcon: Icons.shopping_bag_outlined,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter item name' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Quantity'),
                            TextFormField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              decoration: _inputDecoration(
                                hintText: '1',
                                prefixIcon: Icons.numbers_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Price (₹)', isRequired: true),
                            TextFormField(
                              controller: priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              decoration: _inputDecoration(
                                hintText: '0.00',
                                prefixIcon: Icons.currency_rupee_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter price';
                                final p = double.tryParse(v.trim());
                                if (p == null || p < 0) return 'Valid price';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final qty = int.tryParse(qtyController.text.trim()) ?? 1;
                  final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                  final newItem = ReceiptLineItem(
                    name: name,
                    quantity: qty > 0 ? qty : 1,
                    price: price,
                  );
                  setState(() {
                    if (isEditing) {
                      _lineItems[index] = newItem;
                    } else {
                      _lineItems.add(newItem);
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.auroraViolet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Item', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // CONFIRM & RETAKE ACTIONS
  // ============================================================
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_isSaving || _showSavedResult) ? null : _confirmAndAddExpense,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 4,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: _showSavedResult
                    ? const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                      )
                    : const LinearGradient(
                        colors: [AppColors.auroraViolet, AppColors.auroraCyan],
                      ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showSavedResult ? Icons.done_all_rounded : Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showSavedResult ? 'Expense Saved to Transactions' : 'Confirm & Add Expense',
                            style: const TextStyle(
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Choose Another Image',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _resetForNewReceipt,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // SAVED RESULT & AI INSIGHT VIEW
  // ============================================================
  Widget _buildSavedResultView(ReceiptInsight insight, FinanceTransaction tx) {
    return Column(
      children: [
        AuraGlassCard(
          level: AuraGlassLevel.level4,
          padding: const EdgeInsets.all(24),
          customBorderColor: AppColors.success.withValues(alpha: 0.4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'RECEIPT CONFIRMED & RECORDED',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCategoryIcon(tx.category),
                      color: AppColors.auroraCyan,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tx.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      ' • ',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    Text(
                      tx.paymentMethod,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
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
                  const Text(
                    'Budget Impact',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${CurrencyFormatter.format(tx.amount)} / ${CurrencyFormatter.format(insight.budgetImpact.monthlyTarget)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (insight.budgetImpact.percentageOfTarget / 100).clamp(
                    0.0,
                    1.0,
                  ),
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    insight.budgetImpact.isExceeding
                        ? AppColors.warning
                        : AppColors.auroraCyan,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // AI Insight Card
        AuraGlassCard(
          level: AuraGlassLevel.level3,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.auroraViolet,
                    size: 17,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'FINPILOT AI INSIGHT',
                    style: TextStyle(
                      color: AppColors.auroraViolet,
                      fontSize: 11.5,
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
                  fontSize: 13.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.auroraCyan.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECOMMENDATION',
                      style: TextStyle(
                        color: AppColors.auroraCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight.recommendation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons: View in Transactions or Record Another
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetForNewReceipt,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Scan Another',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 16),
                label: const Text(
                  'View in History',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.auroraViolet,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
  // UI HELPERS
  // ============================================================
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [AppColors.auroraViolet, AppColors.auroraCyan],
                )
              : null,
          color: isPrimary ? null : AppColors.cardBackground,
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.auroraViolet.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: AppColors.auroraCyan, size: 19),
      filled: true,
      fillColor: AppColors.secondaryBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.auroraCyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.warning, width: 1.5),
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
