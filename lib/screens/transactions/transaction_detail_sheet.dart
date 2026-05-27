import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/custom_animations.dart';

class TransactionDetailSheet extends StatefulWidget {
  final TransactionModel transaction;
  const TransactionDetailSheet({super.key, required this.transaction});

  static void show(BuildContext context, TransactionModel transaction) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailSheet(transaction: transaction),
    );
  }

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  bool _showOriginal = false;
  late String _currentCategory;
  bool _isRecurring = false;

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
    _currentCategory = AppState.instance.getCategory(widget.transaction.merchant, widget.transaction.id);
    // Mark as recurring mock logic: read from SharedPreferences or keep local
    _isRecurring = widget.transaction.merchant.toLowerCase().contains('netflix') ||
        widget.transaction.merchant.toLowerCase().contains('spotify') ||
        widget.transaction.merchant.toLowerCase().contains('youtube');
  }

  String _formatDate(DateTime dt) {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final day = dt.day;
    final monthStr = months[dt.month - 1];
    final year = dt.year;
    return "$day $monthStr $year";
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;
    final labelColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final valueColor = isDark ? Colors.white : AppColors.lightTextPrimary;

    final txDate = DateTime.fromMillisecondsSinceEpoch(widget.transaction.timestamp);
    final isDebit = widget.transaction.type == "DEBIT";

    final emoji = _categoryEmojis[_currentCategory] ?? "📝";
    final categoryColor = _categoryColors[_currentCategory] ?? const Color(0xFF8E8E93);

    // Parse amount to double for formatting
    final amtVal = double.tryParse(widget.transaction.amount) ?? 0.0;
    final formattedAmount = formatIndianRupees(amtVal);

    // Determine source
    String source = "Manual Entry";
    if (widget.transaction.sender == "CSV") {
      source = "CSV Upload";
    } else if (widget.transaction.sender != "MANUAL") {
      source = "SMS · ${widget.transaction.sender}";
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.50,
      maxChildSize: 0.90,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Draggable Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Scrollable Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Merchant Icon
                    Center(
                      child: Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: categoryColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Merchant Name
                    Center(
                      child: Text(
                        widget.transaction.merchant,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: valueColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Amount
                    Center(
                      child: Text(
                        "${isDebit ? '–' : '+'}${'₹'}$formattedAmount",
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: isDebit ? AppColors.errorRed : AppColors.successGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Date & Time
                    Center(
                      child: Text(
                        "${_formatDate(txDate)} · ${_formatTime(txDate)}",
                        style: TextStyle(
                          fontSize: 14,
                          color: labelColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Divider(color: borderColor),
                    const SizedBox(height: 12),
                    
                    // Detail Rows
                    _buildDetailRow("Category", Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentCategory,
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ), labelColor),
                    
                    _buildDetailRow("Source", Text(
                      source,
                      style: TextStyle(color: valueColor, fontWeight: FontWeight.w500, fontSize: 13),
                    ), labelColor),
                    
                    _buildDetailRow("Transaction Type", Text(
                      isDebit ? "Debit" : "Credit",
                      style: TextStyle(
                        color: isDebit ? AppColors.errorRed : AppColors.successGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ), labelColor),
                    
                    _buildDetailRow("Bank Account", Text(
                      widget.transaction.bank,
                      style: TextStyle(color: valueColor, fontWeight: FontWeight.w500, fontSize: 13),
                    ), labelColor),
                    
                    // Raw Message Collapsible
                    if (widget.transaction.message.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showOriginal = !_showOriginal;
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Original Message",
                              style: TextStyle(color: labelColor, fontSize: 13),
                            ),
                            Text(
                              _showOriginal ? "Hide original ↑" : "Show original →",
                              style: TextStyle(
                                color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showOriginal) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161616) : const Color(0xFFF6F8F6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            widget.transaction.message,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.4,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                    
                    const SizedBox(height: 16),
                    Divider(color: borderColor),
                    const SizedBox(height: 16),
                    
                    // Action controls
                    // 1. Edit Category Row Button
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_rounded, color: isDark ? Colors.white : Colors.black87),
                      title: Text(
                        "Edit Category",
                        style: TextStyle(color: valueColor, fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: labelColor),
                      onTap: () => _showCategoryPicker(context),
                    ),
                    
                    // 2. Recurring Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.autorenew_rounded, color: isDark ? Colors.white : Colors.black87),
                      title: Text(
                        "Mark as Recurring",
                        style: TextStyle(color: valueColor, fontWeight: FontWeight.w500),
                      ),
                      value: _isRecurring,
                      activeColor: AppColors.accentNeon,
                      onChanged: (val) {
                        setState(() {
                          _isRecurring = val;
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                    
                    // 3. Delete Transaction
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed),
                      title: const Text(
                        "Delete Transaction",
                        style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700),
                      ),
                      onTap: () => _confirmDelete(context),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, Widget valueWidget, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 13),
          ),
          valueWidget,
        ],
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
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
                  "Select Category",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _categoryEmojis.keys.map((cat) {
                    final emoji = _categoryEmojis[cat]!;
                    final isSelected = cat == _currentCategory;
                    final categoryColor = _categoryColors[cat] ?? Colors.grey;
                    
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji),
                          const SizedBox(width: 6),
                          Text(cat),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) async {
                        if (selected && widget.transaction.id != null) {
                          setState(() {
                            _currentCategory = cat;
                          });
                          await AppState.instance.updateTransactionCategory(widget.transaction.id!, cat);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } else if (widget.transaction.id == null) {
                          // Handle manual draft override
                          setState(() {
                            _currentCategory = cat;
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      selectedColor: categoryColor.withOpacity(0.2),
                      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F0),
                      labelStyle: TextStyle(
                        color: isSelected ? categoryColor : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Transaction"),
          content: const Text("Are you sure you want to permanently delete this transaction? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                if (widget.transaction.id != null) {
                  await AppState.instance.deleteTransaction(widget.transaction.id!);
                }
                if (ctx.mounted) Navigator.pop(ctx); // Close dialog
                if (context.mounted) Navigator.pop(context); // Close bottom sheet
              },
              child: const Text("Delete", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
