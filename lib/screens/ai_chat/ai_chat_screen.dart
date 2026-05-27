import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/custom_animations.dart';

class MessageModel {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final TransactionModel? referencedTransaction;

  MessageModel({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.referencedTransaction,
  });
}

class AIChatScreen extends StatefulWidget {
  final String? prefilledQuestion;
  const AIChatScreen({super.key, this.prefilledQuestion});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> with TickerProviderStateMixin {
  final List<MessageModel> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isResponding = false;
  late AnimationController _pulseController;
  late AnimationController _sparkleController;

  final List<String> _suggestionsRow1 = [
    "Where did I spend the most this month? 📊",
    "Do I have any unused subscriptions? 📺",
    "How does my spending compare to last month? 📈",
  ];

  final List<String> _suggestionsRow2 = [
    "What came in via SMS today? 📲",
    "Am I on track with my budget? 🎯",
    "Show me my top merchants this week 🏪",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // If prefilled question exists, send it on mount
    if (widget.prefilledQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSubmitted(widget.prefilledQuestion!);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sparkleController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    setState(() {
      _messages.add(
        MessageModel(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isResponding = true;
    });
    _scrollToBottom();
    HapticFeedback.lightImpact();

    // Simulate AI response delay
    Timer(const Duration(seconds: 1500 ~/ 1000 == 1 ? 1 : 2), () {
      if (!mounted) return;
      final responseText = _generateMockResponse(text);
      final refTx = _findMatchingRefTx(text);

      setState(() {
        _isResponding = false;
        _messages.add(
          MessageModel(
            text: responseText,
            isUser: false,
            timestamp: DateTime.now(),
            referencedTransaction: refTx,
          ),
        );
      });
      _scrollToBottom();
      HapticFeedback.lightImpact();
    });
  }

  TransactionModel? _findMatchingRefTx(String query) {
    final state = AppState.instance;
    if (state.transactions.isEmpty) return null;
    final q = query.toLowerCase();
    if (q.contains('spend') || q.contains('most') || q.contains('swiggy') || q.contains('uber')) {
      // Find highest spend debit
      final debits = state.transactions.where((tx) => tx.type == "DEBIT").toList();
      if (debits.isNotEmpty) {
        debits.sort((a, b) => (double.tryParse(b.amount) ?? 0.0).compareTo(double.tryParse(a.amount) ?? 0.0));
        return debits.first;
      }
    }
    return null;
  }

  String _generateMockResponse(String query) {
    final state = AppState.instance;
    final totalSpent = state.totalSpent;
    final remaining = (state.totalBudgetLimit - totalSpent) < 0 ? 0.0 : (state.totalBudgetLimit - totalSpent);
    final q = query.toLowerCase();

    if (q.contains('most') || q.contains('spend the most') || q.contains('categories')) {
      final food = state.getCategorySpend("Food & Beverages");
      final shop = state.getCategorySpend("Shopping");
      final trans = state.getCategorySpend("Transport");
      
      String topName = "Food & Beverages";
      double topAmt = food;
      if (shop > topAmt) { topName = "Shopping"; topAmt = shop; }
      if (trans > topAmt) { topName = "Transport"; topAmt = trans; }

      return "Based on your records, your highest spending category this month is **$topName**, totalling ₹${formatIndianRupees(topAmt)}. Your biggest transaction is referenced below.";
    } else if (q.contains('subscription') || q.contains('unused')) {
      final subs = state.getSubscriptions();
      if (subs.isEmpty) {
        return "I haven't detected any active recurring subscriptions in your ledger. If you have recurring bills, make sure they are parsed via SMS or statement imports!";
      }
      return "I've detected ${subs.length} active subscriptions (e.g. Netflix, Spotify). I notice you haven't logged any matching usage or verification updates for Spotify in the last 30 days. You could save money by review-cancelling it!";
    } else if (q.contains('compare') || q.contains('last month')) {
      return "This month you've spent ₹${formatIndianRupees(totalSpent)} so far, compared to ₹${formatIndianRupees(totalSpent * 1.15)} last month. You're currently spending about 15% less! Great job maintaining your budget constraints.";
    } else if (q.contains('sms')) {
      final smsTxs = state.transactions.where((tx) => tx.sender != "MANUAL" && tx.sender != "CSV").toList();
      if (smsTxs.isEmpty) {
        return "No SMS transactions have been detected today. To verify auto-ingestion, you can simulate HDFC or SBI alert text messages in the 'Alerts' tab on the Dashboard.";
      }
      final last = smsTxs.first;
      return "Your last auto-parsed SMS transaction was ₹${formatIndianRupees(double.tryParse(last.amount) ?? 0.0)} spent at **${last.merchant}** (Source: ${last.sender}).";
    } else if (q.contains('track') || q.contains('budget')) {
      final pct = state.totalBudgetLimit > 0 ? (totalSpent / state.totalBudgetLimit * 100) : 0.0;
      if (pct > 85.0) {
        return "Warning: You have utilized ${pct.toStringAsFixed(0)}% of your ₹${formatIndianRupees(state.totalBudgetLimit)} total budget limit. You have only ₹${formatIndianRupees(remaining)} left, so I suggest scaling back non-essential purchases.";
      }
      return "You're on track! You've spent ₹${formatIndianRupees(totalSpent)} out of ₹${formatIndianRupees(state.totalBudgetLimit)} total budget (${pct.toStringAsFixed(0)}% utilized). With ${_getRemainingDays()} days left, your daily spend limit is ₹${(remaining / _getRemainingDays()).toStringAsFixed(0)}.";
    } else if (q.contains('merchant') || q.contains('week')) {
      return "Your top merchant by frequency and cost this week is **Swiggy**, followed closely by **Uber**. You spent ₹${formatIndianRupees(totalSpent * 0.4)} across Swiggy orders.";
    }
    
    return "I've analyzed your financial ledger. Your current monthly limit is ₹${formatIndianRupees(state.totalBudgetLimit)} and you've spent ₹${formatIndianRupees(totalSpent)} (₹${formatIndianRupees(remaining)} left). How can I help you optimize your savings today?";
  }

  int _getRemainingDays() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return lastDay - now.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF080808) : Colors.white;
    final threadBg = isDark ? const Color(0xFF080808) : const Color(0xFFFBFDFA);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;
    final textTheme = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF080808) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "AI Assistant",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textTheme,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Green pulsing dot indicating online
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.3 + 0.7 * _pulseController.value),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Online",
                      style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.history_toggle_off_rounded, color: isDark ? Colors.white : Colors.black),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showHistoryDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Area
          Expanded(
            child: Container(
              color: threadBg,
              child: _messages.isEmpty
                  ? _buildWelcomeState(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _messages.length + (_isResponding ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isResponding) {
                          return _buildTypingIndicator(isDark);
                        }
                        
                        final msg = _messages[index];
                        final showLabel = !msg.isUser && (index == 0 || _messages[index - 1].isUser);
                        
                        return Column(
                          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (showLabel) ...[
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0, bottom: 4.0),
                                child: Text(
                                  "Spendify AI",
                                  style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            _buildMessageBubble(msg, isDark),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
            ),
          ),
          
          // Fixed Input Box
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewPadding.bottom + 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF080808) : Colors.white,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
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
                      controller: _textController,
                      style: TextStyle(color: textTheme),
                      onChanged: (val) {
                        setState(() {}); // Rebuild send button active state
                      },
                      decoration: InputDecoration(
                        hintText: "Ask about your spending...",
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Send Circle
                SpringScaleButton(
                  scaleDownFactor: 0.95,
                  onTap: () => _handleSubmitted(_textController.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _textController.text.trim().isNotEmpty
                          ? AppColors.successGreen
                          : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: _textController.text.trim().isNotEmpty
                            ? Colors.black
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Typewriter Text display wrapper
  Widget _buildMessageBubble(MessageModel msg, bool isDark) {
    final bubbleColor = msg.isUser
        ? const Color(0xFF132F1A) // dark green User bubble
        : (isDark ? const Color(0xFF161616) : Colors.white); // AI bubble
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.4,
    );
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;

    final bubbleBorderRadius = msg.isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.zero,
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.zero,
            bottomRight: Radius.circular(18),
          );

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: bubbleBorderRadius,
        border: msg.isUser ? null : Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stream text (Typewriter only for latest AI message)
          if (!msg.isUser && msg == _messages.last) ...[
            TypewriterText(
              text: msg.text,
              style: textStyle.copyWith(color: isDark ? Colors.white : AppColors.lightTextPrimary),
            ),
          ] else ...[
            Text(
              msg.text,
              style: textStyle.copyWith(
                color: msg.isUser ? Colors.white : (isDark ? Colors.white : AppColors.lightTextPrimary),
              ),
            ),
          ],
          
          // Referenced transaction card
          if (msg.referencedTransaction != null) ...[
            const SizedBox(height: 12),
            _buildReferenceTransactionCard(msg.referencedTransaction!, isDark),
          ],
        ],
      ),
    );
  }

  // Referenced transaction card (green left border)
  Widget _buildReferenceTransactionCard(TransactionModel tx, bool isDark) {
    final amtVal = double.tryParse(tx.amount) ?? 0.0;
    final formattedAmt = formatIndianRupees(amtVal);
    final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    final dateStr = "${date.day} May";
    final category = AppState.instance.getCategory(tx.merchant, tx.id);
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: AppColors.successGreen, width: 3),
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
          right: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
          bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$category · $dateStr",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "–₹$formattedAmt",
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.errorRed,
            ),
          ),
        ],
      ),
    );
  }

  // Typing indicator
  Widget _buildTypingIndicator(bool isDark) {
    final bubbleColor = isDark ? const Color(0xFF161616) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;

    return Container(
      constraints: const BoxConstraints(maxWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.zero,
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          BouncingDot(delay: 0),
          BouncingDot(delay: 150),
          BouncingDot(delay: 300),
        ],
      ),
    );
  }

  // Welcome State
  Widget _buildWelcomeState(bool isDark) {
    final String name = AppState.instance.userName;
    final labelColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI Sparkle Avatar (loop pulsing)
            ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.06).animate(
                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
              ),
              child: Container(
                height: 64,
                width: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successGreen,
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              "Hi $name! 👋",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Ask me anything about your spending.",
              style: TextStyle(color: labelColor, fontSize: 15),
            ),
            const SizedBox(height: 32),

            // Horizontal suggestions rows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: _suggestionsRow1.length,
                      itemBuilder: (context, idx) {
                        final chipText = _suggestionsRow1[idx];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(chipText),
                            selected: false,
                            onSelected: (_) => _handleSubmitted(chipText),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: _suggestionsRow2.length,
                      itemBuilder: (context, idx) {
                        final chipText = _suggestionsRow2[idx];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(chipText),
                            selected: false,
                            onSelected: (_) => _handleSubmitted(chipText),
                          ),
                        );
                      },
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

  void _showHistoryDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Chat Session History"),
          content: const Text(
            "This is a new local session. Historical summaries are compiled on-device when new transaction CSV statements or bank SMS messages are parsed.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Dismiss"),
            ),
          ],
        );
      },
    );
  }
}

// Bouncing dots for typing indicator
class BouncingDot extends StatefulWidget {
  final int delay;
  const BouncingDot({super.key, required this.delay});

  @override
  State<BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<BouncingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.successGreen,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// Typewriter streaming text widget
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayText = "";
  Timer? _timer;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startTypewriter();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTypewriter() {
    _timer?.cancel();
    _displayText = "";
    _charIndex = 0;
    
    _timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _displayText += widget.text[_charIndex];
          _charIndex++;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayText, style: widget.style);
  }
}
