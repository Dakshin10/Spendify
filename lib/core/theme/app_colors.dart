import 'package:flutter/material.dart';

class AppColors {
  // Common Colors
  static const Color accentNeon = Color(0xFF02FF82);
  static const Color errorRed = Color(0xFFFF3B30);
  static const Color alertOrange = Color(0xFFFF9500);
  static const Color successGreen = Color(0xFF34C759);
  
  // Light Theme Colors
  static const Color lightBg = Color(0xFFE8F1EA); // Sage/mint background
  static const Color lightCardBg = Color(0xFFFFFFFF); // White floating cards
  static const Color lightTextPrimary = Color(0xFF111111); // Black typography
  static const Color lightTextSecondary = Color(0xFF7A7A7A);
  static const Color lightBorder = Color(0xFFD2DDD5);
  static const Color lightShadow = Color(0x0A000000);
  static const List<Color> lightGradient = [
    Color(0xFF0F6038),
    Color(0xFF1B8D56),
  ];

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0A0B0A); // Matte black background
  static const Color darkCardBg = Color(0xFF151915); // Elevated dark cards
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // White typography
  static const Color darkTextSecondary = Color(0xFF888E88);
  static const Color darkBorder = Color(0xFF1F241F);
  static const Color darkShadow = Colors.transparent;
  static const List<Color> darkGradient = [
    Color(0xFF121412),
    Color(0xFF1C1F1C),
  ];

  // Navigation (Graphite navigation)
  static const Color graphiteNav = Color(0xFF121412);
}
