import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/custom_animations.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 7;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  // Category Budgets Controllers (6 default categories)
  final Map<String, TextEditingController> _catControllers = {
    "Food & Beverages": TextEditingController(),
    "Transport": TextEditingController(),
    "Shopping": TextEditingController(),
    "Entertainment": TextEditingController(),
    "Bills & Utilities": TextEditingController(),
    "Other": TextEditingController(),
  };

  final Map<String, String> _catEmojis = {
    "Food & Beverages": "🍔",
    "Transport": "🚗",
    "Shopping": "🛍️",
    "Entertainment": "🎮",
    "Bills & Utilities": "💡",
    "Other": "📦",
  };

  final Map<String, double> _catPercentages = {
    "Food & Beverages": 0.35,
    "Transport": 0.15,
    "Shopping": 0.20,
    "Entertainment": 0.10,
    "Bills & Utilities": 0.12,
    "Other": 0.08,
  };

  // Preference selections
  bool _smsSelected = true;
  bool _csvSelected = true;
  bool _showPreferencesAnimation = false;

  // Animations
  late AnimationController _confettiController;
  late AnimationController _phoneBubbleController;
  late AnimationController _checkmarkController;

  // Particle list for exactly-allocated burst
  List<Offset> _burstParticles = [];
  bool _showExactBurst = false;

  @override
  void initState() {
    super.initState();
    
    // Pre-populate if set in Step 0 (PersonalDetailsScreen)
    if (AppState.instance.userName != "Investor" && AppState.instance.userName.isNotEmpty) {
      _nameController.text = AppState.instance.userName;
    }
    if (AppState.instance.monthlyIncome > 0) {
      _incomeController.text = _formatIndianRupees(AppState.instance.monthlyIncome.toStringAsFixed(0));
    }

    // Confetti drop controller (2s loop)
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Phone bubble floating controller
    _phoneBubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Checkmark self-drawing controller (600ms)
    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Live update calculations
    _incomeController.addListener(_onIncomeChanged);
    _budgetController.addListener(_onBudgetChanged);

    // Trigger preferences highlight on step 5 load
    _nameController.addListener(() {
      setState(() {}); // Updates heading preview
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _incomeController.dispose();
    _budgetController.dispose();
    for (var controller in _catControllers.values) {
      controller.dispose();
    }
    _confettiController.dispose();
    _phoneBubbleController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  void _onIncomeChanged() {
    final double income = _parseFormattedAmount(_incomeController.text);
    if (income > 0) {
      final double suggested = income * 0.60;
      final String formattedSuggested = _formatIndianRupees(suggested.toStringAsFixed(0));
      if (_budgetController.text.isEmpty || _budgetController.text == "0") {
        _budgetController.text = formattedSuggested;
      }
    }
  }

  void _onBudgetChanged() {
    final double budget = _parseFormattedAmount(_budgetController.text);
    if (budget > 0) {
      _catPercentages.forEach((key, pct) {
        final double amt = budget * pct;
        _catControllers[key]!.text = _formatIndianRupees(amt.toStringAsFixed(0));
      });
      setState(() {});
    }
  }

  double _parseFormattedAmount(String text) {
    final clean = text.replaceAll(RegExp(r'\D'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  String _formatIndianRupees(String val) {
    final clean = val.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return "";
    int len = clean.length;
    if (len <= 3) return clean;
    final last3 = clean.substring(len - 3);
    final remaining = clean.substring(0, len - 3);
    final List<String> chunks = [];
    int i = remaining.length;
    while (i > 0) {
      if (i >= 2) {
        chunks.insert(0, remaining.substring(i - 2, i));
        i -= 2;
      } else {
        chunks.insert(0, remaining.substring(0, i));
        break;
      }
    }
    return "${chunks.join(',')},$last3";
  }

  void _nextPage() {
    if (_currentStep == 4 && !_smsSelected) {
      // Step 5 -> Skip step 6 (SMS Perms) if SMS is not selected
      setState(() {
        _currentStep = 6;
      });
      _pageController.animateToPage(
        6,
        duration: const Duration(milliseconds: 280),
        curve: AppAnimationCurves.easeInOutCubic,
      );
      // Trigger confetti and checkmark drawing in celebration
      _confettiController.repeat();
      _checkmarkController.forward(from: 0.0);
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: AppAnimationCurves.easeInOutCubic,
      );

      if (_currentStep == 4) {
        // Trigger select card highlight staggered delay
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _showPreferencesAnimation = true;
            });
          }
        });
      }

      if (_currentStep == 6) {
        // Celebration Step
        _confettiController.repeat();
        _checkmarkController.forward(from: 0.0);
      }
    }
  }

  void _prevPage() {
    if (_currentStep == 6 && !_smsSelected) {
      // Step 7 -> Step 5 if SMS was skipped
      setState(() {
        _currentStep = 4;
      });
      _pageController.animateToPage(
        4,
        duration: const Duration(milliseconds: 280),
        curve: AppAnimationCurves.easeInOutCubic,
      );
      _confettiController.stop();
      _checkmarkController.reset();
      return;
    }

    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: AppAnimationCurves.easeInOutCubic,
      );
      _confettiController.stop();
      _checkmarkController.reset();
    }
  }

  Future<void> _completeWizard({bool uploadCsvFirst = false}) async {
    final String name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "Investor";
    final double income = _parseFormattedAmount(_incomeController.text);
    final double budget = _parseFormattedAmount(_budgetController.text);

    final Map<String, double> categories = {};
    _catControllers.forEach((key, controller) {
      categories[key] = _parseFormattedAmount(controller.text);
    });

    await AppState.instance.completeOnboarding(
      name: name,
      income: income,
      budget: budget,
      categories: categories,
    );
    
    // If user clicked CSV upload first, redirect appropriately
    if (uploadCsvFirst && mounted) {
      AppState.instance.setTab(1); // Go to transactions to launch CSV upload
    }
  }

  void _triggerExactBurst() {
    final random = math.Random();
    _burstParticles = List.generate(12, (index) {
      final double angle = random.nextDouble() * 2 * math.pi;
      final double distance = 10 + random.nextDouble() * 30;
      return Offset(math.cos(angle) * distance, math.sin(angle) * distance);
    });
    setState(() {
      _showExactBurst = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showExactBurst = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Thin top progress bar and Step label
            if (_currentStep < _totalSteps - 1) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      GestureDetector(
                        onTap: _prevPage,
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white60, size: 18),
                      )
                    else
                      const SizedBox(width: 18),
                    Text(
                      "Step ${_currentStep + 1} of 7",
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Thin green filling indicator line
              Container(
                width: double.infinity,
                height: 3,
                color: Colors.white.withOpacity(0.08),
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: MediaQuery.of(context).size.width * ((_currentStep + 1) / _totalSteps),
                  height: 3,
                  color: AppColors.accentNeon,
                ),
              ),
            ],
            
            // Core PageView steps
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStepWelcome(),
                  _buildStepIncome(),
                  _buildStepBudget(),
                  _buildStepCategorySplits(),
                  _buildStepPreferences(),
                  _buildStepSMSPermission(),
                  _buildStepCelebration(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1: Welcome & Name
  // ==========================================
  Widget _buildStepWelcome() {
    final name = _nameController.text.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Text("👋", style: TextStyle(fontSize: 48)),
          const SizedBox(height: 24),
          // Heading updates crossfade
          AnimatedCrossFade(
            firstChild: Text(
              "Let's set up your Spendify",
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            secondChild: Text(
              "Let's go, $name! 🎉",
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.accentNeon,
              ),
            ),
            crossFadeState: name.isNotEmpty ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          const SizedBox(height: 12),
          Text(
            "Takes less than 2 minutes. We'll personalise everything for you.",
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 48),
          
          // Focus input
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: "What's your first name?",
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: AppColors.darkCardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accentNeon, width: 1.5),
              ),
            ),
          ),
          const Spacer(flex: 2),
          
          SpringScaleButton(
            onTap: () {
              if (_nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter your name")),
                );
                return;
              }
              _nextPage();
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentNeon,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  "Let's Go →",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: Monthly Income
  // ==========================================
  Widget _buildStepIncome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text("💰", style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            "What's your monthly income?",
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Helps us suggest realistic budgets. Completely private — never shared.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),
          
          // Formatting Rupees Input field
          TextField(
            controller: _incomeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue.copyWith(text: '');
                final clean = newValue.text.replaceAll(RegExp(r'\D'), '');
                final formatted = _formatIndianRupees(clean);
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
            ],
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("₹", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: "0",
              hintStyle: const TextStyle(color: Colors.white12),
              filled: true,
              fillColor: AppColors.darkCardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.accentNeon, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Income chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIncomeChip("₹10K", 10000),
              _buildIncomeChip("₹25K", 25000),
              _buildIncomeChip("₹50K", 50000),
              _buildIncomeChip("₹1L+", 100000),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Most college students earn ₹5,000–₹15,000/month from part-time work or allowance",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.35),
              height: 1.3,
            ),
          ),
          const Spacer(),
          
          SpringScaleButton(
            onTap: () {
              if (_parseFormattedAmount(_incomeController.text) <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid monthly income")),
                );
                return;
              }
              _nextPage();
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentNeon,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  "Next →",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeChip(String label, double value) {
    final String formattedVal = _formatIndianRupees(value.toStringAsFixed(0));
    final isSelected = _incomeController.text == formattedVal;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _incomeController.text = formattedVal;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentNeon.withOpacity(0.12) : AppColors.darkCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accentNeon : Colors.white10,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accentNeon : Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 3: Total Monthly Budget
  // ==========================================
  Widget _buildStepBudget() {
    final double income = _parseFormattedAmount(_incomeController.text);
    final double suggested = income * 0.60;
    final double savings = income - suggested;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text("🎯", style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            "How much do you want to spend this month?",
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This is your total monthly limit. We'll warn you before you hit it.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),
          
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue.copyWith(text: '');
                final clean = newValue.text.replaceAll(RegExp(r'\D'), '');
                final formatted = _formatIndianRupees(clean);
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
            ],
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("₹", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: "0",
              hintStyle: const TextStyle(color: Colors.white12),
              filled: true,
              fillColor: AppColors.darkCardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.accentNeon, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Suggested details box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCardBg,
              borderRadius: BorderRadius.circular(16),
              border: const Border(
                left: BorderSide(color: AppColors.accentNeon, width: 3),
              ),
            ),
            child: Text(
              "💡 Based on your income, we suggest spending ₹${_formatIndianRupees(suggested.toStringAsFixed(0))} (60%). This leaves ₹${_formatIndianRupees(savings.toStringAsFixed(0))} for savings.",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Percent quick-select row
          Row(
            children: [
              _buildBudgetPercentChip("50%", income * 0.50),
              _buildBudgetPercentChip("60%", income * 0.60),
              _buildBudgetPercentChip("70%", income * 0.70),
            ],
          ),
          const Spacer(),
          
          SpringScaleButton(
            onTap: () {
              if (_parseFormattedAmount(_budgetController.text) <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid spending budget")),
                );
                return;
              }
              _nextPage();
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentNeon,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  "Next →",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetPercentChip(String label, double value) {
    final String formattedVal = _formatIndianRupees(value.toStringAsFixed(0));
    final isSelected = _budgetController.text == formattedVal;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _budgetController.text = formattedVal;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentNeon.withOpacity(0.12) : AppColors.darkCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accentNeon : Colors.white10,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accentNeon : Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 4: Category Budgets (6 categories)
  // ==========================================
  Widget _buildStepCategorySplits() {
    final double totalBudget = _parseFormattedAmount(_budgetController.text);
    
    double allocated = 0.0;
    _catControllers.forEach((key, controller) {
      allocated += _parseFormattedAmount(controller.text);
    });

    final double unallocated = totalBudget - allocated;
    final bool isOver = allocated > totalBudget;
    final bool isExact = allocated == totalBudget && totalBudget > 0;
    final double percent = totalBudget > 0 ? (allocated / totalBudget).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            "Split your budget by category 📊",
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "We've suggested amounts based on typical student spending. Adjust freely.",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          // 6 Category List
          Expanded(
            child: Stack(
              children: [
                ListView(
                  physics: const BouncingScrollPhysics(),
                  children: _catControllers.keys.map((catName) {
                    final controller = _catControllers[catName]!;
                    final emoji = _catEmojis[catName]!;
                    final double catBudget = _parseFormattedAmount(controller.text);
                    final double catPercent = totalBudget > 0 ? (catBudget / totalBudget) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.darkCardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.07)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    catName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                                  ),
                                ),
                                
                                // Rupee input field 100px wide
                                SizedBox(
                                  width: 110,
                                  height: 42,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.right,
                                    inputFormatters: [
                                      TextInputFormatter.withFunction((oldValue, newValue) {
                                        if (newValue.text.isEmpty) return newValue.copyWith(text: '');
                                        final clean = newValue.text.replaceAll(RegExp(r'\D'), '');
                                        final formatted = _formatIndianRupees(clean);
                                        return TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(offset: formatted.length),
                                        );
                                      }),
                                    ],
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    onChanged: (_) {
                                      setState(() {});
                                      if (_parseFormattedAmount(_budgetController.text) == 
                                          _catControllers.keys.fold(0.0, (sum, key) => sum + _parseFormattedAmount(_catControllers[key]!.text))) {
                                        _triggerExactBurst();
                                      }
                                    },
                                    decoration: InputDecoration(
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.only(left: 10.0, top: 11),
                                        child: Text("₹", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                      ),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.03),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Colors.white10),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: AppColors.accentNeon),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Line showing category percentage of total budget
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: catPercent.clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(_getCategoryColor(catName)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Tiny Green dots particle burst
                if (_showExactBurst)
                  Positioned(
                    bottom: 40,
                    left: MediaQuery.of(context).size.width / 2 - 50,
                    child: CustomPaint(
                      painter: BurstParticlesPainter(particles: _burstParticles),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // Bottom allocation status tracker
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Allocated ₹${_formatIndianRupees(allocated.toStringAsFixed(0))} of ₹${_formatIndianRupees(totalBudget.toStringAsFixed(0))}",
                    style: TextStyle(
                      color: isOver ? AppColors.alertOrange : (isExact ? AppColors.accentNeon : Colors.white70),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "${(percent * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      color: isOver ? AppColors.alertOrange : AppColors.accentNeon,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOver ? AppColors.alertOrange : AppColors.accentNeon,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Validation allocation text logic
              if (isOver)
                Text(
                  "⚠ You've exceeded your budget by ₹${_formatIndianRupees((allocated - totalBudget).toStringAsFixed(0))}. Reduce a category.",
                  style: const TextStyle(color: AppColors.alertOrange, fontSize: 12, fontWeight: FontWeight.w500),
                )
              else if (isExact)
                const Text(
                  "Perfect allocation! 🎯",
                  style: TextStyle(color: AppColors.accentNeon, fontSize: 12, fontWeight: FontWeight.bold),
                )
              else
                Text(
                  "₹${_formatIndianRupees(unallocated.toStringAsFixed(0))} unallocated — consider adding to savings",
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          
          const SizedBox(height: 20),

          SpringScaleButton(
            onTap: _nextPage,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentNeon,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  "Looks Good →",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String catName) {
    switch (catName) {
      case "Food & Beverages": return const Color(0xFFFF9500);
      case "Transport": return const Color(0xFF007AFF);
      case "Shopping": return const Color(0xFFFF2D55);
      case "Entertainment": return const Color(0xFFAF52DE);
      case "Bills & Utilities": return Colors.cyan;
      default: return Colors.grey;
    }
  }

  // ==========================================
  // STEP 5: Tracking Preferences (both SMS and CSV default highlight)
  // ==========================================
  Widget _buildStepPreferences() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            "How do you want to track expenses? 📲",
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You can use both. Most users prefer SMS + CSV together.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),

          // Card 1: SMS Auto-Detection (Recommended)
          AnimatedScale(
            scale: _showPreferencesAnimation ? 1.0 : 0.95,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _smsSelected = !_smsSelected;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.darkCardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _smsSelected ? AppColors.accentNeon : Colors.white.withOpacity(0.07),
                    width: _smsSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentNeon.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sms_rounded, color: AppColors.accentNeon, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "SMS Auto-Detection",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentNeon.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "Recommended",
                                  style: TextStyle(color: AppColors.accentNeon, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Bank messages are read instantly. Zero manual entry.",
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Text("✓ Works in background  ", style: TextStyle(color: AppColors.accentNeon, fontSize: 10)),
                              Text("✓ HDFC, SBI, ICICI, Axis", style: TextStyle(color: AppColors.accentNeon, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card 2: CSV Upload
          AnimatedScale(
            scale: _showPreferencesAnimation ? 1.0 : 0.95,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _csvSelected = !_csvSelected;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.darkCardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _csvSelected ? AppColors.accentNeon : Colors.white.withOpacity(0.07),
                    width: _csvSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.file_upload_rounded, color: Colors.white60, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "CSV Upload",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Upload your bank statement for full history.",
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          SizedBox(height: 8),
                          Text("✓ Any bank format supported", style: TextStyle(color: Colors.white30, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          
          if (_smsSelected)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Center(
                child: Text(
                  "We'll ask for SMS permission on the next step",
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ),
            ),
            
          SpringScaleButton(
            onTap: () {
              if (!_smsSelected && !_csvSelected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select at least one method")),
                );
                return;
              }
              _nextPage();
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentNeon,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  "Continue →",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 6: SMS Permission with animated phone bubbles
  // ==========================================
  Widget _buildStepSMSPermission() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SVG/Custom painted phone with bubbles floating up
          Center(
            child: SizedBox(
              height: 160,
              width: 200,
              child: AnimatedBuilder(
                animation: _phoneBubbleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: PhoneSMSBubblePainter(
                      progress: _phoneBubbleController.value,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Allow SMS Access 📩",
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "We need one-time permission to read bank messages.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),

          _buildTrustCard("Only bank sender IDs are read (HDFCBK, SBIINB, ICICIB, AXISBK)"),
          const SizedBox(height: 10),
          _buildTrustCard("Your messages are processed on-device first. Never stored raw."),
          const SizedBox(height: 10),
          _buildTrustCard("Turn off anytime in Settings → Permissions"),
          
          const Spacer(),
          
          SpringScaleButton(
            onTap: () async {
              final status = await Permission.sms.request();
              if (status.isGranted) {
                _nextPage();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("SMS permission denied. Falling back to CSV.")),
                  );
                }
                _nextPage();
              }
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentNeon,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  "Grant SMS Permission",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _nextPage,
              child: const Text(
                "Skip for now",
                style: TextStyle(color: Colors.white30, fontSize: 13, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustCard(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.darkCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.accentNeon, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 7: All Set Celebration Screen
  // ==========================================
  Widget _buildStepCelebration() {
    final String name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "Investor";
    final double budget = _parseFormattedAmount(_budgetController.text);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Falling Confetti Layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  painter: ConfettiPainter(progress: _confettiController.value),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Self-drawing checkmark
                Center(
                  child: SizedBox(
                    height: 100,
                    width: 100,
                    child: AnimatedBuilder(
                      animation: _checkmarkController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: DrawingCheckmarkPainter(progress: _checkmarkController.value),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                
                Text(
                  "You're all set, $name! 🎉",
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Your ₹${_formatIndianRupees(budget.toStringAsFixed(0))} monthly budget is ready. Here's what happens next:",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Staggered hints
                _buildStaggeredHint(0, "📲 SMS transactions will appear automatically"),
                const SizedBox(height: 10),
                _buildStaggeredHint(1, "📁 Upload a CSV to see your spending history"),
                const SizedBox(height: 10),
                _buildStaggeredHint(2, "💬 Ask the AI anything about your money"),
                
                const Spacer(),

                // Stacked buttons
                FadeUpEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: SpringScaleButton(
                    onTap: () => _completeWizard(uploadCsvFirst: false),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.accentNeon,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text(
                          "Go to Dashboard",
                          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeUpEntrance(
                  delay: const Duration(milliseconds: 380),
                  child: SpringScaleButton(
                    onTap: () => _completeWizard(uploadCsvFirst: true),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text(
                          "Upload a CSV first",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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

  Widget _buildStaggeredHint(int index, String text) {
    return FadeUpEntrance(
      delay: Duration(milliseconds: 80 * index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.darkCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

// ==========================================
// Custom Painter for phone bubbles (Step 6)
// ==========================================
class PhoneSMSBubblePainter extends CustomPainter {
  final double progress;
  PhoneSMSBubblePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw Phone base outline
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 60, height: 100),
      const Radius.circular(12),
    );
    canvas.drawRRect(phoneRect, paint);

    // Dynamic bubbles floating upward
    final bubblePaint = Paint()
      ..color = AppColors.accentNeon
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final double individualProgress = (progress + (i * 0.33)) % 1.0;
      final double y = center.dy - 30 - (individualProgress * 70);
      final double x = center.dx + (math.sin(individualProgress * 4 * math.pi) * 10);
      final double radius = 8 * (1 - individualProgress * 0.5);
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        bubblePaint..color = AppColors.accentNeon.withOpacity(0.8 * (1 - individualProgress)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PhoneSMSBubblePainter oldDelegate) => true;
}

// ==========================================
// Custom Painter for checkmark (Step 7)
// ==========================================
class DrawingCheckmarkPainter extends CustomPainter {
  final double progress;
  DrawingCheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = AppColors.accentNeon.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    // Background glow ring
    canvas.drawCircle(center, radius, ringPaint);

    final greenRing = Paint()
      ..color = AppColors.accentNeon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius - 2, greenRing..color = AppColors.accentNeon.withOpacity(0.3));

    // Self drawing checkmark path
    final path = Path();
    path.moveTo(center.dx - 20, center.dy + 2);
    path.lineTo(center.dx - 6, center.dy + 16);
    path.lineTo(center.dx + 22, center.dy - 12);

    final pMeasure = PathMetricsPainter(path: path, progress: progress);
    canvas.drawPath(pMeasure.getExtractPath(), greenRing..color = AppColors.accentNeon);
  }

  @override
  bool shouldRepaint(covariant DrawingCheckmarkPainter oldDelegate) => true;
}

class PathMetricsPainter {
  final Path path;
  final double progress;

  PathMetricsPainter({required this.path, required this.progress});

  Path getExtractPath() {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return Path();
    final firstMetric = metrics.first;
    final extractLen = firstMetric.length * progress;
    return firstMetric.extractPath(0, extractLen);
  }
}

// ==========================================
// Custom Confetti Painter (Step 7)
// ==========================================
class ConfettiPainter extends CustomPainter {
  final double progress;
  ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // Seeding to keep positions stable
    final List<Color> colors = [AppColors.accentNeon, Colors.white, AppColors.successGreen];
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      final double startX = random.nextDouble() * size.width;
      final double fallSpeed = 100 + random.nextDouble() * 200;
      final double y = (progress * fallSpeed + (i * 20)) % size.height;
      final double x = startX + math.sin(progress * 2 * math.pi + i) * 15;
      final double r = 3 + random.nextDouble() * 4;
      
      paint.color = colors[random.nextInt(colors.length)].withOpacity(1 - (y / size.height).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}

// ==========================================
// Custom Burst Painter (Step 4 exactly allocated)
// ==========================================
class BurstParticlesPainter extends CustomPainter {
  final List<Offset> particles;
  BurstParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentNeon
      ..style = PaintingStyle.fill;

    for (var offset in particles) {
      canvas.drawCircle(offset, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BurstParticlesPainter oldDelegate) => true;
}
