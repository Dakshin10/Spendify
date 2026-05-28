import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/custom_animations.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 3;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _numPages - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    // Restart autoplay timer on manual swipe
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Pure black background
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Top: 3 dot page indicator (wider active green dot)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_numPages, (index) {
                final isActive = index == _currentPage;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: isActive ? 24 : 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.accentNeon : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildSlide(
                    iconWidget: const AnimatedSMSPhoneIcon(),
                    title: "Expenses tracked\nautomatically",
                    subtitle: "Spendify reads your bank SMS alerts and logs every transaction the moment it happens. No manual entry ever.",
                    trustNote: "🔒 We never read personal messages",
                  ),
                  _buildSlide(
                    iconWidget: const AnimatedGrowingBarChart(),
                    title: "Understand where\nyour money goes",
                    subtitle: "AI-powered categories, anomaly detection, and plain-English insights. Ask anything about your spending.",
                  ),
                  _buildSlide(
                    iconWidget: const AnimatedCircularRingIcon(),
                    title: "Set budgets.\nStay in control.",
                    subtitle: "Monthly budgets per category with real-time alerts. Know when you're about to overspend before it happens.",
                  ),
                ],
              ),
            ),

            // Fixed Bottom Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  // Create Free Account Spring Button
                  SpringScaleButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        AppPageTransitions.buildParallaxRoute(const SignupScreen()),
                      );
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
                          "Create Free Account",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Login Trigger Link
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        AppPageTransitions.buildParallaxRoute(const LoginScreen()),
                      );
                    },
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                        children: [
                          TextSpan(text: "Already have an account? "),
                          TextSpan(
                            text: "Log In",
                            style: TextStyle(color: AppColors.accentNeon, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    String? trustNote,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Centered Animated Icon Area
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: AppColors.darkCardBg,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Center(child: iconWidget),
          ),
          const Spacer(flex: 2),
          // Heading Text
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle Text
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (trustNote != null) ...[
            const SizedBox(height: 16),
            Text(
              trustNote,
              style: const TextStyle(
                color: AppColors.accentNeon,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ==========================================
// Slide 1 Icon: Looping SMS phone bubble animation
// ==========================================
class AnimatedSMSPhoneIcon extends StatefulWidget {
  const AnimatedSMSPhoneIcon({super.key});

  @override
  State<AnimatedSMSPhoneIcon> createState() => _AnimatedSMSPhoneIconState();
}

class _AnimatedSMSPhoneIconState extends State<AnimatedSMSPhoneIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bubbleOpacity;
  late Animation<double> _bubbleOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Bubble fades in, stays, fades out
    _bubbleOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    // Bubble moves upward
    _bubbleOffset = Tween<double>(begin: 20.0, end: -10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer rings
        Container(
          height: 130,
          width: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentNeon.withOpacity(0.04),
          ),
        ),
        Container(
          height: 90,
          width: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentNeon.withOpacity(0.08),
          ),
        ),
        
        // Base Phone Icon
        const Icon(
          Icons.phone_iphone_rounded,
          size: 64,
          color: Colors.white38,
        ),
        
        // Floating SMS Bubble
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(28, _bubbleOffset.value),
              child: Opacity(
                opacity: _bubbleOpacity.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentNeon,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentNeon.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sms_rounded,
                    size: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ==========================================
// Slide 2 Icon: Looping animated bar chart grows
// ==========================================
class AnimatedGrowingBarChart extends StatefulWidget {
  const AnimatedGrowingBarChart({super.key});

  @override
  State<AnimatedGrowingBarChart> createState() => _AnimatedGrowingBarChartState();
}

class _AnimatedGrowingBarChartState extends State<AnimatedGrowingBarChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _barHeights;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _barHeights = List.generate(4, (index) {
      // Staggered growing timeline for each of the 4 bars
      final start = index * 0.15;
      final end = start + 0.35;
      final items = <TweenSequenceItem<double>>[];
      
      if (start > 0.0) {
        items.add(TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: start * 100));
      }
      
      items.add(TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 35));
      
      final remainingWeight = (0.8 - end) * 100 + 20;
      if (remainingWeight > 0.0) {
        items.add(TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: remainingWeight));
      }
      
      return TweenSequence(items).animate(_controller);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColors = [
      AppColors.accentNeon,
      Colors.tealAccent,
      AppColors.successGreen,
      Colors.greenAccent,
    ];
    final maxHeights = [50.0, 85.0, 60.0, 75.0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double animatedHeight = maxHeights[index] * _barHeights[index].value;
              return Container(
                height: animatedHeight.clamp(4.0, 100.0),
                width: 14,
                decoration: BoxDecoration(
                  color: barColors[index],
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    if (_barHeights[index].value > 0)
                      BoxShadow(
                        color: barColors[index].withOpacity(0.3),
                        blurRadius: 6,
                      ),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

// ==========================================
// Slide 3 Icon: Looping progress fills to 70%
// ==========================================
class AnimatedCircularRingIcon extends StatefulWidget {
  const AnimatedCircularRingIcon({super.key});

  @override
  State<AnimatedCircularRingIcon> createState() => _AnimatedCircularRingIconState();
}

class _AnimatedCircularRingIconState extends State<AnimatedCircularRingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _ringProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _ringProgress = TweenSequence([
      // Fills to 70% (0.7) during first 50% of the timeline
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.7).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 50),
      // Stays at 70% for the remaining 50%
      TweenSequenceItem(tween: ConstantTween<double>(0.7), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: CircularProgressIndicator(
                value: _ringProgress.value,
                strokeWidth: 10,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentNeon),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${(_ringProgress.value * 100).toStringAsFixed(0)}%",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Budget",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}