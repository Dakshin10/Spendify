import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../budgets/budgets_screen.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../profile/profile_screen.dart';
import '../transactions/transactions_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  final List<Widget> screens = [
    const HomeScreen(),
    const TransactionsScreen(),
    const InsightsScreen(),
    const BudgetsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, child) {
        final currentTab = AppState.instance.currentTab;
        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: currentTab,
            children: screens,
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkCardBg : Colors.white).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double barWidth = constraints.maxWidth;
                          final double itemWidth = barWidth / 5;
                          return Stack(
                            children: [
                              // Animated background sliding capsule
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutBack,
                                left: currentTab * itemWidth + 8,
                                top: 8,
                                bottom: 8,
                                width: itemWidth - 16,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? [
                                              AppColors.accentNeon.withOpacity(0.18),
                                              AppColors.accentNeon.withOpacity(0.05),
                                            ]
                                          : [
                                              AppColors.lightGradient[0].withOpacity(0.15),
                                              AppColors.lightGradient[1].withOpacity(0.04),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.accentNeon.withOpacity(0.25)
                                          : AppColors.lightGradient[0].withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                              // Navigation items Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildNavItem(context, 0, Icons.home_rounded, "Home", currentTab, isDark),
                                  _buildNavItem(context, 1, Icons.swap_horiz_rounded, "Transactions", currentTab, isDark),
                                  _buildNavItem(context, 2, Icons.bar_chart_rounded, "Insights", currentTab, isDark),
                                  _buildNavItem(context, 3, Icons.account_balance_wallet_rounded, "Budgets", currentTab, isDark),
                                  _buildNavItem(context, 4, Icons.person_rounded, "Profile", currentTab, isDark),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label, int activeTab, bool isDark) {
    final isSelected = activeTab == index;
    final activeColor = isDark ? AppColors.accentNeon : AppColors.lightGradient[0];
    final inactiveColor = isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppState.instance.setTab(index);
          try {
            HapticFeedback.selectionClick();
          } catch (_) {}
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontFamily: GoogleFonts.outfit().fontFamily,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}


