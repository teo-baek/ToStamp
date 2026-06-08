import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import 'group_detail_screen.dart';

/// 사장님 상권 연합 관리 — 내 그룹 목록 + 생성
class AffiliateAdminScreen extends StatefulWidget {
  final String storeId;

  const AffiliateAdminScreen({super.key, required this.storeId});

  @override
  State<AffiliateAdminScreen> createState() => _AffiliateAdminScreenState();
}

class _AffiliateAdminScreenState extends State<AffiliateAdminScreen> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getMyGroups(widget.storeId);
      if (!mounted) return;
      setState(() {
        _groups = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _createGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        title: Text('새 상권 연합', style: AppTypography.h3),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '예: 강남 OO골목 상권'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('만들기')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final group = await _api.createGroup(name);
      // 내 매장을 자동으로 그룹에 추가
      await _api.addGroupMember(group['id'], widget.storeId);
      _snack('상권 연합이 생성됐어요', AppColors.success);
      await _load();
    } catch (e) {
      _snack('생성 실패: $e', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      appBar: AppBar(
        title: Text('상권 연합 관리',
            style: AppTypography.h3.copyWith(color: AppColors.darkBrown)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: AppColors.stampGold,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('새 상권 연합',
            style: AppTypography.labelLarge.copyWith(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.stampGold))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.stampGold,
              child: _groups.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Column(children: [
                          const Text('🤝', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('아직 가입한 상권 연합이 없어요',
                              style: AppTypography.bodyLarge
                                  .copyWith(color: AppColors.warmGray)),
                          const SizedBox(height: 4),
                          Text('이웃 매장과 손님을 함께 키워보세요',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.lightGray)),
                        ]),
                      ),
                    ])
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: _groups.map(_groupCard).toList(),
                    ),
            ),
    );
  }

  Widget _groupCard(Map<String, dynamic> g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: const Icon(Icons.groups_rounded, color: AppColors.stampGold),
        title: Text(g['name'] ?? '상권 연합',
            style: AppTypography.bodyLarge.copyWith(
                color: AppColors.darkBrown, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.warmGray),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(
                groupId: g['id'],
                groupName: g['name'] ?? '상권 연합',
                myStoreId: widget.storeId,
              ),
            ),
          );
          _load();
        },
      ),
    );
  }
}
