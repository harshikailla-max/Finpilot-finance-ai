import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storageService;
  bool _isDarkMode = true;

  ThemeProvider(this._storageService) {
    _loadFromStorage();
  }

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _storageService.setBool('settings_dark_mode', _isDarkMode);
  }

  void _loadFromStorage() {
    _isDarkMode = _storageService.getBool('settings_dark_mode') ?? true;
    notifyListeners();
  }
}
