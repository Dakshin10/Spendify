import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_helper.dart';
import '../../models/transaction_model.dart';
import '../../services/sms_service.dart';

class AppState extends ChangeNotifier {
  // Singleton pattern for easy global access
  static final AppState instance = AppState._internal();
  AppState._internal() {
    loadTransactions();
  }

  // Onboarding & user settings persistence
  bool _isOnboarded = false;
  bool _isProfileSetup = false;
  String _userName = 'Investor';
  double _monthlyIncome = 0.0;

  // Personal profile details
  String _fullName = '';
  String _displayName = '';
  String _dateOfBirth = '';
  String _gender = '';
  String _city = '';
  String _state = '';
  String _lifeStage = '';
  String _primaryBank = '';
  String _upiId = '';
  String _spendingStyle = '';
  List<String> _moneyChallenge = [];
  bool _notifyTransactions = true;
  bool _notifyBudget = true;
  bool _notifyMonthly = true;

  // SMS auto-tracking toggle
  bool _smsTrackingEnabled = true;

  // Category overrides by transaction ID
  final Map<int, String> _categoryOverrides = {};

  bool get isOnboarded => _isOnboarded;
  bool get isProfileSetup => _isProfileSetup;
  String get userName => _userName;
  double get monthlyIncome => _monthlyIncome;
  String get fullName => _fullName;
  String get displayName => _displayName;
  String get dateOfBirth => _dateOfBirth;
  String get gender => _gender;
  String get city => _city;
  String get userState => _state;
  String get lifeStage => _lifeStage;
  String get primaryBank => _primaryBank;
  String get upiId => _upiId;
  String get spendingStyle => _spendingStyle;
  List<String> get moneyChallenge => _moneyChallenge;
  bool get notifyTransactions => _notifyTransactions;
  bool get notifyBudget => _notifyBudget;
  bool get notifyMonthly => _notifyMonthly;
  bool get smsTrackingEnabled => _smsTrackingEnabled;

  int currentTab = 0;

  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  List<TransactionModel> transactions = [];
  double totalSpent = 0;
  double totalCredits = 0;

  // Budget configurations
  double totalBudgetLimit = 8000.0;
  final Map<String, double> categoryLimits = {
    "Food & Beverages": 3000.0,
    "Transport": 1500.0,
    "Shopping": 2000.0,
    "Entertainment": 1000.0,
    "Bills & Utilities": 1200.0,
    "Other": 800.0,
  };

  bool alertNotificationsEnabled = true;

  // Theme Toggler
  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', _themeMode == ThemeMode.light ? 'light' : 'dark');
    } catch (e) {
      debugPrint("Failed to save theme preference: $e");
    }
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', _themeMode == ThemeMode.light ? 'light' : 'dark');
    } catch (e) {
      debugPrint("Failed to save theme preference: $e");
    }
  }

  // SMS Tracking Toggle
  void setSmsTracking(bool enabled) async {
    _smsTrackingEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('smsTrackingEnabled', enabled);
    } catch (e) {
      debugPrint("Failed to save SMS tracking preference: $e");
    }
  }

  // Load Transactions from SQLite DB
  Future<void> loadTransactions() async {
    try {
      // Load persisted settings
      final prefs = await SharedPreferences.getInstance();
      _isOnboarded = prefs.getBool('isOnboarded') ?? false;
      _isProfileSetup = prefs.getBool('isProfileSetup') ?? false;
      _userName = prefs.getString('userName') ?? 'Investor';
      _monthlyIncome = prefs.getDouble('monthlyIncome') ?? 0.0;
      totalBudgetLimit = prefs.getDouble('totalBudgetLimit') ?? 8000.0;
      _fullName = prefs.getString('fullName') ?? '';
      _displayName = prefs.getString('displayName') ?? '';
      _dateOfBirth = prefs.getString('dateOfBirth') ?? '';
      _gender = prefs.getString('gender') ?? '';
      _city = prefs.getString('city') ?? '';
      _state = prefs.getString('userState') ?? '';
      _lifeStage = prefs.getString('lifeStage') ?? '';
      _primaryBank = prefs.getString('primaryBank') ?? '';
      _upiId = prefs.getString('upiId') ?? '';
      _spendingStyle = prefs.getString('spendingStyle') ?? '';
      _moneyChallenge = prefs.getStringList('moneyChallenge') ?? [];
      _notifyTransactions = prefs.getBool('notifyTransactions') ?? true;
      _notifyBudget = prefs.getBool('notifyBudget') ?? true;
      _notifyMonthly = prefs.getBool('notifyMonthly') ?? true;
      _smsTrackingEnabled = prefs.getBool('smsTrackingEnabled') ?? true;
      final themeStr = prefs.getString('themeMode') ?? 'dark';
      _themeMode = themeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

      for (var cat in categoryLimits.keys) {
        if (prefs.containsKey('limit_$cat')) {
          categoryLimits[cat] = prefs.getDouble('limit_$cat')!;
        }
      }
    } catch (e) {
      debugPrint("Failed to load SharedPreferences: $e");
      // Fallback/resilience: if preferences fail, default to onboarded so user can see dashboard
      _isOnboarded = true;
      _isProfileSetup = true;
      _userName = 'Investor';
    }

    try {
      var list = await DatabaseHelper.getTransactions();
      transactions = list.map((e) => TransactionModel.fromMap(e)).toList();

      // Load category overrides
      _categoryOverrides.clear();
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey('category_overrides')) {
          final String? overridesJson = prefs.getString('category_overrides');
          if (overridesJson != null) {
            final Map<String, dynamic> decoded = jsonDecode(overridesJson);
            decoded.forEach((key, value) {
              final int? id = int.tryParse(key);
              if (id != null && value is String) {
                _categoryOverrides[id] = value;
              }
            });
          }
        } else {
          // Perform one-time migration from legacy format
          bool migrated = false;
          for (var tx in transactions) {
            if (tx.id != null) {
              final key = 'override_${tx.id}';
              if (prefs.containsKey(key)) {
                _categoryOverrides[tx.id!] = prefs.getString(key)!;
                migrated = true;
              }
            }
          }
          if (migrated) {
            // Save migrated overrides to consolidated key
            final Map<String, String> stringMap = _categoryOverrides.map((k, v) => MapEntry(k.toString(), v));
            await prefs.setString('category_overrides', jsonEncode(stringMap));
            
            // Clean up old individual keys to save disk space
            for (var id in _categoryOverrides.keys) {
              await prefs.remove('override_$id');
            }
          }
        }
      } catch (_) {}

      // Sum credits/debits
      double spent = 0;
      double credits = 0;
      for (var tx in transactions) {
        final amt = double.tryParse(tx.amount) ?? 0.0;
        if (tx.type == "DEBIT") {
          spent += amt;
        } else {
          credits += amt;
        }
      }
      totalSpent = spent;
      totalCredits = credits;
    } catch (e) {
      debugPrint("Failed to load transactions database: $e");
    }
    
    notifyListeners();
  }



  // Add a manual transaction
  Future<void> addManualTransaction({
    required double amount,
    required String merchant,
    required String type,
    required String paymentMode,
    required String bank,
    int? timestamp,
  }) async {
    final tx = TransactionModel(
      amount: amount.toStringAsFixed(2),
      merchant: merchant,
      type: type,
      paymentMode: paymentMode,
      bank: bank,
      sender: "MANUAL",
      confidence: 100,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      message: "Manually entered transaction of ₹${amount.toStringAsFixed(2)} at $merchant.",
    );

    await DatabaseHelper.insertTransaction(tx.toMap());
    await loadTransactions();
  }

  // Add multiple transactions at once (batch insert)
  Future<void> addTransactions(List<TransactionModel> newTxs) async {
    for (var tx in newTxs) {
      await DatabaseHelper.insertTransaction(tx.toMap());
    }
    await loadTransactions();
  }

  // SMS Ingest Hook
  Future<void> ingestSMS(String message, String sender, BuildContext context) async {
    final tx = SMSService.parseSMS(message, sender);
    if (tx != null) {
      await DatabaseHelper.insertTransaction(tx.toMap());
      await loadTransactions();
      
      if (alertNotificationsEnabled && context.mounted) {
        _showNotificationAlert(context, tx);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("SMS received, but it wasn't recognized as a transaction."),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Save personal details and mark profile setup complete
  Future<void> savePersonalDetails({
    required String fullName,
    required String displayName,
    required String dateOfBirth,
    required String gender,
    required String city,
    required String state,
    required String lifeStage,
    required String primaryBank,
    required String upiId,
    required double income,
    required String spendingStyle,
    required List<String> moneyChallenge,
    required bool notifyTransactions,
    required bool notifyBudget,
    required bool notifyMonthly,
  }) async {
    _fullName = fullName;
    _displayName = displayName.isNotEmpty ? displayName : fullName.split(' ').first;
    _userName = _displayName;
    _dateOfBirth = dateOfBirth;
    _gender = gender;
    _city = city;
    _state = state;
    _lifeStage = lifeStage;
    _primaryBank = primaryBank;
    _upiId = upiId;
    _monthlyIncome = income;
    _spendingStyle = spendingStyle;
    _moneyChallenge = moneyChallenge;
    _notifyTransactions = notifyTransactions;
    _notifyBudget = notifyBudget;
    _notifyMonthly = notifyMonthly;
    _isProfileSetup = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isProfileSetup', true);
      await prefs.setString('fullName', fullName);
      await prefs.setString('displayName', _displayName);
      await prefs.setString('userName', _displayName);
      await prefs.setString('dateOfBirth', dateOfBirth);
      await prefs.setString('gender', gender);
      await prefs.setString('city', city);
      await prefs.setString('userState', state);
      await prefs.setString('lifeStage', lifeStage);
      await prefs.setString('primaryBank', primaryBank);
      await prefs.setString('upiId', upiId);
      await prefs.setDouble('monthlyIncome', income);
      await prefs.setString('spendingStyle', spendingStyle);
      await prefs.setStringList('moneyChallenge', moneyChallenge);
      await prefs.setBool('notifyTransactions', notifyTransactions);
      await prefs.setBool('notifyBudget', notifyBudget);
      await prefs.setBool('notifyMonthly', notifyMonthly);
    } catch (e) {
      debugPrint("Failed to save personal details: $e");
    }

    notifyListeners();
  }

  // Delete all data and preferences
  Future<void> resetAllData() async {
    await DatabaseHelper.clearTransactions();
    transactions.clear();
    totalSpent = 0;
    totalCredits = 0;

    _isOnboarded = false;
    _userName = 'Investor';
    _monthlyIncome = 0.0;
    totalBudgetLimit = 8000.0;

    // Reset default category limits
    final Map<String, double> defaults = {
      "Food & Beverages": 3000.0,
      "Transport": 1500.0,
      "Shopping": 2000.0,
      "Entertainment": 1000.0,
      "Bills & Utilities": 1200.0,
      "Other": 800.0,
    };
    categoryLimits.clear();
    defaults.forEach((key, val) {
      categoryLimits[key] = val;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint("Failed to clear SharedPreferences: $e");
    }

    notifyListeners();
  }

  // Completes onboarding wizard and persists attributes
  Future<void> completeOnboarding({
    required String name,
    required double income,
    required double budget,
    required Map<String, double> categories,
  }) async {
    _userName = name;
    _monthlyIncome = income;
    totalBudgetLimit = budget;
    categories.forEach((key, val) {
      categoryLimits[key] = val;
    });
    _isOnboarded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOnboarded', true);
      await prefs.setString('userName', name);
      await prefs.setDouble('monthlyIncome', income);
      await prefs.setDouble('totalBudgetLimit', budget);
      for (var entry in categories.entries) {
        await prefs.setDouble('limit_${entry.key}', entry.value);
      }
    } catch (e) {
      debugPrint("Failed to save onboarding to SharedPreferences: $e");
    }
    
    notifyListeners();
  }

  // Toggle notifications
  void toggleAlertNotifications(bool value) {
    alertNotificationsEnabled = value;
    notifyListeners();
  }

  // Update budget limit for category (Persistent)
  Future<void> updateCategoryLimit(String category, double limit) async {
    categoryLimits[category] = limit;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('limit_$category', limit);
    } catch (e) {
      debugPrint("Failed to update category limit in SharedPreferences: $e");
    }
    notifyListeners();
  }

  // Update total budget limit (Persistent)
  Future<void> updateTotalBudget(double limit) async {
    totalBudgetLimit = limit;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('totalBudgetLimit', limit);
    } catch (e) {
      debugPrint("Failed to update total budget in SharedPreferences: $e");
    }
    notifyListeners();
  }


  // Dynamic Merchant -> Category mapper
  String getCategory(String merchant, [int? txId]) {
    if (txId != null && _categoryOverrides.containsKey(txId)) {
      return _categoryOverrides[txId]!;
    }
    final m = merchant.toLowerCase();
    if (m.contains('coffee') ||
        m.contains('snacks') ||
        m.contains('lunch') ||
        m.contains('starbucks') ||
        m.contains('food') ||
        m.contains('dining') ||
        m.contains('restaurant') ||
        m.contains('cafe')) {
      return "Food & Beverages";
    } else if (m.contains('bigbasket') ||
        m.contains('grocery') ||
        m.contains('groceries') ||
        m.contains('supermarket')) {
      return "Food & Beverages"; // Grouped in Food & Beverages for simplicity/onboarding consistency
    } else if (m.contains('uber') ||
        m.contains('ride') ||
        m.contains('cab') ||
        m.contains('transport') ||
        m.contains('travel') ||
        m.contains('ola') ||
        m.contains('train') ||
        m.contains('flight')) {
      return "Transport";
    } else if (m.contains('sneakers') ||
        m.contains('shopping') ||
        m.contains('amazon') ||
        m.contains('flipkart') ||
        m.contains('myntra') ||
        m.contains('zara') ||
        m.contains('clothing')) {
      return "Shopping";
    } else if (m.contains('salary') ||
        m.contains('credits') ||
        m.contains('dividend') ||
        m.contains('income')) {
      return "Credits";
    } else if (m.contains('bill') ||
        m.contains('utility') ||
        m.contains('recharge') ||
        m.contains('electricity') ||
        m.contains('water') ||
        m.contains('broadband') ||
        m.contains('netflix') ||
        m.contains('spotify') ||
        m.contains('youtube') ||
        m.contains('prime') ||
        m.contains('subscription') ||
        m.contains('telecom') ||
        m.contains('phone')) {
      return "Bills & Utilities";
    }
    return "Entertainment"; // Default fallback
  }

  Future<void> setCategoryOverride(int txId, String category) async {
    _categoryOverrides[txId] = category;
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> stringMap = _categoryOverrides.map((k, v) => MapEntry(k.toString(), v));
      await prefs.setString('category_overrides', jsonEncode(stringMap));
    } catch (e) {
      debugPrint("Failed to save category override to SharedPreferences: $e");
    }
    // Recalculate spent totals
    double spent = 0;
    double credits = 0;
    for (var tx in transactions) {
      final amt = double.tryParse(tx.amount) ?? 0.0;
      if (tx.type == "DEBIT") {
        spent += amt;
      } else {
        credits += amt;
      }
    }
    totalSpent = spent;
    totalCredits = credits;
    notifyListeners();
  }

  Future<void> updateTransactionCategory(int txId, String category) async {
    await setCategoryOverride(txId, category);
  }

  Future<void> deleteTransaction(int txId) async {
    await DatabaseHelper.deleteTransaction(txId);
    _categoryOverrides.remove(txId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> stringMap = _categoryOverrides.map((k, v) => MapEntry(k.toString(), v));
      await prefs.setString('category_overrides', jsonEncode(stringMap));
      await prefs.remove('override_$txId');
    } catch (_) {}
    await loadTransactions();
  }

  // Compute spend for specific category
  double getCategorySpend(String category) {
    double spent = 0;
    for (var tx in transactions) {
      if (tx.type == "DEBIT" && getCategory(tx.merchant, tx.id) == category) {
        spent += double.tryParse(tx.amount) ?? 0.0;
      }
    }
    return spent;
  }

  // Custom premium in-app alert notification
  void _showNotificationAlert(BuildContext context, TransactionModel tx) {
    final isDark = _themeMode == ThemeMode.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 70), // Keep it above the floating nav bar!
        elevation: 10,
        backgroundColor: isDark ? const Color(0xFF151915) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1F241F) : const Color(0xFFD2DDD5),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF00FF66).withOpacity(0.15) : const Color(0xFF0F6038).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sms_rounded,
                color: isDark ? const Color(0xFF02FF82) : const Color(0xFF0F6038),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Smart SMS Ingestion Active",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "₹${tx.amount} spent at ${tx.merchant} (${tx.paymentMode})",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF888E88) : const Color(0xFF7A7A7A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dynamic Monthly Spends for Sparkline Graph
  List<String> getMonthlyTrendLabels() {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final now = DateTime.now();
    final List<String> labels = [];
    for (int i = 6; i >= 0; i--) {
      // Correctly roll back month without overflow
      final dt = DateTime(now.year, now.month - i, 1);
      labels.add(months[dt.month - 1]);
    }
    return labels;
  }

  List<double> getMonthlyTrendSpends() {
    final now = DateTime.now();
    final List<double> spends = [];
    for (int i = 6; i >= 0; i--) {
      final startOfMonth = DateTime(now.year, now.month - i, 1);
      final endOfMonth = DateTime(now.year, now.month - i + 1, 1).subtract(const Duration(milliseconds: 1));
      
      double monthlySpent = 0;
      for (var tx in transactions) {
        if (tx.type == "DEBIT" && 
            tx.timestamp >= startOfMonth.millisecondsSinceEpoch && 
            tx.timestamp <= endOfMonth.millisecondsSinceEpoch) {
          monthlySpent += double.tryParse(tx.amount) ?? 0.0;
        }
      }
      spends.add(monthlySpent);
    }
    return spends;
  }

  // Dynamic Recurring Subscriptions list
  List<Map<String, String>> getSubscriptions() {
    final Map<String, double> subs = {};
    for (var tx in transactions) {
      if (tx.type == "DEBIT") {
        final merchantLower = tx.merchant.toLowerCase();
        if (merchantLower.contains('netflix') ||
            merchantLower.contains('spotify') ||
            merchantLower.contains('icloud') ||
            merchantLower.contains('youtube') ||
            merchantLower.contains('prime') ||
            merchantLower.contains('subscription') ||
            merchantLower.contains('premium')) {
          final double amt = double.tryParse(tx.amount) ?? 0.0;
          subs[tx.merchant] = amt;
        }
      }
    }
    
    final List<Map<String, String>> result = [];
    subs.forEach((name, price) {
      result.add({
        "name": name,
        "price": "₹${price.toStringAsFixed(0)} / Month",
      });
    });
    return result;
  }

  // Today's spend compared to Yesterday's spend dynamically
  Map<String, dynamic> getTodaySpendComparison() {
    final now = DateTime.now();
    final todayStart = DateUtils.dateOnly(now).millisecondsSinceEpoch;
    final yesterdayStart = DateUtils.dateOnly(now.subtract(const Duration(days: 1))).millisecondsSinceEpoch;
    
    double todaySpent = 0;
    double yesterdaySpent = 0;
    
    for (var tx in transactions) {
      if (tx.type == "DEBIT") {
        if (tx.timestamp >= todayStart) {
          todaySpent += double.tryParse(tx.amount) ?? 0.0;
        } else if (tx.timestamp >= yesterdayStart && tx.timestamp < todayStart) {
          yesterdaySpent += double.tryParse(tx.amount) ?? 0.0;
        }
      }
    }
    
    double pctChange = 0;
    bool isDown = true;
    if (yesterdaySpent > 0) {
      final diff = todaySpent - yesterdaySpent;
      pctChange = (diff / yesterdaySpent * 100).abs();
      isDown = diff < 0;
    } else if (todaySpent > 0) {
      pctChange = 100.0;
      isDown = false;
    }
    
    return {
      "todaySpent": todaySpent,
      "pctChange": pctChange,
      "isDown": isDown,
      "yesterdaySpent": yesterdaySpent,
    };
  }

  // Today's highest category spend dynamically
  String getTodayTopCategory() {
    final now = DateTime.now();
    final todayStart = DateUtils.dateOnly(now).millisecondsSinceEpoch;
    final Map<String, double> categorySpends = {};
    
    for (var tx in transactions) {
      if (tx.type == "DEBIT" && tx.timestamp >= todayStart) {
        final cat = getCategory(tx.merchant);
        categorySpends[cat] = (categorySpends[cat] ?? 0.0) + (double.tryParse(tx.amount) ?? 0.0);
      }
    }
    
    if (categorySpends.isEmpty) {
      return "No spends logged today";
    }
    
    String topCat = "";
    double maxSpend = -1;
    categorySpends.forEach((cat, spend) {
      if (spend > maxSpend) {
        maxSpend = spend;
        topCat = cat;
      }
    });
    
    return "Mostly on $topCat";
  }
}
