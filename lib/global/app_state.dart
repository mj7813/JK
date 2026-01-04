import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  factory AppState() => instance;
  AppState._internal(); // Remove the call from here

  bool _admin = false;
  bool get admin => _admin;

  // Change this to a public method you can 'await' in main.dart
  Future<void> loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _admin = prefs.getBool('is_admin') ?? false;
    notifyListeners();
    debugPrint("AppState Loaded: Admin = $_admin");
  }
  // Inside AppState class in app_state.dart
  Future<void> reset() async {
    _admin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_admin'); // Clears the saved data from disk
    notifyListeners(); // Tells the UI to hide the admin buttons
  }

  // Keep your existing setter, reset, and save methods...
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
}