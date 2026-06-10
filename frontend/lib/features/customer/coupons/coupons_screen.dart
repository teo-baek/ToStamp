import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

/// 고객 쿠폰 목록 화면 — 상태별(available/used/expired) 구분
class CouponsScreen extends StatefulWidget {
  final String guestId;

  const CouponsScreen({super.key, required this.guestId});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = true;
  late TabController _tabController;

  static const _tabs = ['사용 가능', '사용됨', '만료'];
  static const _statusKeys = ['available', 'used', 'expired'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCoupons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    try {
      final data = await _api.getCoupons(widget.guestId);
      if (mounted) {
        setState(() {
          _coupons = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filteredCoupons(String status) {
    return _coupons
        .where((c) => (c['status'] as String?) == status)
        .toList();
  }

  Future<void> _useCoupon(Map<String, dynamic> coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '쿠폰 사용',
          style: AppTypography.h3.copyWith(color: AppColors.darkBrown),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              '사장님께 보여주고 눌러주세요',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.warmBrown),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              coupon['reward_description'] ?? '',
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.stampGold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              '취소',
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.warmGray),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stampGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('사용하기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.useCoupon(
        couponId: coupon['coupon_id'] as String,
        storeId: coupon['store_id'] as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('쿠폰이 사용되었습니다! 🎉'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        await _loadCoupons();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사용 실패: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      appBar: AppBar(
        title: Text(
          '내 쿠폰',
          style: AppTypography.h3.copyWith(color: AppColors.darkBrown),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: AppTypography.labelMedium,
          labelColor: AppColors.stampGold,
          unselectedLabelColor: AppColors.warmGray,
          indicatorColor: AppColors.stampGold,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.stampGold))
          : TabBarView(
              controller: _tabController,
              children: _statusKeys
                  .map((status) => _buildCouponList(status))
                  .toList(),
            ),
    );
  }

  Widget _buildCouponList(String status) {
    final coupons = _filteredCoupons(status);

    if (coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎟️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              '쿠폰이 없어요',
              style:
                  AppTypography.bodyLarge.copyWith(color: AppColors.warmGray),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCoupons,
      color: AppColors.stampGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coupons.length,
        itemBuilder: (context, index) =>
            _buildCouponCard(coupons[index], status),
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon, String status) {
    final isAvailable = status == 'available';
    final isUsed = status == 'used';

    String? expiresAtStr = coupon['expires_at'] as String?;
    String expiryText = '';
    if (expiresAtStr != null) {
      try {
        final dt = DateTime.parse(expiresAtStr);
        expiryText = '만료: ${DateFormat('yyyy.MM.dd').format(dt)}';
      } catch (_) {
        expiryText = '';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUsed || !isAvailable
            ? AppColors.warmWhite.withOpacity(0.6)
            : AppColors.warmWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAvailable
              ? AppColors.stampGold.withOpacity(0.3)
              : AppColors.stampEmpty,
          width: 1.5,
        ),
        boxShadow: isAvailable
            ? [
                BoxShadow(
                  color: AppColors.stampGold.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isAvailable
                    ? AppColors.stampGoldLight
                    : AppColors.softBeige,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  isAvailable ? '🎁' : (isUsed ? '✅' : '⏰'),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon['store_name'] as String? ?? '',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.warmGray,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    coupon['reward_description'] as String? ?? '',
                    style: AppTypography.labelLarge.copyWith(
                      color: isAvailable
                          ? AppColors.darkBrown
                          : AppColors.warmGray,
                    ),
                  ),
                  if (expiryText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      expiryText,
                      style: AppTypography.bodySmall.copyWith(
                        color: status == 'expired'
                            ? AppColors.error
                            : AppColors.lightGray,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 사용하기 버튼 (available만)
            if (isAvailable)
              ElevatedButton(
                onPressed: () => _useCoupon(coupon),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stampGold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: AppTypography.labelMedium,
                ),
                child: const Text('사용하기'),
              ),
          ],
        ),
      ),
    );
  }
}
