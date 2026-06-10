import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

/// 사장님 CRM 화면 — 세그먼트별 고객 목록
class CrmScreen extends StatefulWidget {
  final String storeId;

  const CrmScreen({super.key, required this.storeId});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  // 세그먼트 정의
  static const _segments = [
    _Segment('new', '신규', AppColors.mint, AppColors.mintBg, '🌱'),
    _Segment('loyal', '단골', AppColors.stampGold, AppColors.stampGoldLight, '⭐'),
    _Segment('at_risk', '이탈위험', AppColors.softOrange, AppColors.softOrangeBg, '⚠️'),
    _Segment('near_reward', '임박', AppColors.babyBlue, AppColors.babyBlueBg, '🎯'),
    _Segment('churned', '이탈', AppColors.lightGray, AppColors.softBeige, '😴'),
  ];

  // 세그먼트별 고객 캐시
  final Map<String, List<Map<String, dynamic>>> _membersCache = {};
  final Map<String, bool> _loadingMap = {};

  // 세그먼트 카운트
  Map<String, dynamic> _counts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _segments.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCounts();
    _loadSegment(_segments[0].key);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final seg = _segments[_tabController.index].key;
    if (!_membersCache.containsKey(seg)) {
      _loadSegment(seg);
    }
  }

  Future<void> _loadCounts() async {
    try {
      final data = await _api.getSegmentCounts(widget.storeId);
      if (mounted) setState(() => _counts = data);
    } catch (_) {}
  }

  Future<void> _loadSegment(String segment) async {
    if (_loadingMap[segment] == true) return;
    setState(() => _loadingMap[segment] = true);
    try {
      final data = await _api.getSegmentMembers(widget.storeId, segment);
      if (mounted) {
        setState(() {
          _membersCache[segment] = data.cast<Map<String, dynamic>>();
          _loadingMap[segment] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMap[segment] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      appBar: AppBar(
        title: Text(
          '고객 CRM',
          style: AppTypography.h3.copyWith(color: AppColors.darkBrown),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: AppTypography.labelMedium,
          labelColor: AppColors.darkBrown,
          unselectedLabelColor: AppColors.warmGray,
          indicatorColor: AppColors.stampGold,
          tabs: _segments.map((s) {
            final count = _counts[s.key];
            final countText = count != null ? ' $count' : '';
            return Tab(text: '${s.label}$countText');
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _segments.map((s) => _buildSegmentTab(s)).toList(),
      ),
    );
  }

  Widget _buildSegmentTab(_Segment seg) {
    final isLoading = _loadingMap[seg.key] == true;
    final members = _membersCache[seg.key];

    if (isLoading || members == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.stampGold),
      );
    }

    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(seg.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              '${seg.label} 고객이 없어요',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.warmGray),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSegment(seg.key),
      color: AppColors.stampGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: members.length,
        itemBuilder: (context, index) =>
            _buildCustomerCard(members[index], seg),
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer, _Segment seg) {
    final name = customer['display_name'] as String? ?? '손님';
    final visits = customer['visits'] ?? 0;
    final maxStamps = customer['max_stamps'] ?? 0;
    final lastVisit = customer['last_visit'] as String?;
    final daysSince = customer['days_since_last'] as int?;

    String lastVisitText = '';
    if (daysSince != null) {
      if (daysSince == 0) {
        lastVisitText = '오늘 방문';
      } else {
        lastVisitText = '$daysSince일 전 방문';
      }
    } else if (lastVisit != null) {
      lastVisitText = lastVisit;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seg.color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 세그먼트 배지
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: seg.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(seg.emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),

          // 고객 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.darkBrown,
                  ),
                ),
                if (lastVisitText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    lastVisitText,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warmGray,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 방문 횟수
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$visits회',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.warmBrown,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.softOrange,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$maxStamps',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.softOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment {
  final String key;
  final String label;
  final Color color;
  final Color bgColor;
  final String emoji;

  const _Segment(this.key, this.label, this.color, this.bgColor, this.emoji);
}
