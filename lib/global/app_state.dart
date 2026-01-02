class AppState {
  static final AppState instance = AppState._internal();

  factory AppState() {
    return instance;
  }

  AppState._internal();

  bool admin = false;
}