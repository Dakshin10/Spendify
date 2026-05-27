import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/custom_animations.dart';
import '../csv_upload/csv_upload_screen.dart';
import 'transaction_detail_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  String _activeFilter = "All";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  late AnimationController _shimmerController;

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
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Simulate skeleton loader
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // Group transactions by date and calculate total spend for each day
  Map<String, List<TransactionModel>> _groupTransactions(List<TransactionModel> list) {
    final Map<String, List<TransactionModel>> groups = {};
    final now = DateTime.now();
    final todayStart = DateUtils.dateOnly(now);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    for (var tx in list) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
      final dateOnly = DateUtils.dateOnly(date);

      String label;
      if (dateOnly.isAtSameMomentAs(todayStart)) {
        label = "Today";
      } else if (dateOnly.isAtSameMomentAs(yesterdayStart)) {
        label = "Yesterday";
      } else {
        label = _formatDate(date);
      }

      if (!groups.containsKey(label)) {
        groups[label] = [];
      }
      groups[label]!.add(tx);
    }
    return groups;
  }

  double _getDayTotalSpend(List<TransactionModel> items) {
    double sum = 0;
    for (var tx in items) {
      if (tx.type == "DEBIT") {
        sum += double.tryParse(tx.amount) ?? 0.0;
      }
    }
    return sum;
  }

  String _formatDate(DateTime dt) {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    // Friday, 24 May 2026 format
    final weekdayStr = weekdays[dt.weekday - 1];
    final monthStr = months[dt.month - 1];
    return "$weekdayStr, ${dt.day} $monthStr ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, child) {
        final state = AppState.instance;

        // Calculate chip counts
        final allCount = state.transactions.length;
        final cardCount = state.transactions.where((tx) => tx.paymentMode == "Card").length;
        final bankCount = state.transactions.where((tx) => tx.paymentMode == "UPI" || tx.paymentMode == "Bank Transfer").length;
        final cashCount = state.transactions.where((tx) => tx.paymentMode == "Cash").length;
        final smsCount = state.transactions.where((tx) => tx.sender != "MANUAL" && tx.sender != "CSV").length;
        final csvCount = state.transactions.where((tx) => tx.sender == "CSV").length;

        // Filter transactions
        final filteredList = state.transactions.where((tx) {
          final query = _searchQuery.toLowerCase();
          final cat = state.getCategory(tx.merchant, tx.id).toLowerCase();
          final matchesSearch = tx.merchant.toLowerCase().contains(query) ||
              cat.contains(query) ||
              tx.amount.contains(query);

          if (!matchesSearch) return false;

          if (_activeFilter == "All") return true;
          if (_activeFilter == "Card") return tx.paymentMode == "Card";
          if (_activeFilter == "Bank") return tx.paymentMode == "UPI" || tx.paymentMode == "Bank Transfer";
          if (_activeFilter == "Cash") return tx.paymentMode == "Cash";
          if (_activeFilter == "SMS") return tx.sender != "MANUAL" && tx.sender != "CSV";
          if (_activeFilter == "CSV") return tx.sender == "CSV";

          return true;
        }).toList();

        final groupedTx = _groupTransactions(filteredList);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          floatingActionButton: state.transactions.isEmpty
              ? null
              : AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      if (state.smsTrackingEnabled) {
                        _showAddCashSheet(context, isDark);
                      } else {
                        _showManualTransactionSheet(context, isDark);
                      }
                    },
                    backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    icon: Icon(
                      state.smsTrackingEnabled ? Icons.payments_rounded : Icons.add_rounded,
                      size: 20,
                    ),
                    label: Text(
                      state.smsTrackingEnabled ? "Add Cash" : "Add Transaction",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
          floatingActionButtonLocation: const _CustomFloatingActionButtonLocation(
            FloatingActionButtonLocation.endFloat,
            110,//cash button -------------------------------
          ),
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
              "Transactions",
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
                  Icons.tune_rounded,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  size: 22,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showFilterBottomSheet(context);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 8),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161616) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "Search merchant, category, amount...",
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildFilterChip("All", allCount, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip("Card", cardCount, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip("Bank", bankCount, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip("Cash", cashCount, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip("SMS", smsCount, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip("CSV", csvCount, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Transaction list / skeleton shimmer
              Expanded(
                child: _isLoading
                    ? _buildSkeletonLoading(isDark)
                    : filteredList.isEmpty
                        ? _buildEmptyState(context, isDark, state.smsTrackingEnabled)
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: groupedTx.keys.length + 1,
                            itemBuilder: (context, index) {
                              if (index == groupedTx.keys.length) {
                                return const SizedBox(height: 120); // spacing for floating navigation + FAB
                              }
                              final dateLabel = groupedTx.keys.elementAt(index);
                              final items = groupedTx[dateLabel]!;
                              final dayTotal = _getDayTotalSpend(items);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Header with right-aligned day total spend
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          dateLabel,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                        if (dayTotal > 0)
                                          Text(
                                            "Total spent: ₹${formatIndianRupees(dayTotal)}",
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    itemBuilder: (context, itemIdx) {
                                      final tx = items[itemIdx];
                                      return _buildSwipeableRow(context, tx, isDark);
                                    },
                                  ),
                                ],
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

  Widget _buildFilterChip(String label, int count, bool isDark) {
    final isSelected = _activeFilter == label;
    final primaryColor = isDark ? AppColors.accentNeon : AppColors.lightGradient[0];
    
    return SpringScaleButton(
      scaleDownFactor: 0.95,
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : (isDark ? const Color(0xFF161616) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white60 : AppColors.lightTextPrimary),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isDark ? Colors.black26 : Colors.white24)
                      : (isDark ? AppColors.accentNeon.withOpacity(0.15) : AppColors.lightGradient[0].withOpacity(0.15)),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? AppColors.accentNeon : AppColors.lightGradient[0]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Swipeable row container
  Widget _buildSwipeableRow(BuildContext context, TransactionModel tx, bool isDark) {
    final uniqueKey = Key("tx_${tx.id ?? tx.timestamp}");

    return Dismissible(
      key: uniqueKey,
      direction: DismissDirection.horizontal,
      
      // Swipe Right -> Mark as reviewed
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withOpacity(0.2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 24),
            SizedBox(width: 8),
            Text(
              "Reviewed",
              style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),

      // Swipe Left -> Edit & Delete
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Icon(Icons.edit_rounded, color: Colors.orange, size: 22),
            SizedBox(width: 16),
            Icon(Icons.delete_sweep_rounded, color: AppColors.errorRed, size: 24),
            SizedBox(width: 8),
            Text(
              "Delete",
              style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),

      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Mark as Reviewed
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Transaction marked as reviewed ✓"),
              duration: Duration(seconds: 1),
            ),
          );
          return false; // Do not dismiss row
        } else {
          // Swipe Left -> Show option dialog to delete or edit
          HapticFeedback.mediumImpact();
          final action = await _showSwipeActionsDialog(context, tx);
          if (!context.mounted) return false;
          if (action == "DELETE") {
            if (tx.id != null) {
              await AppState.instance.deleteTransaction(tx.id!);
            }
            return true;
          } else if (action == "EDIT") {
            TransactionDetailSheet.show(context, tx);
            return false;
          }
          return false;
        }
      },
      child: _buildTransactionRowItem(context, tx, isDark),
    );
  }

  Widget _buildTransactionRowItem(BuildContext context, TransactionModel tx, bool isDark) {
    final category = AppState.instance.getCategory(tx.merchant, tx.id);
    final emoji = _categoryEmojis[category] ?? "📝";
    final categoryColor = _categoryColors[category] ?? const Color(0xFF8E8E93);
    final isDebit = tx.type == "DEBIT";

    final txDate = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    final timeStr = "${txDate.hour.toString().padLeft(2, '0')}:${txDate.minute.toString().padLeft(2, '0')}";

    final amtVal = double.tryParse(tx.amount) ?? 0.0;
    final formattedAmt = formatIndianRupees(amtVal);

    final showSMSBadge = tx.sender != "MANUAL" && tx.sender != "CSV";
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;

    return Card(
      color: isDark ? const Color(0xFF161616) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.lightImpact();
          TransactionDetailSheet.show(context, tx);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon
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
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              fontSize: 16,
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
                    const SizedBox(height: 4),
                    Text(
                      "$category · $timeStr",
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${isDebit ? '–' : '+'}${'₹'}$formattedAmt",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDebit ? AppColors.errorRed : AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
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
      ),
    );
  }

  // Swipe Action Confirm Dialog
  Future<String?> _showSwipeActionsDialog(BuildContext context, TransactionModel tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            tx.merchant,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: const Text("What would you like to do with this transaction?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, "CANCEL"),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, "EDIT"),
              child: const Text("Edit Category", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, "DELETE"),
              child: const Text("Delete", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Filter dialog bottom sheet
  void _showFilterBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filter Transactions",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Choose a payment method or source from the chips above to drill down your spending statement history.",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Dismiss"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Shimmer Skeleton loading rows
  Widget _buildSkeletonLoading(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: 5,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            final gradient = LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1E1E), const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)]
                  : [const Color(0xFFEBEBEB), const Color(0xFFF4F4F4), const Color(0xFFEBEBEB)],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(-1.0 + _shimmerController.value * 2, -0.3),
              end: Alignment(1.0 + _shimmerController.value * 2, 0.3),
            );

            return Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161616) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  // Icon shimmer
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Text fields shimmer
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount shimmer
                  Container(
                    width: 60,
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(6),
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

  // Monochrome SVG / Simple Empty State
  Widget _buildEmptyState(BuildContext context, bool isDark, [bool smsOn = true]) {
    final primaryColor = isDark ? AppColors.accentNeon : AppColors.lightGradient[0];
    final iconColor = isDark ? Colors.white38 : Colors.black38;
    final labelColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final headline = _activeFilter == "All"
        ? "No transactions yet"
        : "No $_activeFilter transactions";
    
    final bodyText = smsOn
        ? "Cash payments won't appear automatically — add them manually. Digital transactions auto-detect from SMS."
        : "SMS tracking is off. Add all your transactions manually below.";

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with subtle ring
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                smsOn ? Icons.payments_outlined : Icons.folder_open_rounded,
                size: 40,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              headline,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              bodyText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: labelColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            
            // Primary: Add Cash Transaction
            SpringScaleButton(
              scaleDownFactor: 0.97,
              onTap: () {
                HapticFeedback.lightImpact();
                _showAddCashSheet(context, isDark);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payments_rounded, size: 18, color: isDark ? Colors.black : Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      "Add Cash Transaction",
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary: Upload CSV
            SpringScaleButton(
              scaleDownFactor: 0.97,
              onTap: () {
                Navigator.push(context, AppPageTransitions.buildParallaxRoute(const CSVUploadScreen()));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161616) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file_rounded, size: 18,
                        color: isDark ? Colors.white70 : AppColors.lightTextPrimary),
                    const SizedBox(width: 8),
                    Text(
                      "Upload Bank CSV",
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (smsOn) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showSMSInfoDialog(context);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Text(
                  "How does SMS auto-detection work?",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Cash-only add sheet (shown when SMS tracking is ON)
  void _showAddCashSheet(BuildContext context, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final amtController = TextEditingController();
    final merchantController = TextEditingController();
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
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 20),
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
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
                                Text("Add Cash Payment",
                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary)),
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 0.8),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.money_rounded, size: 10, color: primaryColor),
                                    const SizedBox(width: 4),
                                    Text("Cash · Not tracked by SMS",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryColor)),
                                  ]),
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
                    TextFormField(
                      controller: amtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white24 : Colors.black12),
                        prefixText: "₹  ",
                        prefixStyle: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.black45),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Enter an amount";
                        if (double.tryParse(val.trim()) == null) return "Enter a valid number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: merchantController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: "Where did you pay? (e.g. Chai stall)",
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                        prefixIcon: Icon(Icons.store_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Enter merchant name";
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => txType = "DEBIT"),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: txType == "DEBIT" ? AppColors.errorRed.withOpacity(0.12)
                                    : (isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: txType == "DEBIT" ? AppColors.errorRed.withOpacity(0.5) : Colors.transparent,
                                  width: 1.2),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.arrow_upward_rounded, size: 16,
                                  color: txType == "DEBIT" ? AppColors.errorRed : Colors.grey),
                                const SizedBox(width: 6),
                                Text("Expense", style: GoogleFonts.outfit(fontSize: 13,
                                  fontWeight: txType == "DEBIT" ? FontWeight.w700 : FontWeight.w400,
                                  color: txType == "DEBIT" ? AppColors.errorRed : Colors.grey)),
                              ]),
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
                                color: txType == "CREDIT" ? AppColors.successGreen.withOpacity(0.12)
                                    : (isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: txType == "CREDIT" ? AppColors.successGreen.withOpacity(0.5) : Colors.transparent,
                                  width: 1.2),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.arrow_downward_rounded, size: 16,
                                  color: txType == "CREDIT" ? AppColors.successGreen : Colors.grey),
                                const SizedBox(width: 6),
                                Text("Income", style: GoogleFonts.outfit(fontSize: 13,
                                  fontWeight: txType == "CREDIT" ? FontWeight.w700 : FontWeight.w400,
                                  color: txType == "CREDIT" ? AppColors.successGreen : Colors.grey)),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text("Category", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: categoryOptions.map((cat) {
                        final isSelected = selectedCategory == cat['key'];
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedCategory = cat['key']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor.withOpacity(isDark ? 0.15 : 0.1)
                                  : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? primaryColor.withOpacity(0.5) : Colors.transparent, width: 1),
                            ),
                            child: Text(cat['label'], style: TextStyle(fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              color: isSelected ? primaryColor : (isDark ? Colors.white60 : Colors.black54))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx, initialDate: selectedDate,
                          firstDate: DateTime(2020), lastDate: DateTime.now(),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.dark(
                              primary: primaryColor, onPrimary: isDark ? Colors.black : Colors.white,
                              surface: isDark ? const Color(0xFF1E1E1E) : Colors.white)),
                            child: child!),
                        );
                        if (picked != null) setSheetState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161616) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black45),
                          const SizedBox(width: 10),
                          Text("${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87)),
                          const Spacer(),
                          Icon(Icons.edit_calendar_rounded, size: 14, color: isDark ? Colors.white30 : Colors.black26),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 56,
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
                              amount: amt, merchant: merchant, type: txType,
                              paymentMode: "Cash", bank: "Cash",
                              timestamp: selectedDate.millisecondsSinceEpoch,
                            );
                            final addedTx = AppState.instance.transactions.isNotEmpty
                                ? AppState.instance.transactions.first : null;
                            if (addedTx?.id != null && selectedCategory != "Other") {
                              await AppState.instance.setCategoryOverride(addedTx!.id!, selectedCategory);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text("Save Cash Payment", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                        ]),
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

  // Full manual transaction entry (shown when SMS tracking is OFF)
  void _showManualTransactionSheet(BuildContext context, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final amtController = TextEditingController();
    final merchantController = TextEditingController();
    String txType = "DEBIT";
    String paymentMode = "UPI";
    String bankName = "HDFC Bank";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
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
                        Text("New Transaction",
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary)),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Amount (₹)",
                        labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
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
                    TextFormField(
                      controller: merchantController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Merchant Name",
                        labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        prefixIcon: const Icon(Icons.store_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Please enter merchant name";
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text("Transaction Type", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text("Expense"),
                            selected: txType == "DEBIT",
                            onSelected: (selected) { if (selected) setSheetState(() => txType = "DEBIT"); },
                            selectedColor: AppColors.errorRed.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: txType == "DEBIT" ? AppColors.errorRed : Colors.grey,
                              fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text("Income"),
                            selected: txType == "CREDIT",
                            onSelected: (selected) { if (selected) setSheetState(() => txType = "CREDIT"); },
                            selectedColor: AppColors.successGreen.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: txType == "CREDIT" ? AppColors.successGreen : Colors.grey,
                              fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: paymentMode,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF161616) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(labelText: "Payment Mode",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                      items: const [
                        DropdownMenuItem(value: "UPI", child: Text("UPI")),
                        DropdownMenuItem(value: "Card", child: Text("Card")),
                        DropdownMenuItem(value: "Bank Transfer", child: Text("Bank Transfer")),
                        DropdownMenuItem(value: "Cash", child: Text("Cash")),
                      ],
                      onChanged: (val) { if (val != null) setSheetState(() => paymentMode = val); },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: bankName,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF161616) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(labelText: "Bank Account",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                      items: const [
                        DropdownMenuItem(value: "HDFC Bank", child: Text("HDFC Bank")),
                        DropdownMenuItem(value: "SBI", child: Text("SBI Bank")),
                        DropdownMenuItem(value: "ICICI Bank", child: Text("ICICI Bank")),
                        DropdownMenuItem(value: "Axis Bank", child: Text("Axis Bank")),
                      ],
                      onChanged: (val) { if (val != null) setSheetState(() => bankName = val); },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 56,
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
                              amount: amt, merchant: merchant, type: txType,
                              paymentMode: paymentMode, bank: bankName,
                            );
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        child: const Text("Save Transaction"),
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

  void _showSMSInfoDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("SMS Auto-Detection"),
          content: const Text(
            "Spendify reads bank SMS alerts on-device, parsing the transaction amount, merchant, and bank name. Your message texts are never stored raw or sent to any servers.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Got It"),
            ),
          ],
        );
      },
    );
  }
}

class _CustomFloatingActionButtonLocation extends FloatingActionButtonLocation {
  final FloatingActionButtonLocation standardLocation;
  final double offsetY;

  const _CustomFloatingActionButtonLocation(this.standardLocation, this.offsetY);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset offset = standardLocation.getOffset(scaffoldGeometry);
    return Offset(offset.dx, offset.dy - offsetY);
  }
}