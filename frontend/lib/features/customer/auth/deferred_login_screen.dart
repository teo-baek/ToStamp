import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/uuid_manager.dart';

/// 지연 가입 화면 — 쿠폰 달성 시 바텀시트로 노출
/// 카카오 로그인 → 계정 병합
class DeferredLoginScreen extends StatelessWidget {
  final String storeName;
  final String reward;
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onSkip;

  const DeferredLoginScreen({
    super.key,
    required this.storeName,
    required this.reward,
    this.onLoginSuccess,
    this.onSkip,
  });

  /// 바텀시트로 표시
  static Future<bool?> show(
    BuildContext context, {
    required String storeName,
    required String reward,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeferredLoginScreen(
        storeName: storeName,
        reward: reward,
        onLoginSuccess: () => Navigator.pop(context, true),
        onSkip: () => Navigator.pop(context, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.stampEmpty,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 28),

            // 축하 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.stampGoldLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🎁', style: TextStyle(fontSize: 40)),
              ),
            ),

            const SizedBox(height: 20),

            // 타이틀
            Text(
              '쿠폰을 사용하려면\n간편 로그인이 필요해요',
              style: AppTypography.h2.copyWith(color: AppColors.darkBrown),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              '$storeName에서 모은 도장으로\n"$reward" 쿠폰을 받을 수 있어요!',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.warmGray,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // 안심 메시지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.mintBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppColors.mint,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '기존 도장은 그대로 유지됩니다',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.warmBrown,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 카카오 로그인 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => _handleKakaoLogin(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: const Color(0xFF191919),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 카카오 아이콘 (텍스트 대체)
                    const Text('💬', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      '카카오로 간편 로그인',
                      style: AppTypography.labelLarge.copyWith(
                        color: const Color(0xFF191919),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 나중에 하기
            TextButton(
              onPressed: onSkip,
              child: Text(
                '나중에 할게요',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.lightGray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleKakaoLogin(BuildContext context) async {
    // TODO: Kakao SDK 연동
    // 1. kakao_flutter_sdk로 로그인
    // 2. access_token 획득
    // 3. API: POST /auth/kakao { kakao_access_token, guest_id }
    // 4. 병합 결과 확인 → 성공 토스트
    onLoginSuccess?.call();
  }
}
