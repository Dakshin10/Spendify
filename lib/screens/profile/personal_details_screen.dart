import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../onboarding/onboarding_wizard_screen.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // ── Section 1: Who Are You? ──────────────────────────────────────────────
  final _fullNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _dobController = TextEditingController();
  String _selectedGender = '';



  // ── Section 3: Life Stage ────────────────────────────────────────────────
  String _selectedLifeStage = '';

  // ── Section 4: Money Profile ─────────────────────────────────────────────
  final _bankController = TextEditingController();
  final _upiController = TextEditingController();
  final _incomeController = TextEditingController();
  String _selectedSpendingStyle = '';
  final Set<String> _selectedChallenges = {};

  // ── Section 5: Preferences ───────────────────────────────────────────────
  bool _notifyTransactions = true;
  bool _notifyBudget = true;
  bool _notifyMonthly = true;

  // ── UI State ─────────────────────────────────────────────────────────────
  late AnimationController _progressController;
  late Animation<double> _progressAnim;
  late AnimationController _fabController;
  bool _isSaving = false;

  // Focus nodes
  final _fullNameFocus = FocusNode();
  final _displayNameFocus = FocusNode();
  final _dobFocus = FocusNode();

  final _bankFocus = FocusNode();
  final _upiFocus = FocusNode();
  final _incomeFocus = FocusNode();

  static const List<String> _genders = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];


  static const List<Map<String, dynamic>> _lifeStages = [
    {'id': 'student', 'label': 'College Student', 'emoji': '🎓', 'sub': 'Budgeting on a tight allowance'},
    {'id': 'working', 'label': 'Working Professional', 'emoji': '💼', 'sub': 'Managing salary & expenses'},
    {'id': 'freelancer', 'label': 'Freelancer', 'emoji': '💻', 'sub': 'Variable income, flexible life'},
    {'id': 'business', 'label': 'Business Owner', 'emoji': '🏢', 'sub': 'Mixing personal & business'},
    {'id': 'homemaker', 'label': 'Homemaker', 'emoji': '🏠', 'sub': 'Managing household finances'},
    {'id': 'retired', 'label': 'Retired', 'emoji': '🌿', 'sub': 'Living on savings & pension'},
  ];

  static const List<Map<String, dynamic>> _spendingStyles = [
    {'id': 'saver', 'label': 'Saver 🐝', 'sub': 'Every rupee counts'},
    {'id': 'balanced', 'label': 'Balanced ⚖️', 'sub': 'Save some, spend some'},
    {'id': 'spender', 'label': 'Spender 🛍️', 'sub': 'You live for today'},
    {'id': 'investor', 'label': 'Investor 📈', 'sub': 'Grow wealth first'},
  ];

  static const List<String> _challenges = [
    'Eating out too much 🍕',
    'Impulse shopping 🛒',
    'Subscription creep 📱',
    'Forgetting to track 📝',
    'Splitting bills with friends 👥',
    'Managing irregular income 💸',
    'Saving consistently 🏦',
    'Overspending on travel ✈️',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 0.12).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
    _progressController.forward();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabController.forward();



    // Auto-fill display name from full name
    _fullNameController.addListener(() {
      if (_displayNameController.text.isEmpty) {
        final parts = _fullNameController.text.trim().split(' ');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          _displayNameController.text = parts[0];
          _displayNameController.selection = TextSelection.fromPosition(
            TextPosition(offset: _displayNameController.text.length),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fabController.dispose();
    _scrollController.dispose();
    _fullNameController.dispose();
    _displayNameController.dispose();
    _dobController.dispose();
    _bankController.dispose();
    _upiController.dispose();
    _incomeController.dispose();
    _fullNameFocus.dispose();
    _displayNameFocus.dispose();
    _dobFocus.dispose();
    _bankFocus.dispose();
    _upiFocus.dispose();
    _incomeFocus.dispose();
    super.dispose();
  }



  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 10),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.accentNeon,
              onPrimary: Colors.black,
              surface: const Color(0xFF151915),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0A0B0A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
      });
    }
  }

  Future<void> _showBackConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151915),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Go back?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your account has been created but your profile won\'t be saved.',
          style: GoogleFonts.inter(color: const Color(0xFF888E88), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Stay', style: GoogleFonts.inter(color: AppColors.accentNeon)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Go Back', style: GoogleFonts.inter(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _skipAndProceed() async {
    // Fill defaults and proceed
    await AppState.instance.savePersonalDetails(
      fullName: _fullNameController.text.trim().isNotEmpty
          ? _fullNameController.text.trim()
          : AppState.instance.userName,
      displayName: _displayNameController.text.trim().isNotEmpty
          ? _displayNameController.text.trim()
          : AppState.instance.userName,
      dateOfBirth: _dobController.text,
      gender: _selectedGender,
      city: '',
      state: '',
      lifeStage: _selectedLifeStage,
      primaryBank: _bankController.text.trim(),
      upiId: _upiController.text.trim(),
      income: double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0,
      spendingStyle: _selectedSpendingStyle,
      moneyChallenge: _selectedChallenges.toList(),
      notifyTransactions: _notifyTransactions,
      notifyBudget: _notifyBudget,
      notifyMonthly: _notifyMonthly,
    );
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => const OnboardingWizardScreen(),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    }
  }

  Future<void> _saveAndProceed() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Validation: full name is the only required field
    if (_fullNameController.text.trim().isEmpty) {
      setState(() => _isSaving = false);
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _showValidationSnack('Please enter your full name to continue');
      return;
    }

    await AppState.instance.savePersonalDetails(
      fullName: _fullNameController.text.trim(),
      displayName: _displayNameController.text.trim(),
      dateOfBirth: _dobController.text,
      gender: _selectedGender,
      city: '',
      state: '',
      lifeStage: _selectedLifeStage,
      primaryBank: _bankController.text.trim(),
      upiId: _upiController.text.trim(),
      income: double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0,
      spendingStyle: _selectedSpendingStyle,
      moneyChallenge: _selectedChallenges.toList(),
      notifyTransactions: _notifyTransactions,
      notifyBudget: _notifyBudget,
      notifyMonthly: _notifyMonthly,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => const OnboardingWizardScreen(),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    }
  }

  void _showValidationSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // ── Subtle radial glow behind progress bar ──────────────────
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      AppColors.accentNeon.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── Top Bar ─────────────────────────────────────────────
                  _buildTopBar(),

                  // ── Progress Bar ─────────────────────────────────────────
                  _buildProgressBar(),

                  // ── Scrollable Content ───────────────────────────────────
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 28),
                              _buildScreenHeader(),
                              const SizedBox(height: 32),
                              _buildSection1(),
                              _buildDivider(),
                              _buildSection3(),
                              _buildDivider(),
                              _buildSection4(),
                              _buildDivider(),
                              _buildSection5(),
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── City Suggestions Overlay ─────────────────────────────────


            // ── Fixed Bottom CTA ─────────────────────────────────────────
            _buildBottomCTA(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconButton(
            onTap: _showBackConfirmation,
            icon: Icons.arrow_back_rounded,
          ),
          const Spacer(),
          GestureDetector(
            onTap: _skipAndProceed,
            child: Text(
              'Skip for now',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF888E88),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROGRESS BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progressAnim.value,
                  backgroundColor: const Color(0xFF1F241F),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentNeon),
                  minHeight: 3,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Step 0 of 8 — Profile Setup',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF888E88),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCREEN HEADER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildScreenHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about\nyourself 👋',
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This helps us personalise Spendify for you.\nAll fields are optional except your name.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF888E88),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION HEADER BUILDER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String number, String title, String emoji) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentNeon.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentNeon.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentNeon,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$title $emoji',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION 1: WHO ARE YOU?
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSection1() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('1', 'Who Are You?', '🧑'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildInputField(
                  controller: _fullNameController,
                  focusNode: _fullNameFocus,
                  nextFocusNode: _displayNameFocus,
                  label: 'Full Name',
                  hint: 'Riya Sharma',
                  isRequired: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _displayNameController,
                  focusNode: _displayNameFocus,
                  nextFocusNode: _dobFocus,
                  label: 'Display Name',
                  hint: 'What should we call you? (e.g. Riya)',
                  textCapitalization: TextCapitalization.words,
                  helperText: 'This appears in greetings across the app',
                ),
                const SizedBox(height: 16),
                _buildDateField(),
                const SizedBox(height: 20),
                _buildGenderSelector(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: _buildInputField(
          controller: _dobController,
          focusNode: _dobFocus,
          label: 'Date of Birth',
          hint: 'DD / MM / YYYY',
          suffixIcon: Icons.calendar_today_rounded,
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF888E88),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _genders.map((g) {
            final selected = _selectedGender == g;
            return GestureDetector(
              onTap: () => setState(() => _selectedGender = selected ? '' : g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentNeon.withOpacity(0.12)
                      : const Color(0xFF151915),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? AppColors.accentNeon : const Color(0xFF1F241F),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  g,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.accentNeon : Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }



  // ══════════════════════════════════════════════════════════════════════════
  // SECTION 3: LIFE STAGE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSection3() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('2', 'Life Stage', '🎯'),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _lifeStages.length,
              itemBuilder: (_, i) {
                final stage = _lifeStages[i];
                final selected = _selectedLifeStage == stage['id'];
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedLifeStage = selected ? '' : stage['id'] as String,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 140,
                    margin: EdgeInsets.only(right: i < _lifeStages.length - 1 ? 12 : 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentNeon.withOpacity(0.12)
                          : const Color(0xFF151915),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? AppColors.accentNeon : const Color(0xFF1F241F),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          stage['emoji'] as String,
                          style: const TextStyle(fontSize: 28),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stage['label'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected ? AppColors.accentNeon : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              stage['sub'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: selected
                                    ? AppColors.accentNeon.withOpacity(0.7)
                                    : const Color(0xFF888E88),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION 4: MONEY PROFILE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSection4() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('3', 'Your Money Profile', '💰'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(
                  controller: _bankController,
                  focusNode: _bankFocus,
                  nextFocusNode: _upiFocus,
                  label: 'Primary Bank',
                  hint: 'e.g. HDFC, ICICI, SBI',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _upiController,
                  focusNode: _upiFocus,
                  nextFocusNode: _incomeFocus,
                  label: 'UPI ID (optional)',
                  hint: 'yourname@upi',
                  keyboardType: TextInputType.emailAddress,
                  helperText: 'Used for smart transaction matching',
                ),
                const SizedBox(height: 16),
                _buildIncomeField(),
                const SizedBox(height: 24),
                _buildSpendingPersonality(),
                const SizedBox(height: 24),
                _buildChallengesSelector(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Income',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF888E88),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _incomeController,
          focusNode: _incomeFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2A2E2A),
            ),
            prefixText: '₹  ',
            prefixStyle: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.accentNeon,
            ),
            filled: true,
            fillColor: const Color(0xFF151915),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1F241F)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1F241F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accentNeon, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            helperText: 'We use this to suggest realistic budgets',
            helperStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF888E88)),
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingPersonality() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spending Personality',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF888E88),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Which one describes you best?',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF555B55)),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
          ),
          itemCount: _spendingStyles.length,
          itemBuilder: (_, i) {
            final style = _spendingStyles[i];
            final selected = _selectedSpendingStyle == style['id'];
            return GestureDetector(
              onTap: () => setState(
                () => _selectedSpendingStyle = selected ? '' : style['id'] as String,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentNeon.withOpacity(0.12)
                      : const Color(0xFF151915),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.accentNeon : const Color(0xFF1F241F),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      style['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.accentNeon : Colors.white,
                      ),
                    ),
                    Text(
                      style['sub'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: selected
                            ? AppColors.accentNeon.withOpacity(0.7)
                            : const Color(0xFF888E88),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChallengesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biggest Money Challenges',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF888E88),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select all that apply',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF555B55)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _challenges.map((c) {
            final selected = _selectedChallenges.contains(c);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedChallenges.remove(c);
                  } else {
                    _selectedChallenges.add(c);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentNeon.withOpacity(0.12)
                      : const Color(0xFF151915),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.accentNeon : const Color(0xFF1F241F),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  c,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.accentNeon : Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION 5: PREFERENCES
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSection5() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('4', 'Preferences', '🔔'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildNotifTile(
                  title: 'Transaction Alerts',
                  sub: 'Instant notification when money moves',
                  value: _notifyTransactions,
                  onChanged: (v) => setState(() => _notifyTransactions = v),
                ),
                _buildNotifTile(
                  title: 'Budget Warnings',
                  sub: 'Alert when you\'re close to a limit',
                  value: _notifyBudget,
                  onChanged: (v) => setState(() => _notifyBudget = v),
                ),
                _buildNotifTile(
                  title: 'Monthly Summary',
                  sub: 'Monthly spending report on the 1st',
                  value: _notifyMonthly,
                  onChanged: (v) => setState(() => _notifyMonthly = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifTile({
    required String title,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF151915),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F241F)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF888E88),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentNeon,
            activeTrackColor: AppColors.accentNeon.withOpacity(0.25),
            inactiveThumbColor: const Color(0xFF555B55),
            inactiveTrackColor: const Color(0xFF1F241F),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED FIELD BUILDER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required String hint,
    bool isRequired = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF888E88),
                letterSpacing: 0.3,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentNeon,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textInputAction:
              nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) {
            if (nextFocusNode != null) {
              FocusScope.of(context).requestFocus(nextFocusNode);
            } else {
              FocusScope.of(context).unfocus();
            }
          },
          decoration: _inputDecoration(hint, suffixIcon: suffixIcon, helperText: helperText),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint,
      {IconData? suffixIcon, String? helperText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF555B55)),
      filled: true,
      fillColor: const Color(0xFF151915),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1F241F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1F241F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accentNeon, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: const Color(0xFF888E88), size: 20)
          : null,
      helperText: helperText,
      helperStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF888E88)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIVIDER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(height: 1, color: const Color(0xFF1A1E1A)),
    );
  }



  // ══════════════════════════════════════════════════════════════════════════
  // BOTTOM CTA
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomCTA() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.darkBg.withOpacity(0),
              AppColors.darkBg.withOpacity(0.95),
              AppColors.darkBg,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: AnimatedBuilder(
              animation: _fabController,
              builder: (_, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - _fabController.value) * 80),
                  child: Opacity(opacity: _fabController.value, child: child),
                );
              },
              child: GestureDetector(
                onTap: _saveAndProceed,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _isSaving ? AppColors.accentNeon.withOpacity(0.5) : AppColors.accentNeon,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentNeon.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Save & Continue',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.black, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// REUSABLE ICON BUTTON
// ══════════════════════════════════════════════════════════════════════════
class _IconButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;

  const _IconButton({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF151915),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F241F)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
