import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _autoAddKey = "sms_auto_add_transactions";

  /// Returns whether incoming transactional SMS should be automatically added
  /// without requiring manual approval actions in notifications.
  static Future<bool> getAutoAddTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoAddKey) ?? true; // Defaults to True (Automatic Mode)
  }

  /// Persists the user setting for SMS auto add transactions mode.
  static Future<void> setAutoAddTransactions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAddKey, value);
  }
}
