import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/custom_animations.dart';


class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with TickerProviderStateMixin {
  late AnimationController _chartAnimationController;
  late Animation<double> _chartCurve;
  
  late AnimationController _swapRotationController;

  int _activeSparkIndex = -1;
  int _highlightedDonutIndex = -1; // Tap legend to highlight donut segment

  @override
  void initState() {
    super.initState();
    _chartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _chartCurve = CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.easeInOutCubic,
    );
    
    _swapRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _chartAnimationController.forward();
    _swapRotationController.forward();
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    _swapRotationController.dispose();
    super.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, child) {
        final state = AppState.instance;

        // Fetch spends from AppState
        final foodSpend = state.getCategorySpend("Food & Beverages");
        final transportSpend = state.getCategorySpend("Transport");
        final shopSpend = state.getCategorySpend("Shopping");
        final entSpend = state.getCategorySpend("Entertainment");
        final billsSpend = state.getCategorySpend("Bills & Utilities");
        final otherSpend = state.getCategorySpend("Other");

        final Map<String, double> spends = {
          "Food & Beverages": foodSpend,
          "Transport": transportSpend,
          "Shopping": shopSpend,
          "Entertainment": entSpend,
          "Bills & Utilities": billsSpend,
          "Other": otherSpend,
        };

        final double totalSpendsSum = spends.values.fold(0, (sum, val) => sum + val);

        // Fetch top merchants
        final topMerchants = _calculateTopMerchants(state.transactions);

        // Subscriptions
        final subs = state.getSubscriptions();

        // Sparkline trend data
        final sparkData = state.getMonthlyTrendSpends();
        final sparkMonths = state.getMonthlyTrendLabels();
        
        if (_activeSparkIndex == -1 || _activeSparkIndex >= sparkData.length) {
          _activeSparkIndex = sparkData.isNotEmpty ? sparkData.length - 1 : 0;
        }

        final thisMonthSpend = sparkData.isNotEmpty ? sparkData.last : 0.0;
        final lastMonthSpend = sparkData.length > 1 ? sparkData[sparkData.length - 2] : 0.0;

        final bool isIncrease = thisMonthSpend > lastMonthSpend;
        final double deltaPct = lastMonthSpend > 0 ? ((thisMonthSpend - lastMonthSpend).abs() / lastMonthSpend * 100) : 0.0;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                size: 20,
              ),
              onPressed: () => state.setTab(0),
            ),
            title: Text(
              "Insights",
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),



                // Today's spend message card
                FadeUpEntrance(
                  delay: const Duration(milliseconds: 60),
                  child: _buildInsightsTodayCard(isDark, state),
                ),
                const SizedBox(height: 20),

                // Monthly Comparison Card
                FadeUpEntrance(
                  delay: const Duration(milliseconds: 120),
                  child: _buildMonthlyComparisonCard(isDark, sparkData, sparkMonths, thisMonthSpend, lastMonthSpend, deltaPct, isIncrease),
                ),
                const SizedBox(height: 20),

                // Category Breakdown Card (Donut Chart)
                FadeUpEntrance(
                  delay: const Duration(milliseconds: 180),
                  child: _buildCategoryBreakdownCard(isDark, spends, totalSpendsSum),
                ),
                const SizedBox(height: 20),

                // Top Merchants Card
                FadeUpEntrance(
                  delay: const Duration(milliseconds: 240),
                  child: _buildTopMerchantsCard(isDark, topMerchants),
                ),
                const SizedBox(height: 20),

                // Savings Opportunity Card
                if (subs.isNotEmpty)
                  FadeUpEntrance(
                    delay: const Duration(milliseconds: 300),
                    child: _buildSavingsOpportunityCard(isDark, subs.length, state),
                  ),

                const SizedBox(height: 120), // Spacing for floating bottom bar
              ],
            ),
          ),
        );
      },
    );
  }



  // Today's Spend message card
  Widget _buildInsightsTodayCard(bool isDark, AppState state) {
    final todayComparison = state.getTodaySpendComparison();
    final double todaySpent = todayComparison['todaySpent'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Spend",
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (todaySpent == 0) ...[
            Text(
              "Clean slate today! Come back after your first spend 🧘",
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
              ),
            ),
          ] else ...[
            Row(
              children: [
                Text(
                  "₹",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                CountUpText(
                  value: todaySpent,
                  prefix: "",
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.getTodayTopCategory(),
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 12,
              ),
            ),
          ]
        ],
      ),
    );
  }

  // Monthly Comparison Card
  Widget _buildMonthlyComparisonCard(
      bool isDark,
      List<double> sparkData,
      List<String> sparkMonths,
      double thisMonth,
      double lastMonth,
      double pct,
      bool isIncrease) {
    
    final badgeColor = isIncrease ? AppColors.errorRed : AppColors.successGreen;
    final badgeText = "${isIncrease ? '▲' : '▼'} ${pct.toStringAsFixed(0)}% ${isIncrease ? 'more' : 'less'}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly Comparison",
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // This Month
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This Month",
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "₹",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      CountUpText(
                        value: thisMonth,
                        prefix: "",
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Swap icon / Comparison delta
              RotationTransition(
                turns: _swapRotationController,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_alt_rounded,
                    color: AppColors.successGreen,
                    size: 18,
                  ),
                ),
              ),

              // Last Month
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Last Month",
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "₹",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      CountUpText(
                        value: lastMonth,
                        prefix: "",
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Delta Comparison Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          Text(
            "7 Month Trend",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          
          // Trend Line Chart draws left to right
          AnimatedBuilder(
            animation: _chartCurve,
            builder: (context, child) {
              return SizedBox(
                height: 160,
                width: double.infinity,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (sparkData.isEmpty) return;
                    final double chartWidth = MediaQuery.of(context).size.width - 88;
                    final double step = chartWidth / (sparkData.length - 1);
                    final double localX = (details.localPosition.dx - 45.0).clamp(0.0, chartWidth);
                    final int index = (localX / step).round();
                    if (index >= 0 && index < sparkData.length && index != _activeSparkIndex) {
                      setState(() {
                        _activeSparkIndex = index;
                      });
                    }
                  },
                  child: CustomPaint(
                    painter: TrendLinePainter(
                      data: sparkData,
                      labels: sparkMonths,
                      activeIndex: _activeSparkIndex,
                      animationValue: _chartCurve.value,
                      isDark: isDark,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Category Breakdown Card (Donut Chart)
  Widget _buildCategoryBreakdownCard(bool isDark, Map<String, double> spends, double totalSum) {
    // Standardize list of categories for donut arcs
    final nonZeroSpends = spends.entries.where((e) => e.value > 0 && e.key != "Credits").toList();
    if (nonZeroSpends.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Text("No transactions recorded yet to build breakdown."),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Category Breakdown",
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                "Total Categories: ${nonZeroSpends.length}",
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Total Spendings: ₹${formatIndianRupees(totalSum)}",
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Donut Chart Draws Clockwise on Entrance
          Center(
            child: AnimatedBuilder(
              animation: _chartCurve,
              builder: (context, child) {
                return SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    painter: DonutChartPainter(
                      spends: nonZeroSpends,
                      totalSum: totalSum,
                      animationValue: _chartCurve.value,
                      highlightIndex: _highlightedDonutIndex,
                      categoryColors: _categoryColors,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Total Spend",
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₹${formatIndianRupees(totalSum)}",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
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
          const SizedBox(height: 24),

          // Interactive legend list
          Column(
            children: List.generate(nonZeroSpends.length, (idx) {
              final entry = nonZeroSpends[idx];
              final cat = entry.key;
              final amt = entry.value;
              final pct = totalSum > 0 ? (amt / totalSum) : 0.0;
              
              final emoji = _categoryEmojis[cat] ?? "📝";
              final color = _categoryColors[cat] ?? Colors.grey;
              final isHighlighted = _highlightedDonutIndex == idx;

              return SpringScaleButton(
                scaleDownFactor: 0.98,
                onTap: () {
                  setState(() {
                    if (_highlightedDonutIndex == idx) {
                      _highlightedDonutIndex = -1; // Toggle off
                    } else {
                      _highlightedDonutIndex = idx;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? color.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHighlighted ? color.withOpacity(0.3) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "₹${formatIndianRupees(amt)}",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "${(pct * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Top Merchants Card
  Widget _buildTopMerchantsCard(bool isDark, List<Map<String, dynamic>> merchants) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Top Merchants This Month",
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          if (merchants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text("No merchants tracked this month."),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: merchants.length > 5 ? 5 : merchants.length,
              separatorBuilder: (context, index) => Divider(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                height: 1,
                thickness: 0.5,
              ),
              itemBuilder: (context, index) {
                final item = merchants[index];
                final String name = item['merchant'];
                final double total = item['total'];
                final int count = item['count'];
                final String category = item['category'];
                
                final emoji = _categoryEmojis[category] ?? "🏪";
                final color = _categoryColors[category] ?? Colors.grey;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      // Emoji container square
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Merchant Name & category badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Total Spent + count
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${formatIndianRupees(total)}",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$count transaction${count > 1 ? 's' : ''}",
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Savings Opportunity Card
  Widget _buildSavingsOpportunityCard(bool isDark, int count, AppState state) {
    double totalSubsCost = 0.0;
    final subs = state.getSubscriptions();
    for (var sub in subs) {
      final cleanPrice = sub['price']!.replaceAll(RegExp(r'\D'), '');
      totalSubsCost += double.tryParse(cleanPrice) ?? 0.0;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.lightbulb_outline_rounded, color: AppColors.successGreen, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Savings Tip",
                      style: TextStyle(
                        color: AppColors.successGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "You have $count recurring subscriptions you haven't reviewed in 30+ days. Cancelling them could save you up to ₹${formatIndianRupees(totalSubsCost)}/month.",
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SpringScaleButton(
            scaleDownFactor: 0.97,
            onTap: () {
              HapticFeedback.lightImpact();
              // Trigger dialog containing sub detail row review
              state.setTab(0); // Go back home so they can review alert simulator
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.successGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "Review Subscriptions →",
                  style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Calculate top merchants
  List<Map<String, dynamic>> _calculateTopMerchants(List<TransactionModel> txList) {
    final Map<String, Map<String, dynamic>> group = {};
    for (var tx in txList) {
      if (tx.type != "DEBIT") continue;
      final double amt = double.tryParse(tx.amount) ?? 0.0;
      final category = AppState.instance.getCategory(tx.merchant, tx.id);
      
      if (!group.containsKey(tx.merchant)) {
        group[tx.merchant] = {
          "merchant": tx.merchant,
          "total": 0.0,
          "count": 0,
          "category": category,
        };
      }
      group[tx.merchant]!['total'] = group[tx.merchant]!['total'] + amt;
      group[tx.merchant]!['count'] = group[tx.merchant]!['count'] + 1;
    }
    
    final sorted = group.values.toList()
      ..sort((a, b) => b['total'].compareTo(a['total']));
      
    return sorted;
  }
}

// Donut Chart Custom Painter draws clockwise on entrance
class DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> spends;
  final double totalSum;
  final double animationValue;
  final int highlightIndex;
  final Map<String, Color> categoryColors;

  DonutChartPainter({
    required this.spends,
    required this.totalSum,
    required this.animationValue,
    required this.highlightIndex,
    required this.categoryColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius - 15);
    const strokeW = 16.0;

    double startAngle = -pi / 2; // Start from top 12 o'clock

    for (int i = 0; i < spends.length; i++) {
      final entry = spends[i];
      final double val = entry.value;
      final pct = totalSum > 0 ? (val / totalSum) : 0.0;
      final double sweepAngle = pct * 2 * pi * animationValue;
      
      final color = categoryColors[entry.key] ?? Colors.grey;
      final isHighlighted = highlightIndex == i;

      final paint = Paint()
        ..color = isHighlighted ? color : color.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? strokeW + 4 : strokeW
        ..strokeCap = StrokeCap.butt;

      // Glow shadow if highlighted
      if (isHighlighted) {
        canvas.drawArc(
          rect,
          startAngle,
          sweepAngle,
          false,
          Paint()
            ..color = color.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW + 8
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.highlightIndex != highlightIndex ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.spends != spends;
  }
}

// Trend Line Custom Painter draws smooth curves and animates left-to-right
class TrendLinePainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int activeIndex;
  final double animationValue;
  final bool isDark;

  TrendLinePainter({
    required this.data,
    required this.labels,
    required this.activeIndex,
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Define dimensions and padding
    const double paddingLeft = 45.0;
    const double paddingRight = 20.0;
    const double paddingTop = 20.0;
    const double paddingBottom = 20.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Find min and max
    double minVal = data.reduce(min);
    double maxVal = data.reduce(max);
    if (maxVal == minVal) {
      maxVal += 1.0;
    }

    // Helper to format rupees for axes
    String formatRupees(double val) {
      if (val >= 100000) {
        return "₹${(val / 100000).toStringAsFixed(1)}L";
      } else if (val >= 1000) {
        return "₹${(val / 1000).toStringAsFixed(0)}K";
      }
      return "₹${val.toStringAsFixed(0)}";
    }

    // Draw grid lines and y-axis labels
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw min / max label on Y axis
    final axisTextStyle = TextStyle(
      color: isDark ? Colors.white54 : Colors.black54,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    // Max line
    canvas.drawLine(
      Offset(paddingLeft, paddingTop),
      Offset(size.width - paddingRight, paddingTop),
      gridPaint,
    );
    textPainter.text = TextSpan(text: formatRupees(maxVal), style: axisTextStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(5, paddingTop - textPainter.height / 2));

    // Mid line
    final double midY = paddingTop + chartHeight / 2;
    canvas.drawLine(
      Offset(paddingLeft, midY),
      Offset(size.width - paddingRight, midY),
      gridPaint,
    );
    textPainter.text = TextSpan(text: formatRupees((minVal + maxVal) / 2), style: axisTextStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(5, midY - textPainter.height / 2));

    // Min line
    canvas.drawLine(
      Offset(paddingLeft, paddingTop + chartHeight),
      Offset(size.width - paddingRight, paddingTop + chartHeight),
      gridPaint,
    );
    textPainter.text = TextSpan(text: formatRupees(minVal), style: axisTextStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(5, paddingTop + chartHeight - textPainter.height / 2));

    // Calculate points
    final double step = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth;
    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final double x = paddingLeft + i * step;
      final double relativeVal = (data[i] - minVal) / (maxVal - minVal);
      final double y = paddingTop + chartHeight - (relativeVal * chartHeight);
      points.add(Offset(x, y));
    }

    // Build smooth Bezier path
    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX1 = p0.dx + step / 2;
        final controlY1 = p0.dy;
        final controlX2 = p1.dx - step / 2;
        final controlY2 = p1.dy;
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
      }
    }

    // Animate the path drawing left-to-right using path metrics
    final linePaint = Paint()
      ..color = AppColors.successGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final areaPaint = Paint()
      ..style = PaintingStyle.fill;

    if (points.isNotEmpty) {
      final pathMetrics = path.computeMetrics();
      final animatedPath = Path();
      for (final metric in pathMetrics) {
        final extractLen = metric.length * animationValue;
        animatedPath.addPath(metric.extractPath(0, extractLen), Offset.zero);
      }

      // Draw standard line
      canvas.drawPath(animatedPath, linePaint);

      // Create gradient fill underneath the path
      if (animatedPath.getBounds().width > 0) {
        final fillPath = Path.from(animatedPath);
        // Find the last point of the animated path
        final lastPointX = paddingLeft + (points.last.dx - paddingLeft) * animationValue;
        
        // We close the path by going down to the bottom and back to the start
        fillPath.lineTo(lastPointX, paddingTop + chartHeight);
        fillPath.lineTo(paddingLeft, paddingTop + chartHeight);
        fillPath.close();

        areaPaint.shader = LinearGradient(
          colors: [
            AppColors.successGreen.withOpacity(isDark ? 0.15 : 0.25),
            AppColors.successGreen.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, size.width - paddingRight, paddingTop + chartHeight));
        canvas.drawPath(fillPath, areaPaint);
      }
    }

    // Draw active point vertical line and dot/tooltip
    if (activeIndex >= 0 && activeIndex < points.length) {
      final activePoint = points[activeIndex];
      
      // Only show if the animation has reached this point's X value
      if (activePoint.dx <= paddingLeft + (points.last.dx - paddingLeft) * animationValue) {
        // Vertical indicator line
        final activeLinePaint = Paint()
          ..color = AppColors.successGreen.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
          
        canvas.drawLine(
          Offset(activePoint.dx, paddingTop),
          Offset(activePoint.dx, paddingTop + chartHeight),
          activeLinePaint,
        );

        // Glow circle under the main dot
        canvas.drawCircle(
          activePoint,
          8.0,
          Paint()..color = AppColors.successGreen.withOpacity(0.3),
        );

        // Main dot
        canvas.drawCircle(
          activePoint,
          4.0,
          Paint()..color = AppColors.successGreen,
        );

        // Tooltip box
        final monthStr = labels[activeIndex];
        final amountStr = "₹${formatIndianRupees(data[activeIndex])}";
        final tooltipText = "$monthStr: $amountStr";

        final tooltipTextStyle = const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        );

        textPainter.text = TextSpan(text: tooltipText, style: tooltipTextStyle);
        textPainter.layout();

        final tooltipW = textPainter.width + 16;
        final tooltipH = textPainter.height + 8;
        
        // Center tooltip over the dot
        double tooltipX = activePoint.dx - tooltipW / 2;
        double tooltipY = activePoint.dy - tooltipH - 8;

        // Keep inside bounds
        if (tooltipX < paddingLeft) tooltipX = paddingLeft;
        if (tooltipX + tooltipW > size.width - paddingRight) {
          tooltipX = size.width - paddingRight - tooltipW;
        }
        if (tooltipY < 0) {
          tooltipY = activePoint.dy + 12; // Put below if too high
        }

        final tooltipRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tooltipX, tooltipY, tooltipW, tooltipH),
          const Radius.circular(8),
        );

        canvas.drawRRect(
          tooltipRect,
          Paint()..color = const Color(0xFF1E1E1E),
        );
        canvas.drawRRect(
          tooltipRect,
          Paint()
            ..color = AppColors.successGreen.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        textPainter.paint(
          canvas,
          Offset(tooltipX + 8, tooltipY + 4),
        );
      }
    }
    
    // Draw month labels on X axis
    for (int i = 0; i < labels.length; i++) {
      if (i % 2 == 0 || i == labels.length - 1) { // Sparsely label
        final labelPoint = points[i];
        textPainter.text = TextSpan(text: labels[i], style: axisTextStyle);
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(labelPoint.dx - textPainter.width / 2, paddingTop + chartHeight + 6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.data != data ||
        oldDelegate.isDark != isDark;
  }
}