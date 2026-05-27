import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/custom_animations.dart';
import '../../services/auth_service.dart';
import '../main/main_navigation_screen.dart';
import '../../wrappers/auth_wrapper.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  final authService = AuthService();

  // Focus states
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;

  // Validation / Error states
  bool _emailHasError = false;
  bool _passwordHasError = false;
  bool _showErrorBanner = false;
  String _bannerMessage = "Incorrect email or password. Try again.";

  // Password visibility
  bool _obscurePassword = true;

  // GlobalKeys for shake animations
  final GlobalKey<ShakeWidgetState> _emailShakeKey = GlobalKey<ShakeWidgetState>();
  final GlobalKey<ShakeWidgetState> _passwordShakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _triggerErrorBanner(String message) {
    setState(() {
      _bannerMessage = message;
      _showErrorBanner = true;
      _emailHasError = true;
      _passwordHasError = true;
    });
    _emailShakeKey.currentState?.shake();
    _passwordShakeKey.currentState?.shake();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showErrorBanner = false;
        });
      }
    });
  }

  // =========================================
  // EMAIL LOGIN
  // =========================================
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() {
      _emailHasError = email.isEmpty;
      _passwordHasError = password.isEmpty;
    });

    if (email.isEmpty || password.isEmpty) {
      if (email.isEmpty) _emailShakeKey.currentState?.shake();
      if (password.isEmpty) _passwordShakeKey.currentState?.shake();
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      await authService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        AppPageTransitions.buildParallaxRoute(const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim();
      _triggerErrorBanner(errorMsg.contains("invalid") || errorMsg.contains("wrong") || errorMsg.contains("user-not-found")
          ? "Incorrect email or password. Try again."
          : errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================
  // GOOGLE LOGIN
  // =========================================
  Future<void> googleLogin() async {
    try {
      setState(() {
        isLoading = true;
      });

      final result = await authService.signInWithGoogle();

      if (result != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          AppPageTransitions.buildParallaxRoute(const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      _triggerErrorBanner(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Stack(
        children: [
          // Main Body
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      // Logo / Icon
                      FadeUpEntrance(
                        delay: Duration.zero,
                        child: Container(
                          height: 70,
                          width: 70,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accentNeon, AppColors.successGreen],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 60),
                        child: Text(
                          "Welcome Back 👋",
                          style: AppTextStyles.heading.copyWith(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 110),
                        child: Text(
                          "Login to continue tracking your expenses",
                          style: AppTextStyles.body.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Email Field (Shake + Focus Glow)
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 160),
                        child: ShakeWidget(
                          key: _emailShakeKey,
                          child: Focus(
                            onFocusChange: (hasFocus) {
                              setState(() {
                                _emailHasFocus = hasFocus;
                                if (hasFocus) _emailHasError = false;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  if (_emailHasFocus && !_emailHasError)
                                    BoxShadow(
                                      color: (isDark ? AppColors.accentNeon : AppColors.lightGradient[0]).withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 1.5,
                                    ),
                                ],
                              ),
                              child: TextField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: "Email Address",
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: isDark ? AppColors.darkCardBg : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: _emailHasError
                                          ? AppColors.errorRed
                                          : (isDark ? Colors.white.withOpacity(0.07) : AppColors.lightBorder),
                                      width: _emailHasError ? 1.5 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: _emailHasError
                                          ? AppColors.errorRed
                                          : (isDark ? AppColors.accentNeon : AppColors.lightGradient[0]),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password Field (Visibility toggle + Shake + Focus Glow)
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 210),
                        child: ShakeWidget(
                          key: _passwordShakeKey,
                          child: Focus(
                            onFocusChange: (hasFocus) {
                              setState(() {
                                _passwordHasFocus = hasFocus;
                                if (hasFocus) _passwordHasError = false;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  if (_passwordHasFocus && !_passwordHasError)
                                    BoxShadow(
                                      color: (isDark ? AppColors.accentNeon : AppColors.lightGradient[0]).withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 1.5,
                                    ),
                                ],
                              ),
                              child: TextField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: "Password",
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: Colors.grey.shade500,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? AppColors.darkCardBg : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: _passwordHasError
                                          ? AppColors.errorRed
                                          : (isDark ? Colors.white.withOpacity(0.07) : AppColors.lightBorder),
                                      width: _passwordHasError ? 1.5 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: _passwordHasError
                                          ? AppColors.errorRed
                                          : (isDark ? AppColors.accentNeon : AppColors.lightGradient[0]),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Forgot Password Link
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 260),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Reset email placeholder triggered")),
                              );
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: AppColors.accentNeon,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Login Spring Button
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 310),
                        child: SpringScaleButton(
                          onTap: isLoading ? () {} : login,
                          child: Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isDark ? Colors.black : Colors.white,
                                      ),
                                    )
                                  : Text(
                                      "Login",
                                      style: AppTextStyles.button.copyWith(
                                        color: isDark ? Colors.black : Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // OR Divider
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 360),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.white.withOpacity(0.12) : AppColors.lightBorder,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.white.withOpacity(0.12) : AppColors.lightBorder,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Google Sign-In Spring Button
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 410),
                        child: SpringScaleButton(
                          onTap: isLoading ? () {} : googleLogin,
                          child: Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCardBg : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.07) : AppColors.lightBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const GoogleGLogo(size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  "Continue with Google",
                                  style: AppTextStyles.button.copyWith(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Sign Up navigation Link
                      FadeUpEntrance(
                        delay: const Duration(milliseconds: 460),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  AppPageTransitions.buildParallaxRoute(const SignupScreen()),
                                );
                              },
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: AppColors.accentNeon,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Slide-down Red Error Banner
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            top: _showErrorBanner ? 0.0 : -90.0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.errorRed,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _bannerMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Vector Google G Logo Widget
class GoogleGLogo extends StatelessWidget {
  final double size;
  const GoogleGLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleGLogoPainter(),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final center = Offset(r, r);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.45
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    final rect = Rect.fromCircle(center: center, radius: r * 0.775);

    // Red: Top segment
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.4, false, paint);

    // Yellow: Left segment
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.9, 1.55, false, paint);

    // Green: Bottom segment
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.4, 1.5, false, paint);

    // Blue: Right segment + horizontal bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -1.0, 1.45, false, paint);

    // Draw horizontal bar of Google G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final barRect = Rect.fromLTWH(r, r - (r * 0.225), r * 0.775, r * 0.45);
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}