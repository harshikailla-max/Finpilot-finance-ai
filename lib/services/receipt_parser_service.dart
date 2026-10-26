import 'package:intl/intl.dart';

import '../models/receipt_model.dart';
import 'receipt_qr_service.dart';
import 'receipt_suggestion_service.dart';

class ReceiptParserService {
  /// Parses raw text extracted from an image or document into structured ReceiptData.
  static ReceiptData parseReceiptText(
    String rawText, {
    String? fileName,
    ReceiptQrPayload? qrPayload,
  }) {
    if (rawText.trim().isEmpty && (qrPayload == null || !qrPayload.isFound)) {
      return ReceiptData(
        merchant: '',
        date: DateTime.now(),
        total: 0.0,
        category: 'Other',
        paymentMethod: 'UPI',
        rawText: rawText,
        confidence: 0.0,
        isTotalUncertain: true,
      );
    }

    final lines = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Extract Merchant Name
    var merchant = _extractMerchant(lines);
    // If merchant wasn't clearly identified in OCR but QR has payee name
    if (merchant.isEmpty &&
        qrPayload != null &&
        qrPayload.upiPayeeName != null &&
        qrPayload.upiPayeeName!.isNotEmpty) {
      merchant = qrPayload.upiPayeeName!;
    }

    // 2. Extract Date (never invent missing dates)
    final extractedDate = _extractDate(lines);
    final date = extractedDate ?? DateTime.now();
    final isDateDetected = extractedDate != null;

    // 3. Extract Invoice / Bill Number & GSTIN
    final invoiceNumber = _extractInvoiceNumber(lines) ?? qrPayload?.invoiceNumber;
    final gstin = _extractGstin(lines) ?? qrPayload?.sellerGstin;

    // 4. Extract Financial Totals
    final totalResult = _extractTotalWithCertainty(lines, qrPayload: qrPayload);
    final total = totalResult.amount;
    final isTotalUncertain = totalResult.isUncertain;

    final tax = _extractTax(lines);
    final subtotal = _extractSubtotal(lines);

    // 5. Extract Line Items
    final lineItems = _extractLineItems(lines, total);

    // 6. Determine Category
    var category = ReceiptSuggestionService.suggestCategory(merchant);
    if (category == 'Other' && lineItems.isNotEmpty) {
      final combinedItems = lineItems.map((e) => e.name).join(' ');
      category = ReceiptSuggestionService.suggestCategory(combinedItems);
    }
    if (category == 'Other') {
      category = ReceiptSuggestionService.suggestCategory(rawText);
    }
    if (category == 'Other') {
      category = 'Food & Dining'; // Practical default for physical receipts
    }

    // 7. Determine Payment Method
    var paymentMethod = ReceiptSuggestionService.suggestPaymentMethod(rawText);
    if (qrPayload != null && qrPayload.type == QrPayloadType.upi) {
      paymentMethod = 'UPI';
    }

    // 8. Confidence Score
    double conf = 0.5;
    if (merchant.isNotEmpty && merchant != 'Receipt Merchant') conf += 0.2;
    if (total > 0 && !isTotalUncertain) conf += 0.2;
    if (lineItems.isNotEmpty) conf += 0.1;
    if (gstin != null) conf += 0.1;

    return ReceiptData(
      merchant: merchant,
      date: date,
      total: total,
      tax: tax,
      subtotal: subtotal,
      category: category,
      paymentMethod: paymentMethod,
      currency: 'INR',
      lineItems: lineItems,
      rawText: rawText,
      confidence: conf.clamp(0.0, 1.0),
      isTotalUncertain: isTotalUncertain,
      isDateDetected: isDateDetected,
      invoiceNumber: invoiceNumber,
      gstin: gstin,
      qrPayload: qrPayload,
    );
  }

  // -------------------------------------------------------------
  // MERCHANT EXTRACTION
  // -------------------------------------------------------------
  static String _extractMerchant(List<String> lines) {
    final ignoredPatterns = [
      'tax invoice',
      'retail invoice',
      'invoice',
      'cash memo',
      'receipt',
      'bill',
      'welcome',
      'thank you',
      'thanks',
      'gstin',
      'fssai',
      'tel:',
      'phone',
      'ph:',
      'mobile',
      'date:',
      'time:',
      'table no',
      'token',
      'order no',
      'customer copy',
      'customer receipt',
      'customer',
      'original for recipient',
      'store #',
      'duplicate',
      'www.',
      'http',
      '.com',
      '.in',
      'address',
      'floor',
      'road',
      'street',
      'nagar',
      'bangalore',
      'mumbai',
      'delhi',
      'pune',
      'hyderabad',
      'chennai',
      'have a',
      'great day',
      'nice day',
      'visit',
      'no:',
      'no.',
      'bill no',
      'inv no',
      'doc no',
      'terminal',
      'pos',
      'cashier',
    ];

    final recognizedMerchants = [
      'Starbucks Coffee',
      'Starbucks',
      'McDonald\'s',
      'McDonalds',
      'KFC',
      'Domino\'s Pizza',
      'Dominos',
      'Pizza Hut',
      'Subway',
      'Burger King',
      'Cafe Coffee Day',
      'Blue Tokai',
      'Third Wave Coffee',
      'Haldiram\'s',
      'Haldirams',
      'Bikanervala',
      'Saravanaa Bhavan',
      'Barbeque Nation',
      'Swiggy',
      'Zomato',
      'Zepto',
      'Blinkit',
      'Instamart',
      'BigBasket',
      'D-Mart',
      'DMart',
      'Reliance Fresh',
      'Reliance Retail',
      'Reliance Smart',
      'Nature\'s Basket',
      'Spencer\'s',
      'More Supermarket',
      'Apollo Pharmacy',
      'Apollo',
      'MedPlus',
      'Netmeds',
      'Decathlon',
      'Zara',
      'H&M',
      'Uniqlo',
      'Marks & Spencer',
      'Westside',
      'Pantaloons',
      'Shoppers Stop',
      'Lifestyle',
      'Shell',
      'HPCL',
      'BPCL',
      'IOCL',
      'Indian Oil',
    ];

    for (final rm in recognizedMerchants) {
      for (final line in lines.take(12)) {
        final cleanLine = line.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
        final cleanRm = rm.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
        if (cleanLine.contains(cleanRm)) {
          if (rm == 'DMart') return 'D-Mart';
          return rm;
        }
      }
    }

    // Only look in top 4 header lines for merchant name
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      if (RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(line)) continue;
      if (line.contains(':')) continue; // Skip key-value lines like "No: 123", "Date: ..."

      bool isIgnored = false;
      for (final ign in ignoredPatterns) {
        if (lower.contains(ign)) {
          isIgnored = true;
          break;
        }
      }

      if (!isIgnored && line.length >= 3 && line.length <= 40) {
        final cleaned = line
            .replaceAll(RegExp(r"^[^a-zA-Z0-9]+|[^a-zA-Z0-9\.\&\s\-']+$"), '')
            .trim();
        // Require at least 3 alphabetic characters to prevent pure numbers or codes
        if (cleaned.length >= 3 && RegExp(r'[a-zA-Z]{3,}').hasMatch(cleaned)) {
          return cleaned;
        }
      }
    }

    // Never invent a missing merchant value. Return empty so user can fill or edit.
    return '';
  }

  // -------------------------------------------------------------
  // GSTIN & INVOICE NUMBER EXTRACTION
  // -------------------------------------------------------------
  static String? _extractGstin(List<String> lines) {
    // 15-character alphanumeric GSTIN format: 2 numbers + 5 letters + 4 numbers + 1 letter + 1 char + Z + 1 char
    final gstinRegex = RegExp(r'\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b');
    for (final line in lines) {
      final match = gstinRegex.firstMatch(line.toUpperCase());
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  static String? _extractInvoiceNumber(List<String> lines) {
    final invRegexes = [
      RegExp(r'(?:invoice\s*(?:no|num|number|#)?|bill\s*(?:no|num|#)?|memo\s*(?:no|#)?|doc\s*(?:no|#)?)\s*[:=\s]\s*([A-Za-z0-9\-\/]{3,24})', caseSensitive: false),
      RegExp(r'\b(?:inv|bill|doc)[-_\s]?#?\s*([0-9]{3,12})\b', caseSensitive: false),
    ];

    for (final line in lines) {
      for (final reg in invRegexes) {
        final match = reg.firstMatch(line);
        if (match != null && match.group(1) != null) {
          final candidate = match.group(1)!.trim();
          if (candidate.length >= 3 && !candidate.toLowerCase().contains('date')) {
            return candidate;
          }
        }
      }
    }
    return null;
  }

  // -------------------------------------------------------------
  // DATE EXTRACTION
  // -------------------------------------------------------------
  static DateTime? _extractDate(List<String> lines) {
    final dateRegexes = [
      RegExp(r'\b(\d{1,2})[/\.-](\d{1,2})[/\.-](\d{4})\b'),
      RegExp(r'\b(\d{4})[/\.-](\d{1,2})[/\.-](\d{1,2})\b'),
      RegExp(r'\b(\d{1,2})[/\.-](\d{1,2})[/\.-](\d{2})\b'),
      RegExp(r'\b(\d{1,2})[\s/-]([A-Za-z]{3,9})[\s/-](\d{2,4})\b'),
    ];

    for (final line in lines) {
      for (final reg in dateRegexes) {
        final match = reg.firstMatch(line);
        if (match != null) {
          final str = match.group(0)!;
          final parsed = _parseFlexibleDate(str);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  static DateTime? _parseFlexibleDate(String raw) {
    final clean = raw.trim().replaceAll('-', '/').replaceAll('.', '/');
    final parts = clean.split('/');

    if (parts.length == 3) {
      final p1 = int.tryParse(parts[0]);
      final p2 = int.tryParse(parts[1]);
      final p3 = int.tryParse(parts[2]);

      if (p1 != null && p2 != null && p3 != null) {
        // YYYY/MM/DD
        if (p1 >= 2020 && p1 <= 2035 && p2 >= 1 && p2 <= 12 && p3 >= 1 && p3 <= 31) {
          return DateTime(p1, p2, p3);
        }

        // DD/MM/YYYY or DD/MM/YY
        var year = p3;
        if (year < 100) year += 2000;
        if (p1 >= 1 && p1 <= 31 && p2 >= 1 && p2 <= 12 && year >= 2020 && year <= 2035) {
          return DateTime(year, p2, p1);
        }

        // MM/DD/YYYY fallback
        if (p2 >= 1 && p2 <= 31 && p1 >= 1 && p1 <= 12 && year >= 2020 && year <= 2035) {
          return DateTime(year, p1, p2);
        }
      }
    }

    try {
      final normalized = raw.replaceAll('-', ' ').replaceAll('/', ' ');
      return DateFormat('dd MMM yyyy').parseLoose(normalized);
    } catch (_) {}

    return null;
  }

  // -------------------------------------------------------------
  // TOTAL AMOUNT EXTRACTION WITH VALIDATION & UNCERTAINTY
  // -------------------------------------------------------------
  static _TotalExtractionResult _extractTotalWithCertainty(
    List<String> lines, {
    ReceiptQrPayload? qrPayload,
  }) {
    // If QR payload has an explicit amount (e.g. GST invoice or UPI amount)
    if (qrPayload != null && qrPayload.invoiceAmount != null && qrPayload.invoiceAmount! > 0) {
      return _TotalExtractionResult(amount: qrPayload.invoiceAmount!, isUncertain: false);
    }
    if (qrPayload != null && qrPayload.upiAmount != null && qrPayload.upiAmount! > 0) {
      return _TotalExtractionResult(amount: qrPayload.upiAmount!, isUncertain: false);
    }

    final primaryTotalKeywords = [
      'grand total',
      'total amount',
      'total payable',
      'net payable',
      'amount payable',
      'net amount',
      'bill total',
      'final total',
      'invoice total',
      'balance due',
      'amount paid',
      'paid amount',
    ];

    // Priority 1: Check primary unambiguous total keywords
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      // Exclude Subtotal, Tax, Discount
      if (lower.contains('sub') ||
          lower.contains('cgst') ||
          lower.contains('sgst') ||
          lower.contains('igst') ||
          lower.contains('vat') ||
          lower.contains('discount') ||
          lower.contains('total qty') ||
          lower.contains('total items')) {
        continue;
      }

      for (final kw in primaryTotalKeywords) {
        if (lower.contains(kw)) {
          final amt = _extractLastAmountFromLine(line);
          if (amt != null && amt > 0) {
            return _TotalExtractionResult(amount: amt, isUncertain: false);
          }

          if (i + 1 < lines.length) {
            final nextAmt = _extractLastAmountFromLine(lines[i + 1]);
            if (nextAmt != null && nextAmt > 0) {
              return _TotalExtractionResult(amount: nextAmt, isUncertain: false);
            }
          }
        }
      }
    }

    // Priority 2: Check generic "TOTAL" line
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (lower.contains('sub') ||
          lower.contains('tax') ||
          lower.contains('discount') ||
          lower.contains('savings') ||
          lower.contains('total qty') ||
          lower.contains('total items')) {
        continue;
      }

      if (lower.contains('total')) {
        final amt = _extractLastAmountFromLine(line);
        if (amt != null && amt > 0) {
          return _TotalExtractionResult(amount: amt, isUncertain: false);
        }

        if (i + 1 < lines.length) {
          final nextAmt = _extractLastAmountFromLine(lines[i + 1]);
          if (nextAmt != null && nextAmt > 0) {
            return _TotalExtractionResult(amount: nextAmt, isUncertain: false);
          }
        }
      }
    }

    // Priority 3: Fallback to largest reasonable number in bottom 60% of receipt
    // This is explicitly marked as UNCERTAIN so user is requested to verify/confirm
    final startIndex = (lines.length * 0.4).floor();
    double highest = 0.0;
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (lower.contains('phone') ||
          lower.contains('tel') ||
          lower.contains('gstin') ||
          lower.contains('gst') ||
          lower.contains('card') ||
          lower.contains('fssai') ||
          lower.contains('auth') ||
          lower.contains('rrn')) {
        continue;
      }

      final amt = _extractLastAmountFromLine(line);
      if (amt != null && amt > highest && amt < 1000000) {
        highest = amt;
      }
    }

    if (highest > 0) {
      return _TotalExtractionResult(amount: highest, isUncertain: true);
    }

    return const _TotalExtractionResult(amount: 0.0, isUncertain: true);
  }

  // -------------------------------------------------------------
  // TAX EXTRACTION
  // -------------------------------------------------------------
  static double? _extractTax(List<String> lines) {
    // Priority 1: Check for explicit "total tax" line to avoid double-counting breakdown
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('total tax') || lower.contains('tax total')) {
        final amt = _extractLastAmountFromLine(line);
        if (amt != null && amt > 0) return amt;
      }
    }

    // Priority 2: Sum individual tax lines (CGST, SGST, IGST, VAT)
    double totalTax = 0.0;
    bool foundTax = false;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('total tax') || lower.contains('tax total')) continue;

      if (lower.contains('gst') ||
          lower.contains('cgst') ||
          lower.contains('sgst') ||
          lower.contains('igst') ||
          lower.contains('vat') ||
          (lower.contains('tax') &&
              !lower.contains('taxable') &&
              !lower.contains('tax invoice'))) {
        final amt = _extractLastAmountFromLine(line);
        if (amt != null && amt > 0 && amt < 50000) {
          totalTax += amt;
          foundTax = true;
        }
      }
    }

    return foundTax && totalTax > 0 ? totalTax : null;
  }

  // -------------------------------------------------------------
  // SUBTOTAL EXTRACTION
  // -------------------------------------------------------------
  static double? _extractSubtotal(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('sub total') ||
          lower.contains('subtotal') ||
          lower.contains('items total')) {
        final amt = _extractLastAmountFromLine(line);
        if (amt != null && amt > 0) return amt;
      }
    }
    return null;
  }

  // -------------------------------------------------------------
  // LINE ITEMS EXTRACTION
  // -------------------------------------------------------------
  static List<ReceiptLineItem> _extractLineItems(
    List<String> lines,
    double total,
  ) {
    final items = <ReceiptLineItem>[];

    final excludeWords = [
      'total',
      'subtotal',
      'sub total',
      'tax',
      'gst',
      'cgst',
      'sgst',
      'vat',
      'discount',
      'round off',
      'round',
      'cash',
      'change',
      'card',
      'balance',
      'paid',
      'tender',
      'invoice',
      'receipt',
      'welcome',
      'fssai',
      'date',
      'time',
      'table',
      'token',
      'customer',
      'order',
      'bill',
      'thank',
      'upi',
      'net banking',
      'phone',
      'tel',
      'qty',
      'rate',
      'item',
      'description',
      'amount',
    ];

    for (final line in lines) {
      final lower = line.toLowerCase();

      bool skip = false;
      for (final ex in excludeWords) {
        if (lower.contains(ex)) {
          skip = true;
          break;
        }
      }
      if (skip) continue;

      final amountMatch = RegExp(
        r'(?:INR|Rs\.?|₹)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})|[0-9]+(?:\.[0-9]{1,2})?)$',
      ).firstMatch(line.trim());
      if (amountMatch == null) continue;

      final priceStr = amountMatch.group(1)?.replaceAll(',', '');
      if (priceStr == null) continue;

      final price = double.tryParse(priceStr);
      if (price == null || price <= 0 || price > 50000) continue;

      var namePart = line.substring(0, amountMatch.start).trim();

      int qty = 1;
      final qtyPrefix = RegExp(r'^(\d{1,2})\s*(?:x|\*|\-)?\s+').firstMatch(namePart);
      if (qtyPrefix != null) {
        qty = int.tryParse(qtyPrefix.group(1)!) ?? 1;
        namePart = namePart.substring(qtyPrefix.end).trim();
      }

      final cleanName = namePart
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s\.\&\-]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleanName.length >= 2 && cleanName.length <= 50) {
        if (price == total && cleanName.toLowerCase().contains('due')) continue;

        items.add(
          ReceiptLineItem(name: cleanName, price: price, quantity: qty),
        );
      }
    }

    return items;
  }

  // -------------------------------------------------------------
  // HELPER: EXTRACT LAST AMOUNT FROM LINE
  // -------------------------------------------------------------
  static double? _extractLastAmountFromLine(String line) {
    final matches = RegExp(
      r'(?:INR|Rs\.?|₹)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
    ).allMatches(line);
    if (matches.isEmpty) return null;

    for (final match in matches.toList().reversed) {
      final raw = match.group(1)?.replaceAll(',', '');
      if (raw != null) {
        final val = double.tryParse(raw);
        if (val != null && val > 0 && val < 5000000) {
          return val;
        }
      }
    }
    return null;
  }
}

class _TotalExtractionResult {
  final double amount;
  final bool isUncertain;

  const _TotalExtractionResult({required this.amount, required this.isUncertain});
}
