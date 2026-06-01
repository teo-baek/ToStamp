import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/glass_card.dart';

/// 스탬프 카드 위젯 — 종이 쿠폰 느낌의 도장판
class StampCardWidget extends StatelessWidget {
  final String storeName;
  final int currentStamps;
  final int stampGoal;
  final String rewardDescription;
  final String? couponImageUrl;
  final bool isCompleted;

  const StampCardWidget({
    super.key,
    required this.storeName,
    required this.currentStamps,
    required this.stampGoal,
    required this.rewardDescription,
    this.couponImageUrl,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = stampGoal - currentStamps;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: couponImageUrl != null
            ? DecorationImage(
                image: NetworkImage(couponImageUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.3),
                  BlendMode.lighten,
                ),
              )
            : null,
      ),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 매장명 + 진행률 배지
            Row(
              children: [
                // 매장 아이콘
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.stampGoldLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '☕',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    storeName,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.darkBrown,
                    ),
                  ),
                ),
                // 진행률 배지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.softOrangeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCompleted ? '완성! 🎉' : '$remaining개 남음',
                    style: AppTypography.labelMedium.copyWith(
                      color: isCompleted
                          ? AppColors.success
                          : AppColors.softOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 도장 그리드
            _buildStampGrid(),

            const SizedBox(height: 12),

            // 리워드 설명
            Row(
              children: [
                Text(
                  '$currentStamps / $stampGoal',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warmGray,
                  ),
                ),
                const Text(' · '),
                Expanded(
                  child: Text(
                    rewardDescription,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warmBrown,
                    ),
                  ),
                ),
                if (isCompleted)
                  TextButton(
                    onPressed: () {
                      // TODO: Navigate to coupon use screen
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.stampGold,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: const Text('사용하기'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStampGrid() {
    // 도장 그리드: 5열 기준
    const columns = 5;
    final rows = (stampGoal / columns).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(columns, (col) {
              final index = row * columns + col;
              if (index >= stampGoal) return const SizedBox(width: 40);

              final isStamped = index < currentStamps;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isStamped
                        ? AppColors.stampGold
                        : AppColors.stampEmpty.withOpacity(0.4),
                    border: isStamped
                        ? null
                        : Border.all(
                            color: AppColors.stampEmpty,
                            width: 1.5,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                    boxShadow: isStamped
                        ? [
                            BoxShadow(
                              color: AppColors.stampGold.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isStamped
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
