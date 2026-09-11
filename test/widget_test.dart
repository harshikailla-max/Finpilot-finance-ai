import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finpilot_ai/services/storage_service.dart';
import 'package:finpilot_ai/screens/splash_screen.dart';
import 'package:finpilot_ai/theme/app_theme.dart';
import 'package:flutter/material.dart';

// In-memory mock storage for testing
class MockStorageService implements StorageService {
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
  testWidgets('SplashScreen smoke test displays title and subtitle', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      Provider<StorageService>.value(
        value: mockStorage,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SplashScreen(),
        ),
      ),
    );

    expect(find.text('FINPILOT AI'), findsOneWidget);
    expect(find.text('Your Intelligent Finance Companion'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
