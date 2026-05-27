import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/custom_animations.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> with TickerProviderStateMixin {
  final Set<String> _expandedCategories = {};
  late AnimationController _progressController;
  late Animation<double> _progressCurve;

  final Map<String, String> _categoryEmojis = {
    "Food & Beverages": "🍔",
    "Transport": "🚗",
    "Shopping": "🛍️",
    "Entertainment": "🎮",
    "Bills & Utilities": "💡",
    "Other": "📦",
    "Credits": "💰",
    "Income": "💰",
  };

  final Map<String, Color> _categoryColors = {
    "Food & Beverages": const Color(0xFFFF9500),
    "Transport": const Color(0xFF007AFF),
    "Shopping": const Color(0xFFFF2D55),
    "Entertainment": const Color(0xFFAF52DE),
    "Bills & Utilities": const Color(0xFFFFCC00),
    "Other": const Color(0xFF8E8E93),
    "Credits": const Color(0xFF34C759),
    "Income": const Color(0xFF34C759),
  };

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressCurve = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutExpo,
    );
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  int _getRemainingDays() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return lastDay - now.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remainingDays = _getRemainingDays();

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, child) {
        final state = AppState.instance;
        final totalSpent = state.totalSpent;
        final totalLimit = state.totalBudgetLimit;
        final remaining = (totalLimit - totalSpent) < 0 ? 0.0 : (totalLimit - totalSpent);
        final spentPct = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;

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
              "Budgets",
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.add_rounded,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  size: 28,
                ),
                onPressed: () => _showAddBudgetBottomSheet(context, state),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Total Budget Hero Card
                FadeUpEntrance(
                  delay: const Duration(milliseconds: 0),
                  child: _buildTotalBudgetHeroCard(isDark, totalLimit, totalSpent, remaining, spentPct, remainingDays),
                ),
                const SizedBox(height: 28),

                // Section Header
                FadeUpEntrance(
                  delay: const Duration(milliseconds: 80),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Category Budgets",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showEditAllBottomSheet(context, state),
                        child: Text(
                          "Edit All",
                          style: TextStyle(
                            color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Category Budgets List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.categoryLimits.keys.length,
                  itemBuilder: (context, index) {
                    final cat = state.categoryLimits.keys.elementAt(index);
                    final limit = state.categoryLimits[cat]!;
                    final spent = state.getCategorySpend(cat);
                    final delay = Duration(milliseconds: 100 + index * 30);

                    return FadeUpEntrance(
                      delay: delay,
                      child: _buildCategoryAccordionCard(context, cat, spent, limit, isDark, state),
                    );
                  },
                ),

                const SizedBox(height: 110),
              ],
            ),
          ),
        );
      },
    );
  }

  // Total Budget Hero Card
  Widget _buildTotalBudgetHeroCard(
      bool isDark, double limit, double spent, double left, double spentPct, int remainingDays) {
    
    final barColor = spentPct > 0.85 
        ? AppColors.errorRed 
        : (spentPct >= 0.60 ? AppColors.alertOrange : AppColors.successGreen);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              GestureDetector(
                onTap: () => _showEditTotalBudgetDialog(context, limit),
                child: Row(
                  children: [
                    Text(
                      "Total Budget Limit Limit",
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "2026 · May",
                  style: TextStyle(
                    color: AppColors.successGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Amount
                    Row(
                      children: [
                        Text(
                          "₹",
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                        CountUpText(
                          value: limit,
                          prefix: "",
                          style: GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$remainingDays days remaining in this month",
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Circular ring percentage draws clockwise on load
              AnimatedBuilder(
                animation: _progressCurve,
                builder: (context, child) {
                  return SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (spentPct * _progressCurve.value).clamp(0.0, 1.0),
                          strokeWidth: 7,
                          backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                        Text(
                          "${(spentPct * 100).toStringAsFixed(0)}%",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Two line summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Spend ₹${formatIndianRupees(spent)}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                "₹${formatIndianRupees(left)} Left",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar (10px thick, rounded)
          AnimatedBuilder(
            animation: _progressCurve,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (spentPct * _progressCurve.value).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Category card Accordion
  Widget _buildCategoryAccordionCard(
      BuildContext context, String category, double spent, double limit, bool isDark, AppState state) {
    
    final isExpanded = _expandedCategories.contains(category);
    final percent = limit > 0 ? (spent / limit).clamp(0.0, 2.0) : 0.0;
    final left = (limit - spent) < 0 ? 0.0 : (limit - spent);

    final emoji = _categoryEmojis[category] ?? "📦";
    final color = _categoryColors[category] ?? Colors.grey;

    String badgeText = "Safe";
    Color badgeColor = AppColors.successGreen;
    if (percent > 1.0) {
      badgeText = "Over Limit";
      badgeColor = AppColors.errorRed;
    } else if (percent >= 0.6) {
      badgeText = "Watch Out";
      badgeColor = AppColors.alertOrange;
    }

    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;

    // Filter transactions in this category
    final categoryTxs = state.transactions.where((tx) {
      return state.getCategory(tx.merchant, tx.id) == category && tx.transactionType == "debit";
    }).toList();

    return Card(
      color: isDark ? const Color(0xFF161616) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Header Tappable area (88px tall)
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(category);
                } else {
                  _expandedCategories.add(category);
                }
              });
              HapticFeedback.selectionClick();
            },
            child: Container(
              height: 88,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$emoji  $category",
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Middle Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "₹${formatIndianRupees(spent)} of ₹${formatIndianRupees(limit)} used",
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 20,
                      ),
                    ],
                  ),
                  
                  // Bottom Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Accordion content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Budget usage details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${(percent * 100).toStringAsFixed(0)}% used",
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        percent > 1.0
                            ? "Exceeded by ₹${formatIndianRupees(spent - limit)}"
                            : "₹${formatIndianRupees(left)} left",
                        style: TextStyle(
                          color: percent > 1.0 ? AppColors.errorRed : AppColors.successGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    "Transactions this month",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  categoryTxs.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            "No transactions in this category yet.",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categoryTxs.length,
                          itemBuilder: (context, txIdx) {
                            final tx = categoryTxs[txIdx];
                            final txDate = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
                            final hasTime = txDate.hour != 0 || txDate.minute != 0;
                            final timeStr = hasTime ? "${txDate.hour.toString().padLeft(2, '0')}:${txDate.minute.toString().padLeft(2, '0')}" : "";
                            final amtVal = double.tryParse(tx.amount) ?? 0.0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      tx.merchant,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "₹${formatIndianRupees(amtVal)}",
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  if (hasTime) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Edit Total Budget Limit Dialog
  void _showEditTotalBudgetDialog(BuildContext context, double currentLimit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentLimit.toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit Total Budget"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: const InputDecoration(
              labelText: "Monthly Limit (₹)",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final double limit = double.tryParse(controller.text.trim()) ?? 0.0;
                if (limit > 0) {
                  await AppState.instance.updateTotalBudget(limit);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Save", style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Edit All category limits bottom sheet
  void _showEditAllBottomSheet(BuildContext context, AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controllers = <String, TextEditingController>{};
    state.categoryLimits.forEach((k, v) {
      controllers[k] = TextEditingController(text: v.toStringAsFixed(0));
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Edit Category Budgets",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: controllers.entries.map((entry) {
                    final cat = entry.key;
                    final controller = entry.value;
                    final emoji = _categoryEmojis[cat] ?? "📦";
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            height: 40,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixText: "₹",
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    for (var entry in controllers.entries) {
                      final double limit = double.tryParse(entry.value.text.trim()) ?? 0.0;
                      if (limit > 0) {
                        await state.updateCategoryLimit(entry.key, limit);
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(
                    "Save All Changes",
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Add Category Budget Bottom Sheet
  void _showAddBudgetBottomSheet(BuildContext context, AppState state) {
    final limitController = TextEditingController();
    String selectedCategory = _categoryEmojis.keys.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Category Budget",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Category picker: horizontal scroll of emoji chips
                  const Text("Select Category", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _categoryEmojis.entries.map((entry) {
                        final cat = entry.key;
                        final emoji = entry.value;
                        final isSelected = selectedCategory == cat;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emoji),
                                const SizedBox(width: 6),
                                Text(cat),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() {
                                  selectedCategory = cat;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount input
                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      labelText: "Limit Amount",
                      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final double limit = double.tryParse(limitController.text.trim()) ?? 0.0;
                        if (limit > 0) {
                          await state.updateCategoryLimit(selectedCategory, limit);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      child: Text(
                        "Add Budget",
                        style: TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}