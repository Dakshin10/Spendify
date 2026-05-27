import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/transaction_model.dart';
import '../../services/sms_service.dart';
import '../../core/theme/custom_animations.dart';
import '../../core/utils/formatters.dart';
import '../transactions/transaction_detail_sheet.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../csv_upload/csv_upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isSearchOverlayActive = false;
  
  // Animation for the AI teaser sparkle
  late AnimationController _sparkleController;

  // Seed recent searches
  final List<String> _recentSearches = ["Food", "Uber", "Swiggy", "Netflix", "Shopping"];

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  // Gets the appropriate greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning,";
    } else if (hour < 17) {
      return "Good afternoon,";
    } else {
      return "Good evening,";
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  final Map<String, String> _categoryEmojis = {
    "Food & Beverages": "🍔",
    "Transport": "🚗",
    "Shopping": "🛍️",
    "Entertainment": "🎮",
    "Bills & Utilities": "💡",
    "Other": "📦",
    "Credits": "💰",
  };

  final Map<String, Color> _categoryColors = {
    "Food & Beverages": const Color(0xFFFF9500),
    "Transport": const Color(0xFF007AFF),
    "Shopping": const Color(0xFFFF2D55),
    "Entertainment": const Color(0xFFAF52DE),
    "Bills & Utilities": const Color(0xFFFFCC00),
    "Other": const Color(0xFF8E8E93),
    "Credits": const Color(0xFF34C759),
  };

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, child) {
        final state = AppState.instance;

        // Extract stats
        final totalLimit = state.totalBudgetLimit;
        final totalSpent = state.totalSpent;
        final remaining = (totalLimit - totalSpent) < 0 ? 0.0 : (totalLimit - totalSpent);
        final spentPct = totalLimit > 0 ? (totalSpent / totalLimit * 100).clamp(0.0, 100.0) : 0.0;
        final remainingPct = 100.0 - spentPct;

        // Daily rotating one-liners
        final int dayIndex = DateTime.now().day % 3;
        String smartOneLiner = "";
        if (dayIndex == 0) {
          smartOneLiner = "You've spent ₹${formatIndianRupees(totalSpent)} so far this month 💸";
        } else if (dayIndex == 1) {
          smartOneLiner = "₹${formatIndianRupees(remaining)} left in your budget. Keep it up! 💪";
        } else {
          // Find highest today transaction
          final todayStart = DateUtils.dateOnly(DateTime.now()).millisecondsSinceEpoch;
          double maxTodayVal = 0.0;
          String maxTodayMerchant = "";
          for (var tx in state.transactions) {
            if (tx.type == "DEBIT" && tx.timestamp >= todayStart) {
              final val = double.tryParse(tx.amount) ?? 0.0;
              if (val > maxTodayVal) {
                maxTodayVal = val;
                maxTodayMerchant = tx.merchant;
              }
            }
          }
          if (maxTodayVal > 0) {
            smartOneLiner = "Your biggest spend today was ₹${formatIndianRupees(maxTodayVal)} at $maxTodayMerchant 🏪";
          } else {
            smartOneLiner = "You haven't spent anything today. Clean record! ✨";
          }
        }

        // Today's spend summation details
        final todayStart = DateUtils.dateOnly(DateTime.now()).millisecondsSinceEpoch;
        double todaySpentSum = 0.0;
        int todayCount = 0;
        double maxSpentToday = 0.0;
        String maxMerchantToday = "";
        for (var tx in state.transactions) {
          if (tx.type == "DEBIT" && tx.timestamp >= todayStart) {
            todayCount++;
            final val = double.tryParse(tx.amount) ?? 0.0;
            todaySpentSum += val;
            if (val > maxSpentToday) {
              maxSpentToday = val;
              maxMerchantToday = tx.merchant;
            }
          }
        }

        return PopScope(
          canPop: !_isSearchOverlayActive,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isSearchOverlayActive = false;
                });
              }
            });
          },
          child: Scaffold(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          body: Stack(
            children: [
              // Main content
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Top Bar
                      _buildTopBar(context, user, isDark),
                      const SizedBox(height: 24),

                      // Greeting Section
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 0),
                        child: Text(
                          _getGreeting(),
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 40),
                        child: Text(
                          state.userName.isNotEmpty
                              ? _toTitleCase(state.userName)
                              : (user?.email != null ? _toTitleCase(user!.email!.split('@')[0]) : "User"),
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 80),
                        child: Text(
                          smartOneLiner,
                          style: TextStyle(
                            color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 1. Monthly Overview Card
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: _buildMonthlyOverviewCard(isDark, totalSpent, remaining, spentPct, remainingPct),
                      ),
                      const SizedBox(height: 20),

                      // 2. Today's Spend Card
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 140),
                        child: _buildTodaysSpendCard(isDark, todaySpentSum, todayCount, maxSpentToday, maxMerchantToday),
                      ),
                      const SizedBox(height: 24),

                      // 3. Quick Action Row
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 180),
                        child: _buildQuickActions(context, isDark),
                      ),
                      const SizedBox(height: 24),

                      // 4. AI Chat Teaser Card
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 220),
                        child: _buildAIChatTeaser(context, isDark),
                      ),
                      const SizedBox(height: 28),

                      // Recent Transactions Section Header
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 240),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Recent Transactions",
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () => state.setTab(1),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "View All ",
                                    style: TextStyle(
                                      color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                                    size: 13,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 5. Recent Transactions List
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 280),
                        child: state.transactions.isEmpty
                            ? _buildEmptyState(context, isDark)
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.transactions.length > 5 ? 5 : state.transactions.length,
                                separatorBuilder: (context, index) => Divider(
                                  color: Colors.white.withOpacity(0.06),
                                  height: 1,
                                  thickness: 0.5,
                                ),
                                itemBuilder: (context, index) {
                                  final tx = state.transactions[index];
                                  return _buildTransactionRow(context, tx, isDark);
                                },
                              ),
                      ),
                      
                      const SizedBox(height: 100), // Padding for floating nav bar
                    ],
                  ),
                ),
              ),

              // Search full-screen overlay
              if (_isSearchOverlayActive)
                _buildSearchOverlay(context, state, isDark),
            ],
          ),
        ),
      );
      },
    );
  }

  // Top Bar Builder
  Widget _buildTopBar(BuildContext context, User? user, bool isDark) {
    final avatarColor = isDark ? AppColors.accentNeon : AppColors.lightGradient[0];
    final avatarBgColor = isDark ? const Color(0xFF141A15) : const Color(0xFFE8F5E9);
    final initials = AppState.instance.userName.isNotEmpty
        ? AppState.instance.userName.substring(0, 1).toUpperCase()
        : (user?.email != null ? user!.email![0].toUpperCase() : "U");

    return Row(
      children: [
        // Search bar disguises as input pill
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isSearchOverlayActive = true;
                _searchQuery = "";
                _searchController.clear();
              });
              HapticFeedback.lightImpact();
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161616) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Search transactions...",
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // User profile initials circle
        SpringScaleButton(
          scaleDownFactor: 0.97,
          onTap: () => AppState.instance.setTab(4),
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarBgColor,
              border: Border.all(
                color: avatarColor,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Monthly Overview Card Builder
  Widget _buildMonthlyOverviewCard(
      bool isDark, double totalSpent, double remaining, double spentPct, double remainingPct) {
    final totalLimit = AppState.instance.totalBudgetLimit;
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0C150E), const Color(0xFF122215)]
              : [const Color(0xFF0F6038), const Color(0xFF1B8D56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Decorative Watermark (Faded Circle bottom right)
          Positioned(
            right: -24,
            bottom: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(isDark ? 0.02 : 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Monthly Overview",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "May 2026 ▾",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                
                // Spent counter amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "₹",
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    CountUpText(
                      value: totalSpent,
                      prefix: "",
                      style: GoogleFonts.outfit(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Spent: ₹${formatIndianRupees(totalSpent)}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "Remaining: ₹${formatIndianRupees(remaining)}",
                      style: TextStyle(
                        color: isDark ? AppColors.accentNeon : const Color(0xFFA3FFC6),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                // Linear progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalSpent / (totalLimit > 0 ? totalLimit : 1.0)).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.accentNeon : Colors.white,
                    ),
                  ),
                ),

                // Spent / Remaining Pills
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${spentPct.toStringAsFixed(0)}% Spent",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${remainingPct.toStringAsFixed(0)}% Left",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Today's Spend Card Builder
  Widget _buildTodaysSpendCard(bool isDark,double todaySpent,int count,double maxSpent,String maxMerchant,) {
    final hasData = count > 0;

    return Container(
      width: double.infinity,

      // ✅ REMOVED FIXED HEIGHT
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF161616)
            : AppColors.lightCardBg,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.lightShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        // ✅ FIX
        mainAxisSize: MainAxisSize.min,

        children: [
          Text(
            "Today's Spend",
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.6) : AppColors.lightTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          if (!hasData) ...[
            Text(
              "No spends logged today — you're good! ✨",

              maxLines: 2,
              overflow: TextOverflow.ellipsis,

              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.8) : AppColors.lightTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ] else ...[
            // ✅ AMOUNT ROW
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),

                const SizedBox(width: 2),

                Expanded(
                  child: CountUpText(
                    value: todaySpent,
                    prefix: "",
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ✅ FIXED OVERFLOW TEXT
            Text(
              "$count transactions · Highest: ₹${formatIndianRupees(maxSpent)} at $maxMerchant",

              maxLines: 2,
              overflow: TextOverflow.ellipsis,

              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.5) : AppColors.lightTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ]
        ],
      ),
    );
  }

  // Quick Action Buttons — adapts based on SMS tracking state
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final state = AppState.instance;
    final smsOn = state.smsTrackingEnabled;
    final primaryColor = isDark ? AppColors.accentNeon : AppColors.lightGradient[0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Adaptive Add button
            _buildQuickActionButton(
              label: smsOn ? "Add Cash" : "Add",
              icon: smsOn ? Icons.payments_rounded : Icons.add_rounded,
              isDark: isDark,
              isAccent: smsOn, // highlighted when it's the only manual entry option
              onTap: () {
                if (smsOn) {
                  _showAddCashSheet(context);
                } else {
                  _showManualTransactionSheet(context);
                }
              },
            ),
            const SizedBox(width: 12),
            _buildQuickActionButton(
              label: "Subscription",
              icon: Icons.autorenew_rounded,
              isDark: isDark,
              onTap: () => _showSubscriptionsDialog(context),
            ),
            const SizedBox(width: 12),
            _buildQuickActionButton(
              label: "Alerts",
              icon: Icons.notifications_none_rounded,
              isDark: isDark,
              onTap: () => _showSMSSimulatorSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // SMS Status Indicator
        GestureDetector(
          onTap: () => AppState.instance.setTab(4), // navigate to profile/settings
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: smsOn
                  ? (isDark ? const Color(0xFF0A2B18) : const Color(0xFFE8F5E9))
                  : (isDark ? const Color(0xFF2A1A0A) : const Color(0xFFFFF3E0)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: smsOn
                    ? (isDark ? AppColors.accentNeon.withOpacity(0.25) : AppColors.lightGradient[0].withOpacity(0.3))
                    : Colors.orange.withOpacity(0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  smsOn ? Icons.sms_rounded : Icons.sms_failed_rounded,
                  size: 13,
                  color: smsOn ? primaryColor : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  smsOn
                      ? "SMS auto-tracking on · UPI & Card detected automatically"
                      : "SMS tracking off · Add all transactions manually",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: smsOn
                        ? (isDark ? AppColors.accentNeon : AppColors.lightGradient[0])
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 13,
                  color: smsOn ? primaryColor : Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    final primaryColor = isDark ? AppColors.accentNeon : AppColors.lightGradient[0];
    return Expanded(
      child: SpringScaleButton(
        scaleDownFactor: 0.94,
        onTap: () {
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: isAccent
                ? primaryColor.withOpacity(isDark ? 0.12 : 0.08)
                : (isDark ? const Color(0xFF161616) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAccent
                  ? primaryColor.withOpacity(0.35)
                  : (isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder),
              width: isAccent ? 1.2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isAccent ? primaryColor : (isDark ? Colors.white : AppColors.lightTextPrimary),
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isAccent ? FontWeight.w700 : FontWeight.w500,
                  color: isAccent ? primaryColor : (isDark ? Colors.white : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // AI Chat Teaser Card
  Widget _buildAIChatTeaser(BuildContext context, bool isDark) {
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;
    return SpringScaleButton(
      scaleDownFactor: 0.98, // card scale 0.98
      onTap: () {
        Navigator.push(context, AppPageTransitions.buildParallaxRoute(const AIChatScreen()));
      },
      child: Container(
        height: 72,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            // Left sparkle icon looping pulse
            ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.15).animate(
                CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentNeon,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Center description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Ask AI anything about your spending →",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Try: 'Where did I overspend this week?'",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Right Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // Transaction row (72px tall)
  Widget _buildTransactionRow(BuildContext context, TransactionModel tx, bool isDark) {
    final category = AppState.instance.getCategory(tx.merchant, tx.id);
    final emoji = _categoryEmojis[category] ?? "📝";
    final categoryColor = _categoryColors[category] ?? const Color(0xFF8E8E93);
    final isDebit = tx.type == "DEBIT";

    final txDate = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    final timeStr = "${txDate.hour.toString().padLeft(2, '0')}:${txDate.minute.toString().padLeft(2, '0')}";
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final dateStr = "${txDate.day} ${months[txDate.month - 1]}";

    final amtVal = double.tryParse(tx.amount) ?? 0.0;
    final formattedAmt = formatIndianRupees(amtVal);

    final showSMSBadge = tx.sender != "MANUAL" && tx.sender != "CSV";

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        TransactionDetailSheet.show(context, tx);
      },
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Left Category icon (44x44 rounded square)
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: categoryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Center details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          tx.merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      if (showSMSBadge) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0A2B18) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? AppColors.accentNeon.withOpacity(0.3) : AppColors.lightGradient[0].withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            "SMS",
                            style: TextStyle(
                              color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "$category · $dateStr, $timeStr",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Right amount column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${isDebit ? '–' : '+'}${'₹'}$formattedAmt",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDebit ? AppColors.errorRed : AppColors.successGreen,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tx.bank,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Empty state for transactions
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Slept phone icon
          Icon(
            Icons.hotel_rounded,
            size: 48,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            "Nothing here yet 😴",
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Upload a CSV or your first bank SMS will appear here automatically",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SpringScaleButton(
            scaleDownFactor: 0.97,
            onTap: () {
              Navigator.push(context, AppPageTransitions.buildParallaxRoute(const CSVUploadScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Upload a CSV",
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Full screen Search Overlay
  Widget _buildSearchOverlay(BuildContext context, AppState state, bool isDark) {
    final overlayBgColor = isDark ? const Color(0xFF080808) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;
    final textTheme = isDark ? Colors.white : Colors.black;

    // Filter transactions
    final matchingTx = state.transactions.where((tx) {
      final query = _searchQuery.toLowerCase();
      final cat = state.getCategory(tx.merchant, tx.id).toLowerCase();
      return tx.merchant.toLowerCase().contains(query) ||
          cat.contains(query) ||
          tx.amount.contains(query);
    }).toList();

    return Positioned.fill(
      child: Container(
        color: overlayBgColor,
        child: SafeArea(
            child: Column(
              children: [
                // Top Search Bar Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearchOverlayActive = false;
                          });
                        },
                      ),
                      
                      // Search Input Field
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161616) : const Color(0xFFF1F3F1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: TextStyle(color: textTheme),
                            decoration: InputDecoration(
                              hintText: "Search merchant, category, amount...",
                              hintStyle: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Divider(color: borderColor, height: 1),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Recent Searches (Only show when search query is empty)
                      if (_searchQuery.isEmpty) ...[
                        Text(
                          "Recent Searches",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _recentSearches.map((term) {
                            return ChoiceChip(
                              label: Text(term),
                              selected: false,
                              onSelected: (_) {
                                setState(() {
                                  _searchQuery = term;
                                  _searchController.text = term;
                                });
                              },
                              backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF1F3F1),
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 13,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Search Results Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _searchQuery.isEmpty ? "All Transactions" : "Matching Results",
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          Text(
                            "${matchingTx.length} found",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Search List
                      matchingTx.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40.0),
                              child: Column(
                                children: [
                                  Icon(Icons.search_off_rounded, size: 40, color: labelColor(isDark)),
                                  const SizedBox(height: 12),
                                  Text(
                                    "No matches found",
                                    style: TextStyle(color: labelColor(isDark), fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: matchingTx.length,
                              separatorBuilder: (context, index) => Divider(
                                color: Colors.white.withOpacity(0.06),
                                height: 1,
                                thickness: 0.5,
                              ),
                              itemBuilder: (context, index) {
                                final tx = matchingTx[index];
                                return _buildTransactionRow(context, tx, isDark);
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Color labelColor(bool isDark) {
    return isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  }

  // 0. Cash-only quick add bottom sheet (shown when SMS tracking is ON)
  void _showAddCashSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final amtController = TextEditingController();
    final merchantController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.accentNeon : AppColors.lightGradient[0];

    String txType = "DEBIT";
    String selectedCategory = "Other";
    DateTime selectedDate = DateTime.now();

    final List<Map<String, dynamic>> categoryOptions = [
      {"label": "Food 🍔", "key": "Food & Beverages"},
      {"label": "Transport 🚗", "key": "Transport"},
      {"label": "Shopping 🛍️", "key": "Shopping"},
      {"label": "Bills 💡", "key": "Bills & Utilities"},
      {"label": "Entertainment 🎮", "key": "Entertainment"},
      {"label": "Other 📦", "key": "Other"},
    ];

    final months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 20),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.payments_rounded, color: primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Add Cash Payment",
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 0.8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.money_rounded, size: 10, color: primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Cash · Not tracked by SMS",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : Colors.black45),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Amount Input
                    TextFormField(
                      controller: amtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        prefixText: "₹  ",
                        prefixStyle: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Enter an amount";
                        if (double.tryParse(val.trim()) == null) return "Enter a valid number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Merchant / Description
                    TextFormField(
                      controller: merchantController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: "Where did you pay? (e.g. Chai stall)",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.store_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Enter merchant name";
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Expense / Income Toggle
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => txType = "DEBIT"),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: txType == "DEBIT"
                                    ? AppColors.errorRed.withOpacity(0.12)
                                    : (isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: txType == "DEBIT" ? AppColors.errorRed.withOpacity(0.5) : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: txType == "DEBIT" ? AppColors.errorRed : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Expense",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: txType == "DEBIT" ? FontWeight.w700 : FontWeight.w400,
                                      color: txType == "DEBIT" ? AppColors.errorRed : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => txType = "CREDIT"),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: txType == "CREDIT"
                                    ? AppColors.successGreen.withOpacity(0.12)
                                    : (isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: txType == "CREDIT" ? AppColors.successGreen.withOpacity(0.5) : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 16,
                                    color: txType == "CREDIT" ? AppColors.successGreen : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Income",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: txType == "CREDIT" ? FontWeight.w700 : FontWeight.w400,
                                      color: txType == "CREDIT" ? AppColors.successGreen : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Category chips
                    Text(
                      "Category",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categoryOptions.map((cat) {
                        final isSelected = selectedCategory == cat['key'];
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedCategory = cat['key']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withOpacity(isDark ? 0.15 : 0.1)
                                  : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? primaryColor.withOpacity(0.5) : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              cat['label'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                color: isSelected
                                    ? primaryColor
                                    : (isDark ? Colors.white60 : Colors.black54),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Date picker row
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: primaryColor,
                                onPrimary: isDark ? Colors.black : Colors.white,
                                surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setSheetState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16,
                                color: isDark ? Colors.white54 : Colors.black45),
                            const SizedBox(width: 10),
                            Text(
                              "${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.edit_calendar_rounded, size: 14,
                                color: isDark ? Colors.white30 : Colors.black26),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            HapticFeedback.mediumImpact();
                            final amt = double.parse(amtController.text.trim());
                            final merchant = merchantController.text.trim();
                            await AppState.instance.addManualTransaction(
                              amount: amt,
                              merchant: merchant,
                              type: txType,
                              paymentMode: "Cash",
                              bank: "Cash",
                              timestamp: selectedDate.millisecondsSinceEpoch,
                            );
                            // Override category immediately
                            final addedTx = AppState.instance.transactions.isNotEmpty
                                ? AppState.instance.transactions.first
                                : null;
                            if (addedTx?.id != null && selectedCategory != "Other") {
                              await AppState.instance.setCategoryOverride(addedTx!.id!, selectedCategory);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Save Cash Payment",
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 1. Manual Transaction Entry Bottom Sheet
  void _showManualTransactionSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final amtController = TextEditingController();
    final merchantController = TextEditingController();
    String txType = "DEBIT";
    String paymentMode = "UPI";
    String bankName = "HDFC Bank";

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "New Transaction",
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Amount Input
                    TextFormField(
                      controller: amtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Amount (₹)",
                        labelStyle: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Please enter amount";
                        if (double.tryParse(val.trim()) == null) return "Please enter a valid number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Merchant Input
                    TextFormField(
                      controller: merchantController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Merchant Name",
                        labelStyle: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        prefixIcon: const Icon(Icons.store_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Please enter merchant name";
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // Type Selection (Debit / Credit)
                    const Text(
                      "Transaction Type",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text("Expense"),
                            selected: txType == "DEBIT",
                            onSelected: (selected) {
                              if (selected) setSheetState(() => txType = "DEBIT");
                            },
                            selectedColor: AppColors.errorRed.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: txType == "DEBIT" ? AppColors.errorRed : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text("Income"),
                            selected: txType == "CREDIT",
                            onSelected: (selected) {
                              if (selected) setSheetState(() => txType = "CREDIT");
                            },
                            selectedColor: AppColors.successGreen.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: txType == "CREDIT" ? AppColors.successGreen : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Payment Mode Dropdown
                    DropdownButtonFormField<String>(
                      value: paymentMode,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF161616) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Payment Mode",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: const [
                        DropdownMenuItem(value: "UPI", child: Text("UPI")),
                        DropdownMenuItem(value: "Card", child: Text("Card")),
                        DropdownMenuItem(value: "Bank Transfer", child: Text("Bank Transfer")),
                        DropdownMenuItem(value: "Cash", child: Text("Cash")),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => paymentMode = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Bank Name Dropdown
                    DropdownButtonFormField<String>(
                      value: bankName,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF161616) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Bank Account",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: const [
                        DropdownMenuItem(value: "HDFC Bank", child: Text("HDFC Bank")),
                        DropdownMenuItem(value: "SBI", child: Text("SBI Bank")),
                        DropdownMenuItem(value: "ICICI Bank", child: Text("ICICI Bank")),
                        DropdownMenuItem(value: "Axis Bank", child: Text("Axis Bank")),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => bankName = val);
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final amt = double.parse(amtController.text.trim());
                            final merchant = merchantController.text.trim();
                            await AppState.instance.addManualTransaction(
                              amount: amt,
                              merchant: merchant,
                              type: txType,
                              paymentMode: paymentMode,
                              bank: bankName,
                            );
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        child: Text(
                          "Save Transaction",
                          style: AppTextStyles.button.copyWith(
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. Subscriptions Dialog
  void _showSubscriptionsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = AppState.instance;
    final subs = state.getSubscriptions();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              isDark ? const Color(0xFF1E1E1E) : Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),

          // ✅ FIXED TITLE
          title: Row(
            children: [
              const Icon(
                Icons.autorenew_rounded,
                color: AppColors.accentNeon,
                size: 22,
              ),

              const SizedBox(width: 8),

              // ✅ EXPANDED FIX
              Expanded(
                child: Text(
                  "Recurring Subscriptions",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),

          // ✅ FIXED CONTENT
          content: SizedBox(
            width: double.maxFinite,

            child: subs.isEmpty
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 24.0),

                    child: Text(
                      "No active recurring subscriptions detected in your transactions.",

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        color:
                            isDark ? Colors.grey : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  )

                : ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 350,
                    ),

                    child: ListView.separated(
                      shrinkWrap: true,

                      itemCount: subs.length,

                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),

                      itemBuilder: (context, index) {
                        final sub = subs[index];

                        return Container(
                          padding: const EdgeInsets.all(14),

                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF161616)
                                : const Color(0xFFF5F5F5),

                            borderRadius:
                                BorderRadius.circular(16),
                          ),

                          child: Row(
                            children: [
                              Container(
                                height: 42,
                                width: 42,

                                decoration: BoxDecoration(
                                  color: AppColors.accentNeon
                                      .withOpacity(0.12),

                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),

                                child: const Icon(
                                  Icons.subscriptions_rounded,
                                  color: AppColors.accentNeon,
                                  size: 20,
                                ),
                              ),

                              const SizedBox(width: 12),

                              // ✅ EXPANDED FIX
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      sub['name']!,

                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,

                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors
                                                .lightTextPrimary,
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      "Recurring Payment",

                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,

                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors
                                                .darkTextSecondary
                                            : AppColors
                                                .lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // ✅ FLEXIBLE PRICE
                              Flexible(
                                child: Text(
                                  sub['price']!,

                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,

                                  textAlign: TextAlign.end,

                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w700,
                                    color: AppColors.errorRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),

          actionsPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),

          actions: [
            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.accentNeon
                      : AppColors.lightGradient[0],

                  foregroundColor:
                      isDark ? Colors.black : Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),

                onPressed: () => Navigator.pop(context),

                child: Text(
                  "Close",

                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubTile(String name, String price, bool isDark) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.subscriptions_rounded, color: Colors.redAccent, size: 18),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      trailing: Text(
        price,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
      ),
    );
  }

  // 3. SMS Simulator Bottom Sheet
  void _showSMSSimulatorSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mocks = SMSService.getMockSMSList();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SMS Simulation Center",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        "Simulate bank messages to test parsing",
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: mocks.length,
                  itemBuilder: (context, index) {
                    final item = mocks[index];
                    return Card(
                      color: isDark ? const Color(0xFF161616) : const Color(0xFFF1F3F1),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          Navigator.pop(context);
                          await AppState.instance.ingestSMS(
                            item['message']!,
                            item['sender']!,
                            context,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['sender']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Text(
                                    "Tap to Sim Ingest",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['message']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}