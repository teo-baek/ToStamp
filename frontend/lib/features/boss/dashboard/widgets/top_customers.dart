import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_client.dart';

/// 단골 TOP 고객 리스트 위젯 — 실제 세그먼테이션 API 연동
class TopCustomersWidget extends StatefulWidget {
  final String storeId;

  const TopCustomersWidget({super.key, required this.storeId});

  @override
  State<TopCustomersWidget> createState() => _TopCustomersWidgetState();
}

class _TopCustomersWidgetState extends State<TopCustomersWidget> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getTopCustomers(widget.storeId, limit: 5);
      if (mounted) {
        setState(() {
          _customers = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Navigator.pushNamed(
                  context,
                  '/crm',
                  arguments: widget.storeId,
                );
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
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.stampGold),
            ),
          )
        else if (_customers.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warmWhite,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '아직 단골 데이터가 없어요',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warmGray,
                ),
              ),
            ),
          )
        else
          ..._customers.asMap().entries.map(
                (e) => _buildCustomerRow(e.key + 1, e.value),
              ),
      ],
    );
  }

  Widget _buildCustomerRow(int rank, Map<String, dynamic> customer) {
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
                '$rank',
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
              (customer['display_name'] as String?) ?? '손님',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.darkBrown,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 방문 횟수
          Text(
            '${customer['visits'] ?? 0}회 방문',
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
                '${customer['max_stamps'] ?? 0}',
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
