import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/fab_scanner.dart';
import 'widgets/stat_card.dart';
import 'widgets/top_customers.dart';

/// 사장님 대시보드 — 4개 지표 + FAB 스캐너
class DashboardScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const DashboardScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiClient _api = ApiClient();

  int _todayStamps = 0;
  int _newCustomers = 0;
  int _returningCustomers = 0;
  int _nearRewardCustomers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await _api.getDashboard(widget.storeId);
      setState(() {
        _todayStamps = data['today_stamps'] ?? 0;
        _newCustomers = data['new_customers'] ?? 0;
        _returningCustomers = data['returning_customers'] ?? 0;
        _nearRewardCustomers = data['near_reward_customers'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openScanner() {
    Navigator.pushNamed(context, '/scanner', arguments: widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          color: AppColors.stampGold,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.storeName,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.warmGray,
                            ),
                          ),
                          Text(
                            '사장님 대시보드',
                            style: AppTypography.h1.copyWith(
                              color: AppColors.darkBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 프로필
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.stampGold,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          '사',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4개 지표 카드 (2×2 그리드)
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: AppColors.stampGold,
                      ),
                    ),
                  )
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      StatCard(
                        label: '오늘 적립',
                        value: _todayStamps,
                        icon: Icons.approval,
                        color: AppColors.softOrange,
                        backgroundColor: AppColors.softOrangeBg,
                      ),
                      StatCard(
                        label: '신규 유입',
                        value: _newCustomers,
                        icon: Icons.person_add_rounded,
                        color: AppColors.mint,
                        backgroundColor: AppColors.mintBg,
                      ),
                      StatCard(
                        label: '단골 재방문',
                        value: _returningCustomers,
                        icon: Icons.favorite_rounded,
                        color: AppColors.lavender,
                        backgroundColor: AppColors.lavenderBg,
                      ),
                      StatCard(
                        label: '혜택 임박',
                        value: _nearRewardCustomers,
                        icon: Icons.card_giftcard_rounded,
                        color: AppColors.babyBlue,
                        backgroundColor: AppColors.babyBlueBg,
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // AI 마케팅 직원 진입 배너
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/agent',
                    arguments: widget.storeId,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.stampGold,
                          AppColors.stampGold.withOpacity(0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI 마케팅 직원',
                                style: AppTypography.labelLarge
                                    .copyWith(color: Colors.white),
                              ),
                              Text(
                                '떠나려는 단골을 알아서 다시 모셔와요',
                                style: AppTypography.bodySmall
                                    .copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 상권 연합 관리 진입
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/affiliate-admin',
                    arguments: widget.storeId,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warmWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.stampGoldLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.groups_rounded,
                            color: AppColors.stampGold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('상권 연합 관리',
                                  style: AppTypography.labelLarge.copyWith(
                                      color: AppColors.darkBrown)),
                              Text('이웃 매장과 공동 이벤트·교차 프로모',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.warmGray)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.warmGray),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 단골 TOP 고객 섹션
                TopCustomersWidget(storeId: widget.storeId),

                const SizedBox(height: 80), // FAB 공간
              ],
            ),
          ),
        ),
      ),

      // 하단 중앙 FAB — QR 스캐너
      floatingActionButton: FabScanner(onPressed: _openScanner),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
