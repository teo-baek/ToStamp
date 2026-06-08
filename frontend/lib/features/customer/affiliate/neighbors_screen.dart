import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

/// 우리 동네 이웃 매장 — 같은 상권 연합의 웰컴 프로모를 받아 교차 방문 유도
class NeighborsScreen extends StatefulWidget {
  final String guestId;

  const NeighborsScreen({super.key, required this.guestId});

  @override
  State<NeighborsScreen> createState() => _NeighborsScreenState();
}

class _NeighborsScreenState extends State<NeighborsScreen> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _promos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getCrossPromos(widget.guestId);
      if (!mounted) return;
      setState(() {
        _promos = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _claim(Map<String, dynamic> promo) async {
    try {
      final r = await _api.claimCrossPromo(
        promoId: promo['promo_id'],
        guestId: widget.guestId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${r['store_name']} 환영 도장 ${r['bonus_stamps']}개 받았어요! 🎁'),
          backgroundColor: AppColors.stampGold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수령 실패: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      appBar: AppBar(
        title: Text('우리 동네 이웃 매장',
            style: AppTypography.h3.copyWith(color: AppColors.darkBrown)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.stampGold))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.stampGold,
              child: _promos.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              const Text('🏘️', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text('받을 수 있는 이웃 혜택이 없어요',
                                  style: AppTypography.bodyLarge.copyWith(
                                      color: AppColors.warmGray)),
                              const SizedBox(height: 4),
                              Text('우리 상권에 더 많은 매장이 모이면 채워져요',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.lightGray)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text('같은 상권의 이웃 매장이 첫 방문 도장을 선물해요.',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.warmGray)),
                        const SizedBox(height: 16),
                        ..._promos.map(_promoCard),
                      ],
                    ),
            ),
    );
  }

  Widget _promoCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.stampGoldLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
                child: Text('🏪', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['store_name'] ?? '이웃 매장',
                    style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.darkBrown,
                        fontWeight: FontWeight.w600)),
                Text(
                    '${p['title']} · 도장 ${p['bonus_stamps']}개 (목표 ${p['stamp_goal']})',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.warmGray)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _claim(p),
            child: const Text('받기'),
          ),
        ],
      ),
    );
  }
}
