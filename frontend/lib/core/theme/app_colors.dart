import 'dart:ui';

/// ToStamp 컬러 팔레트 — Soft & Warm UI
/// 레퍼런스: etc/ 디자인 목업 (소프트 베이지 + 파스텔 톤)
class AppColors {
  AppColors._();

  // ── 배경 ───────────────────────────────────────
  static const softBeige = Color(0xFFF5F0EB);
  static const warmWhite = Color(0xFFFAF8F5);
  static const cream = Color(0xFFFFF8F0);

  // ── 대시보드 파스텔 카드 ──────────────────────────
  static const softOrange = Color(0xFFE8985A);       // 오늘 적립
  static const softOrangeBg = Color(0xFFFFF0E5);
  static const mint = Color(0xFFB8D8D0);             // 신규 유입
  static const mintBg = Color(0xFFE8F5F0);
  static const lavender = Color(0xFFD4C5E2);         // 단골 재방문
  static const lavenderBg = Color(0xFFF0EBF5);
  static const babyBlue = Color(0xFFA8C8E8);         // 혜택 임박
  static const babyBlueBg = Color(0xFFE8F0F8);

  // ── 도장 & 강조 ─────────────────────────────────
  static const stampGold = Color(0xFFD4A34A);
  static const stampGoldLight = Color(0xFFF5E6C8);
  static const stampEmpty = Color(0xFFE0D8D0);

  // ── 텍스트 ──────────────────────────────────────
  static const darkBrown = Color(0xFF3D2C1E);
  static const warmBrown = Color(0xFF5C4A3A);
  static const warmGray = Color(0xFF8A7F76);
  static const lightGray = Color(0xFFBDB5AC);

  // ── 시스템 ──────────────────────────────────────
  static const success = Color(0xFF68B984);
  static const error = Color(0xFFE07A5F);
  static const warning = Color(0xFFF2CC8F);

  // ── 글래스모피즘 ────────────────────────────────
  static const glassWhite = Color(0xCCFFFFFF);       // 80% opacity white
  static const glassBorder = Color(0x33FFFFFF);       // 20% opacity white

  // ── FAB (스캐너) ────────────────────────────────
  static const fabDark = Color(0xFF2C1F14);
  static const fabDarkHover = Color(0xFF3D2C1E);
}
