import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        cardColor: AppColors.lightCardBg,
        primaryColor: AppColors.lightGradient[0],
        dividerColor: AppColors.lightBorder,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.lightBg,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTextStyles.title.copyWith(color: AppColors.lightTextPrimary),
          iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
        ),
        textTheme: TextTheme(
          headlineLarge: AppTextStyles.heading.copyWith(color: AppColors.lightTextPrimary),
          titleLarge: AppTextStyles.cardTitle.copyWith(color: AppColors.lightTextPrimary),
          bodyMedium: AppTextStyles.body.copyWith(color: AppColors.lightTextPrimary),
          bodySmall: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.graphiteNav,
          selectedItemColor: AppColors.accentNeon,
          unselectedItemColor: Colors.grey,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        cardColor: AppColors.darkCardBg,
        primaryColor: AppColors.accentNeon,
        dividerColor: AppColors.darkBorder,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTextStyles.title.copyWith(color: AppColors.darkTextPrimary),
          iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        ),
        textTheme: TextTheme(
          headlineLarge: AppTextStyles.heading.copyWith(color: AppColors.darkTextPrimary),
          titleLarge: AppTextStyles.cardTitle.copyWith(color: AppColors.darkTextPrimary),
          bodyMedium: AppTextStyles.body.copyWith(color: AppColors.darkTextPrimary),
          bodySmall: AppTextStyles.caption.copyWith(color: AppColors.darkTextSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.graphiteNav,
          selectedItemColor: AppColors.accentNeon,
          unselectedItemColor: Colors.grey,
        ),
      );
}