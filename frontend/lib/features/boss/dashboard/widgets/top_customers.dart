import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// 단골 TOP 고객 리스트 위젯
class TopCustomersWidget extends StatelessWidget {
  final String storeId;

  const TopCustomersWidget({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    // MVP: 더미 데이터 (실제 API 연동 필요)
    final topCustomers = [
      {'rank': 1, 'name': '김민지', 'visits': 23, 'stamps': 8},
      {'rank': 2, 'name': '이준호', 'visits': 19, 'stamps': 5},
      {'rank': 3, 'name': '박서연', 'visits': 15, 'stamps': 3},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '단골 TOP 고객',
              style: AppTypography.h3.copyWith(color: AppColors.darkBrown),
            ),
            TextButton(
              onPressed: () {
                // TODO: Navigate to full CRM
              },
              child: Text(
                '전체 CRM →',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.stampGold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...topCustomers.map((customer) => _buildCustomerRow(customer)),
      ],
    );
  }

  Widget _buildCustomerRow(Map<String, dynamic> customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 순위
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.stampGoldLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${customer['rank']}',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.stampGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 이름
          Expanded(
            child: Text(
              customer['name'] as String,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.darkBrown,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 방문 횟수
          Text(
            '${customer['visits']}회 방문',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.warmGray,
            ),
          ),

          const SizedBox(width: 12),

          // 도장 수
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.softOrange,
                size: 16,
              ),
              const SizedBox(width: 2),
              Text(
                '${customer['stamps']}',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.softOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
