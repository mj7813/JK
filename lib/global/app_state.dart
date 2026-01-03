import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  factory AppState() => instance;
  AppState._internal();

  bool _admin = false;

  // Getter
  bool get admin => _admin;

  // Setter that notifies the UI to rebuild
  set admin(bool value) {
    if (_admin != value) {
      _admin = value;
      notifyListeners(); 
    }
  }

  // IMPORTANT: Call this when the user logs out
  void reset() {
    _admin = false;
    notifyListeners();
  }
}