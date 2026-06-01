import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ToStamp 타이포그래피 — 따뜻하고 부드러운 느낌
class AppTypography {
  AppTypography._();

  /// 기본 텍스트 스타일 (Noto Sans KR 기반)
  static TextStyle get _baseStyle => GoogleFonts.notoSansKr();

  // ── 헤딩 ─────────────────────────────────────
  static TextStyle get h1 => _baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => _baseStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
      );

  static TextStyle get h3 => _baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  // ── 본문 ─────────────────────────────────────
  static TextStyle get bodyLarge => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyMedium => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  // ── 라벨 ─────────────────────────────────────
  static TextStyle get labelLarge => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.1,
      );

  static TextStyle get labelMedium => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );

  // ── 숫자 (대시보드용) ────────────────────────────
  static TextStyle get statNumber => _baseStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get statLabel => _baseStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.3,
        letterSpacing: 0.2,
      );
}
