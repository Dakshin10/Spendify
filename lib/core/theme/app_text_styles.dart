import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static TextStyle get heading => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get subheading => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get title => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get cardTitle => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get amount => GoogleFonts.outfit(
        fontSize: 42,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get amountMedium => GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get body => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get caption => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get button => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );
}