import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ToStamp ThemeData — Soft & Warm UI 테마
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.softBeige,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.stampGold,
          brightness: Brightness.light,
          surface: AppColors.warmWhite,
          onSurface: AppColors.darkBrown,
          primary: AppColors.stampGold,
          onPrimary: Colors.white,
          secondary: AppColors.softOrange,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.softBeige,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.darkBrown),
          titleTextStyle: TextStyle(
            color: AppColors.darkBrown,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.warmWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.fabDark,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.fabDark,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: CircleBorder(),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.warmWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.warmWhite,
          selectedItemColor: AppColors.stampGold,
          unselectedItemColor: AppColors.warmGray,
          elevation: 0,
        ),
      );
}
