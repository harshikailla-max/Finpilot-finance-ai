import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finpilot_ai/providers/finance_provider.dart';
import 'package:finpilot_ai/providers/theme_provider.dart';
import 'package:finpilot_ai/screens/receipt_scanner_screen.dart';
import 'package:finpilot_ai/services/storage_service.dart';
import 'package:finpilot_ai/theme/app_theme.dart';

class MockTestStorage implements StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }
}

void main() {
  testWidgets(
    'ReceiptScannerScreen renders title, scanning hero, and action buttons',
    (WidgetTester tester) async {
      final storage = MockTestStorage();
      final finance = FinanceProvider(storage);
      final theme = ThemeProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ReceiptScannerScreen(),
          ),
        ),
      );

      // Initial frame
      await tester.pump();

      // Verify title and subtitle
      expect(find.text('Receipt Scanner'), findsOneWidget);
      expect(find.text('Capture & Scan Receipt'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('PDF / File'), findsOneWidget);
      expect(find.textContaining('BEST PRACTICES FOR OCR'), findsOneWidget);
    },
  );
}
