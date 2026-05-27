import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart' as uuid;
import '../../database/database_helper.dart';
import '../../models/transaction_model.dart';
import '../../services/sms_service.dart';
import '../../services/settings_service.dart';
import '../../services/notification_service.dart';
import '../../services/api_service.dart';

class AppState extends ChangeNotifier {
  // Singleton pattern for easy global access
  static final AppState instance = AppState._internal();
  AppState._internal() {
    loadTransactions();
    NotificationService.initialize();
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
  bool _autoAddTransactions = true; // Mode Toggle: true = Auto, false = Manual Approval

  // Category overrides by transaction ID
  final Map<String, String> _categoryOverrides = {};

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
  bool get autoAddTransactions => _autoAddTransactions;

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
  double totalIncome = 0;
  double get netBalance => totalIncome - totalSpent;

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

  // Auto Add Transactions Mode Toggle
  void setAutoAddTransactions(bool enabled) async {
    _autoAddTransactions = enabled;
    notifyListeners();
    try {
      await SettingsService.setAutoAddTransactions(enabled);
    } catch (e) {
      debugPrint("Failed to save SMS Auto Add Mode preference: $e");
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
      _autoAddTransactions = await SettingsService.getAutoAddTransactions();
      
      final themeStr = prefs.getString('themeMode') ?? 'dark';
      _themeMode = themeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

      for (var cat in categoryLimits.keys) {
        if (prefs.containsKey('limit_$cat')) {
          categoryLimits[cat] = prefs.getDouble('limit_$cat')!;
        }
      }
    } catch (e) {
      debugPrint("Failed to load SharedPreferences: $e");
      _isOnboarded = true;
      _isProfileSetup = true;
      _userName = 'Investor';
    }

    try {
      var list = await DatabaseHelper.getTransactions();
      // Filter out autoAdded = 0 (pending approval) transactions from the primary active feed!
      transactions = list
          .map((e) => TransactionModel.fromMap(e))
          .where((tx) => tx.autoAdded == 1)
          .toList();

      // Load category overrides
      _categoryOverrides.clear();
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey('category_overrides')) {
          final String? overridesJson = prefs.getString('category_overrides');
          if (overridesJson != null) {
            final Map<String, dynamic> decoded = jsonDecode(overridesJson);
            decoded.forEach((key, value) {
              if (value is String) {
                _categoryOverrides[key] = value;
              }
            });
          }
        }
      } catch (_) {}

      // Sum credits/debits
      double spent = 0;
      double credits = 0;
      for (var tx in transactions) {
        final amt = double.tryParse(tx.amount) ?? 0.0;
        if (tx.transactionType == "credit") {
          credits += amt;
        } else {
          spent += amt;
        }
      }
      totalSpent = spent;
      totalCredits = credits;
      totalIncome = credits;
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
    final txId = strUUID();
    final tx = TransactionModel(
      id: txId,
      fingerprint: "manual_$txId",
      amount: amount.toStringAsFixed(2),
      merchant: merchant,
      category: getCategory(merchant),
      type: type,
      paymentMode: paymentMode,
      bank: bank,
      sender: "MANUAL",
      confidence: 100,
      autoAdded: 1,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      message: "Manually entered transaction of ₹${amount.toStringAsFixed(2)} at $merchant.",
    );

    await DatabaseHelper.insertTransaction(tx.toMap());
    await loadTransactions();
  }

  String strUUID() {
    return uuid.Uuid().v4();
  }

  // Add multiple transactions at once (batch insert)
  Future<void> addTransactions(List<TransactionModel> newTxs) async {
    for (var tx in newTxs) {
      await DatabaseHelper.insertTransaction(tx.toMap());
    }
    await loadTransactions();
  }

  // Approves a transaction that was in manual confirmation mode
  Future<void> approveTransaction(String txId) async {
    try {
      final db = await DatabaseHelper.getDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableName,
        where: 'id = ?',
        whereArgs: [txId],
      );
      if (maps.isNotEmpty) {
        final tx = TransactionModel.fromMap(maps.first);
        final updatedTx = TransactionModel(
          id: tx.id,
          fingerprint: tx.fingerprint,
          amount: tx.amount,
          merchant: tx.merchant,
          category: tx.category,
          type: tx.type,
          paymentMode: tx.paymentMode,
          bank: tx.bank,
          sender: tx.sender,
          confidence: tx.confidence,
          autoAdded: 1, // Set to Approved
          timestamp: tx.timestamp,
          message: tx.message,
        );
        await DatabaseHelper.updateTransaction(updatedTx.toMap());
        await loadTransactions();
        
        // Notify API
        await ApiService.approveTransaction(txId);
      }
    } catch (e) {
      debugPrint("Failed to approve transaction: $e");
    }
  }

  // Ignores/Deletes a transaction
  Future<void> ignoreTransaction(String txId) async {
    try {
      await DatabaseHelper.deleteTransaction(txId);
      await loadTransactions();
      
      // Notify API
      await ApiService.ignoreTransaction(txId);
    } catch (e) {
      debugPrint("Failed to ignore transaction: $e");
    }
  }

  // SMS Ingest Hook
  Future<void> ingestSMS(String message, String sender, BuildContext context) async {
    final tx = SMSService.parseSMS(message, sender);
    if (tx != null) {
      final localTx = TransactionModel(
        id: tx.id ?? strUUID(),
        fingerprint: tx.fingerprint,
        amount: tx.amount,
        merchant: tx.merchant,
        category: tx.category,
        type: tx.type,
        paymentMode: tx.paymentMode,
        bank: tx.bank,
        sender: tx.sender,
        confidence: tx.confidence,
        autoAdded: tx.autoAdded,
        timestamp: tx.timestamp,
        message: tx.message,
      );
      
      await DatabaseHelper.insertTransaction(localTx.toMap());
      await loadTransactions();
      
      if (alertNotificationsEnabled && context.mounted) {
        _showNotificationAlert(context, localTx);
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

  // ─── Delete all transactions only (keeps settings intact) ────────────────
  Future<void> resetAllData() async {
    await DatabaseHelper.clearTransactions();
    try {
      await ApiService.clearBackendTransactions();
      debugPrint("Backend transactions database cleared successfully.");
    } catch (e) {
      debugPrint("Failed to clear backend transactions: $e");
    }
    transactions.clear();
    totalSpent = 0;
    totalCredits = 0;
    notifyListeners();
  }

  // ─── Full app reset: wipes transactions + prefs + cache + DB file ─────────
  Future<void> resetAllAppData() async {
    // 1. Clear in-memory state
    transactions.clear();
    totalSpent = 0;
    totalCredits = 0;
    _isOnboarded = false;
    _userName = 'Investor';
    _monthlyIncome = 0.0;
    totalBudgetLimit = 8000.0;
    categoryLimits
      ..clear()
      ..addAll({
        "Food & Beverages": 3000.0,
        "Transport": 1500.0,
        "Shopping": 2000.0,
        "Entertainment": 1000.0,
        "Bills & Utilities": 1200.0,
        "Other": 800.0,
      });

    // 2. Clear SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint("Failed to clear SharedPreferences: $e");
    }

    // 3. Delete SQLite DB file from disk (forces fresh schema on next launch)
    try {
      await DatabaseHelper.deleteDatabaseFileStatic();
      debugPrint("SQLite DB file deleted safely using helper.");
    } catch (e) {
      debugPrint("Failed to delete DB file: $e");
    }

    // 3b. Clear backend database as well
    try {
      await ApiService.clearBackendTransactions();
      debugPrint("Backend transactions database cleared successfully.");
    } catch (e) {
      debugPrint("Failed to clear backend transactions: $e");
    }

    // 4. Wipe file_picker cache directory
    try {
      final cacheRoot = Directory('/data/user/0/com.example.spendify/cache/file_picker');
      if (await cacheRoot.exists()) {
        await cacheRoot.delete(recursive: true);
        debugPrint("file_picker cache cleared.");
      }
    } catch (e) {
      debugPrint("Failed to clear file_picker cache: $e");
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
  String getCategory(String merchant, [String? txId]) {
    if (txId != null && _categoryOverrides.containsKey(txId)) {
      return _categoryOverrides[txId]!;
    }
    if (txId != null) {
      final match = transactions.firstWhere(
        (t) => t.id == txId,
        orElse: () => TransactionModel(
          id: '', fingerprint: '', amount: '', merchant: '', category: '', type: '', paymentMode: '', bank: '', sender: '', confidence: 0, autoAdded: 0, timestamp: 0, message: ''
        ),
      );
      if (match.id != null && match.id!.isNotEmpty && match.category.isNotEmpty && match.category != 'Other') {
        return match.category;
      }
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
      return "Food & Beverages";
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
        m.contains('payroll') ||
        m.contains('credited salary') ||
        m.contains('salary-tcs') ||
        m.contains('salary transfer') ||
        m.contains('income')) {
      return "Income";
    } else if (m.contains('credits') ||
        m.contains('dividend')) {
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
    return "Entertainment";
  }

  Future<void> setCategoryOverride(String txId, String category) async {
    _categoryOverrides[txId] = category;
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> stringMap = _categoryOverrides.map((k, v) => MapEntry(k, v));
      await prefs.setString('category_overrides', jsonEncode(stringMap));
    } catch (e) {
      debugPrint("Failed to save category override to SharedPreferences: $e");
    }
    // Recalculate spent totals
    double spent = 0;
    double credits = 0;
    for (var tx in transactions) {
      final amt = double.tryParse(tx.amount) ?? 0.0;
      if (tx.transactionType == "debit") {
        spent += amt;
      } else {
        credits += amt;
      }
    }
    totalSpent = spent;
    totalCredits = credits;
    notifyListeners();
  }

  Future<void> updateTransactionCategory(String txId, String category) async {
    await setCategoryOverride(txId, category);
  }

  Future<void> deleteTransaction(String txId) async {
    await DatabaseHelper.deleteTransaction(txId);
    _categoryOverrides.remove(txId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> stringMap = _categoryOverrides.map((k, v) => MapEntry(k, v));
      await prefs.setString('category_overrides', jsonEncode(stringMap));
      await prefs.remove('override_$txId');
    } catch (_) {}
    await loadTransactions();
  }

  // Compute spend for specific category
  double getCategorySpend(String category) {
    double spent = 0;
    for (var tx in transactions) {
      if (tx.transactionType == "debit" && getCategory(tx.merchant, tx.id) == category) {
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
                    tx.autoAdded == 1 ? "Transaction Auto-Added" : "Transaction Detected",
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
        if (tx.transactionType == "debit" && 
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
      if (tx.transactionType == "debit") {
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
      if (tx.transactionType == "debit") {
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
      if (tx.transactionType == "debit" && tx.timestamp >= todayStart) {
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
