import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  factory AppState() => instance;
  AppState._internal() {
    _loadAdminStatus(); // Load saved status when the app starts
  }

  bool _admin = false;
  bool get admin => _admin;

  // Load from disk
  Future<void> _loadAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _admin = prefs.getBool('is_admin') ?? false;
    notifyListeners();
  }

  // Save to disk
  set admin(bool value) {
    if (_admin != value) {
      _admin = value;
      _saveAdminStatus(value);
      notifyListeners(); 
    }
  }

  Future<void> _saveAdminStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_admin', value);
  }

  void reset() async {
    _admin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_admin');
    notifyListeners();
  }
}