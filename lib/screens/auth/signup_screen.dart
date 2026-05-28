import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/custom_animations.dart';
import '../../services/auth_service.dart';
import '../main/main_navigation_screen.dart';
import '../../wrappers/auth_wrapper.dart';
import 'login_screen.dart'; // To reuse GoogleGLogo

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  
  bool isLoading = false;
  final authService = AuthService();

  // Focus states
  bool _nameHasFocus = false;
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;
  bool _confirmHasFocus = false;

  // Validation / Error states
  bool _nameHasError = false;
  bool _emailHasError = false;
  bool _passwordHasError = false;
  bool _confirmHasError = false;
  
  String? _nameErrorText;
  String? _emailErrorText;
  String? _passwordErrorText;
  String? _confirmErrorText;

  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Shake keys
  final GlobalKey<ShakeWidgetState> _nameShakeKey = GlobalKey<ShakeWidgetState>();
  final GlobalKey<ShakeWidgetState> _emailShakeKey = GlobalKey<ShakeWidgetState>();
  final GlobalKey<ShakeWidgetState> _passwordShakeKey = GlobalKey<ShakeWidgetState>();
  final GlobalKey<ShakeWidgetState> _confirmShakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmController.text.trim();

    setState(() {
      _nameHasError = name.isEmpty;
      _nameErrorText = name.isEmpty ? "Full Name is required" : null;
      
      _emailHasError = email.isEmpty || !email.contains('@');
      _emailErrorText = email.isEmpty 
          ? "Email Address is required" 
          : (!email.contains('@') ? "Enter a valid email address" : null);
      
      _passwordHasError = password.isEmpty || password.length < 6;
      _passwordErrorText = password.isEmpty 
          ? "Password is required" 
          : (password.length < 6 ? "Password must be at least 6 characters" : null);
      
      _confirmHasError = confirmPassword.isEmpty || password != confirmPassword;
      _confirmErrorText = confirmPassword.isEmpty 
          ? "Confirm Password is required" 
          : (password != confirmPassword ? "Passwords do not match" : null);
    });

    if (_nameHasError) _nameShakeKey.currentState?.shake();
    if (_emailHasError) _emailShakeKey.currentState?.shake();
    if (_passwordHasError) _passwordShakeKey.currentState?.shake();
    if (_confirmHasError) _confirmShakeKey.currentState?.shake();

    if (_nameHasError || _emailHasError || _passwordHasError || _confirmHasError) {
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      await authService.signup(
        email: email,
        password: password,
      );

      // Save name to profile / settings
      await authService.updateDisplayName(name);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        AppPageTransitions.buildParallaxRoute(const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()),
          backgroundColor: AppColors.errorRed,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()),
          backgroundColor: AppColors.errorRed,
        ),
      );
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Back Arrow
                  FadeUpEntrance(
                    delay: Duration.zero,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Spendify logo icon 40px green
                  FadeUpEntrance(
                    delay: const Duration(milliseconds: 40),
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accentNeon, AppColors.successGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  FadeUpEntrance(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      "Create Account 🚀",
                      style: AppTextStyles.heading.copyWith(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeUpEntrance(
                    delay: const Duration(milliseconds: 120),
                    child: Text(
                      "Start tracking your finances today",
                      style: AppTextStyles.body.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 1. Full Name
                  _buildAnimatedField(
                    shakeKey: _nameShakeKey,
                    controller: nameController,
                    hintText: "Full Name",
                    keyboardType: TextInputType.name,
                    delay: const Duration(milliseconds: 160),
                    hasFocus: _nameHasFocus,
                    hasError: _nameHasError,
                    errorText: _nameErrorText,
                    onFocusChange: (focus) {
                      setState(() {
                        _nameHasFocus = focus;
                        if (focus) _nameHasError = false;
                      });
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // 2. Email Address
                  _buildAnimatedField(
                    shakeKey: _emailShakeKey,
                    controller: emailController,
                    hintText: "Email Address",
                    keyboardType: TextInputType.emailAddress,
                    delay: const Duration(milliseconds: 200),
                    hasFocus: _emailHasFocus,
                    hasError: _emailHasError,
                    errorText: _emailErrorText,
                    onFocusChange: (focus) {
                      setState(() {
                        _emailHasFocus = focus;
                        if (focus) _emailHasError = false;
                      });
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // 3. Password Field
                  _buildAnimatedField(
                    shakeKey: _passwordShakeKey,
                    controller: passwordController,
                    hintText: "Password",
                    obscureText: _obscurePassword,
                    delay: const Duration(milliseconds: 240),
                    hasFocus: _passwordHasFocus,
                    hasError: _passwordHasError,
                    errorText: _passwordErrorText,
                    onFocusChange: (focus) {
                      setState(() {
                        _passwordHasFocus = focus;
                        if (focus) _passwordHasError = false;
                      });
                    },
                    suffixIcon: IconButton(
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
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // 4. Confirm Password Field
                  _buildAnimatedField(
                    shakeKey: _confirmShakeKey,
                    controller: confirmController,
                    hintText: "Confirm Password",
                    obscureText: _obscureConfirmPassword,
                    delay: const Duration(milliseconds: 280),
                    hasFocus: _confirmHasFocus,
                    hasError: _confirmHasError,
                    errorText: _confirmErrorText,
                    onFocusChange: (focus) {
                      setState(() {
                        _confirmHasFocus = focus;
                        if (focus) _confirmHasError = false;
                      });
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 28),

                  // Create Account Spring Button
                  FadeUpEntrance(
                    delay: const Duration(milliseconds: 320),
                    child: SpringScaleButton(
                      onTap: isLoading ? () {} : signup,
                      child: Container(
                        width: double.infinity,
                        height: 56,
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
                                  "Create Account",
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
                  
                  // Divider
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
                  
                  // Google Sign-In button
                  FadeUpEntrance(
                    delay: const Duration(milliseconds: 400),
                    child: SpringScaleButton(
                      onTap: isLoading ? () {} : googleLogin,
                      child: Container(
                        width: double.infinity,
                        height: 56,
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
                  
                  // Already have account Link
                  FadeUpEntrance(
                    delay: const Duration(milliseconds: 440),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Log In",
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
    );
  }

  Widget _buildAnimatedField({
    required GlobalKey<ShakeWidgetState> shakeKey,
    required TextEditingController controller,
    required String hintText,
    required Duration delay,
    required bool hasFocus,
    required bool hasError,
    String? errorText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    required Function(bool) onFocusChange,
    required bool isDark,
  }) {
    return FadeUpEntrance(
      delay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShakeWidget(
            key: shakeKey,
            child: Focus(
              onFocusChange: onFocusChange,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    if (hasFocus && !hasError)
                      BoxShadow(
                        color: (isDark ? AppColors.accentNeon : AppColors.lightGradient[0]).withOpacity(0.25),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    suffixIcon: suffixIcon,
                    filled: true,
                    fillColor: isDark ? AppColors.darkCardBg : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: hasError
                            ? AppColors.errorRed
                            : (isDark ? Colors.white.withOpacity(0.07) : AppColors.lightBorder),
                        width: hasError ? 1.5 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: hasError
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
          if (hasError && errorText != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                errorText,
                style: const TextStyle(
                  color: AppColors.errorRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}