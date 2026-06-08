import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

/// 상권 연합 상세 — 멤버 관리 + 이웃 프로모/공동 이벤트 생성
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String myStoreId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.myStoreId,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = data.cast<Map<String, dynamic>>();
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

  Future<void> _addMember() async {
    List<dynamic> stores;
    try {
      stores = await _api.listStores();
    } catch (e) {
      _snack('매장 목록 조회 실패: $e', AppColors.error);
      return;
    }
    final memberIds = _members.map((m) => m['id'].toString()).toSet();
    final candidates = stores
        .cast<Map<String, dynamic>>()
        .where((s) => !memberIds.contains(s['id'].toString()))
        .toList();
    if (candidates.isEmpty) {
      _snack('추가할 수 있는 매장이 없어요', AppColors.warmGray);
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text('매장 추가', style: AppTypography.h3),
          const SizedBox(height: 8),
          ...candidates.map((s) => ListTile(
                leading: const Icon(Icons.store_outlined,
                    color: AppColors.stampGold),
                title: Text(s['store_name'] ?? ''),
                onTap: () => Navigator.pop(context, s),
              )),
        ],
      ),
    );
    if (picked == null) return;
    try {
      await _api.addGroupMember(widget.groupId, picked['id']);
      _snack('${picked['store_name']} 추가됨', AppColors.success);
      await _load();
    } catch (e) {
      _snack('추가 실패: $e', AppColors.error);
    }
  }

  Future<void> _createPromo() async {
    final titleCtrl = TextEditingController(text: '첫 방문 환영 도장');
    int bonus = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          backgroundColor: AppColors.warmWhite,
          title: Text('이웃 쿠폰 프로모', style: AppTypography.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '프로모 문구'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('지급 도장', style: AppTypography.labelLarge),
                  const Spacer(),
                  IconButton(
                      onPressed: bonus > 1
                          ? () => setSt(() => bonus--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('$bonus개', style: AppTypography.h3),
                  IconButton(
                      onPressed: bonus < 5
                          ? () => setSt(() => bonus++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('등록')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _api.createCrossPromo(
        groupId: widget.groupId,
        storeId: widget.myStoreId,
        title: titleCtrl.text.trim(),
        bonusStamps: bonus,
      );
      _snack('이웃 프로모가 등록됐어요 (내 매장 신규 손님 유치)', AppColors.success);
    } catch (e) {
      _snack('등록 실패: $e', AppColors.error);
    }
  }

  Future<void> _createEvent() async {
    final titleCtrl = TextEditingController(text: '우리 상권 투어');
    int required = 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          backgroundColor: AppColors.warmWhite,
          title: Text('공동 적립 이벤트', style: AppTypography.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '이벤트 이름'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text('방문 매장 수',
                        style: AppTypography.labelLarge),
                  ),
                  IconButton(
                      onPressed: required > 2
                          ? () => setSt(() => required--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('$required곳', style: AppTypography.h3),
                  IconButton(
                      onPressed: required < (_members.length)
                          ? () => setSt(() => required++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
              const SizedBox(height: 8),
              Text('완성 시 내 매장 보상 쿠폰 지급 · 30일간',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.warmGray)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('시작')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final now = DateTime.now().toUtc();
    try {
      await _api.createCoStampEvent(
        groupId: widget.groupId,
        title: titleCtrl.text.trim(),
        requiredVisits: required,
        rewardStoreId: widget.myStoreId,
        startAtIso: now.toIso8601String(),
        endAtIso: now.add(const Duration(days: 30)).toIso8601String(),
      );
      _snack('공동 이벤트가 시작됐어요', AppColors.success);
    } catch (e) {
      _snack('시작 실패: $e', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      appBar: AppBar(
        title: Text(widget.groupName,
            style: AppTypography.h3.copyWith(color: AppColors.darkBrown)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.stampGold))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 액션
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                          Icons.card_giftcard, '이웃 프로모', _createPromo),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionButton(
                          Icons.flag_circle, '공동 이벤트', _createEvent),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('멤버 매장 (${_members.length})',
                        style: AppTypography.h3
                            .copyWith(color: AppColors.darkBrown)),
                    TextButton.icon(
                      onPressed: _addMember,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('매장 추가'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._members.map((m) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.warmWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.store_rounded,
                              color: AppColors.stampGold, size: 20),
                          const SizedBox(width: 12),
                          Text(m['store_name'] ?? '',
                              style: AppTypography.bodyLarge
                                  .copyWith(color: AppColors.darkBrown)),
                          if (m['id'].toString() == widget.myStoreId) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.stampGoldLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('내 매장',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.stampGold)),
                            ),
                          ],
                        ],
                      ),
                    )),
              ],
            ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.stampGold, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.darkBrown)),
          ],
        ),
      ),
    );
  }
}
