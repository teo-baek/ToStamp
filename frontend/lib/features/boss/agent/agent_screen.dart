import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

/// AI 마케팅 에이전트 화면 — 예산/모드 설정 + 즉시 실행 + 성과 리포트
class AgentScreen extends StatefulWidget {
  final String storeId;

  const AgentScreen({super.key, required this.storeId});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final ApiClient _api = ApiClient();
  final _budgetController = TextEditingController();

  Map<String, dynamic>? _policy;
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  bool _isRunning = false;
  String _mode = 'auto';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final policy = await _api.getAgentPolicy(widget.storeId);
      Map<String, dynamic>? report;
      try {
        report = await _api.getAgentReport(widget.storeId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _policy = policy;
        _report = report;
        _mode = policy['automation_mode'] ?? 'auto';
        _budgetController.text = '${policy['budget_stamps_max'] ?? 50}';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePolicy() async {
    try {
      final budget = int.tryParse(_budgetController.text.trim());
      final updated = await _api.updateAgentPolicy(
        widget.storeId,
        budgetStampsMax: budget,
        automationMode: _mode,
      );
      if (!mounted) return;
      setState(() => _policy = updated);
      _snack('설정이 저장되었어요 ✅', AppColors.success);
    } catch (e) {
      _snack('저장 실패: $e', AppColors.error);
    }
  }

  Future<void> _runNow() async {
    setState(() => _isRunning = true);
    try {
      final r = await _api.runAgent(widget.storeId);
      _snack(
        '복귀 도장 ${r['issued']}건 발송 (대상 ${r['targeted']}명, 잔여 예산 ${r['budget_left']})',
        AppColors.stampGold,
      );
      await _load();
    } catch (e) {
      _snack('실행 실패: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consumed = _policy?['budget_consumed'] ?? 0;
    final maxBudget = _policy?['budget_stamps_max'] ?? 50;
    final ratio = maxBudget > 0 ? (consumed / maxBudget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.softBeige,
      appBar: AppBar(
        title: Text('AI 마케팅 직원',
            style: AppTypography.h3.copyWith(color: AppColors.darkBrown)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.stampGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('바쁜 사장님 대신, 떠나려는 단골을 알아서 다시 모셔와요.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.warmGray)),
                  const SizedBox(height: 24),

                  // 예산 카드
                  _card([
                    Text('이달 마케팅 예산 (도장 수)',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.warmBrown)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: '개'),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: AppColors.stampGoldLight,
                      color: AppColors.stampGold,
                    ),
                    const SizedBox(height: 6),
                    Text('사용 $consumed / $maxBudget개',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.warmGray)),
                  ]),
                  const SizedBox(height: 16),

                  // 모드 선택
                  _card([
                    Text('자동화 모드',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.warmBrown)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _modeChip('auto', '자동 실행'),
                        _modeChip('approval', '승인 후 실행'),
                        _modeChip('off', '끔'),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _savePolicy,
                      child: const Text('설정 저장'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isRunning ? null : _runNow,
                      icon: _isRunning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome),
                      label: Text('지금 한 번 실행',
                          style: AppTypography.labelLarge
                              .copyWith(color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text('이달 성과',
                      style: AppTypography.h3
                          .copyWith(color: AppColors.darkBrown)),
                  const SizedBox(height: 12),
                  _reportCard(),
                ],
              ),
            ),
    );
  }

  Widget _reportCard() {
    final r = _report;
    if (r == null) {
      return _card([
        Text('아직 성과 데이터가 없어요. 에이전트를 실행하면 쌓여요.',
            style:
                AppTypography.bodySmall.copyWith(color: AppColors.warmGray)),
      ]);
    }
    final lift = ((r['incremental_lift'] ?? 0) * 100).toStringAsFixed(0);
    final rev = r['est_incremental_revenue_krw'] ?? 0;
    return _card([
      _reportRow('처치군 재방문율',
          '${((r['treated_return_rate'] ?? 0) * 100).toStringAsFixed(0)}% (${r['treated']}명)'),
      _reportRow('대조군 재방문율',
          '${((r['holdout_return_rate'] ?? 0) * 100).toStringAsFixed(0)}% (${r['holdout']}명)'),
      const Divider(height: 20),
      _reportRow('증분 효과 (Lift)', '+$lift%p', highlight: true),
      _reportRow('추정 증분 매출', '₩$rev', highlight: true),
      const SizedBox(height: 8),
      Text('대조군(무처치 10%)과 비교한 순수 에이전트 효과예요.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.warmGray)),
    ]);
  }

  Widget _reportRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.warmGray)),
          Text(value,
              style: AppTypography.bodyLarge.copyWith(
                color: highlight ? AppColors.stampGold : AppColors.darkBrown,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }

  Widget _modeChip(String value, String label) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _mode = value),
      selectedColor: AppColors.stampGold,
      labelStyle: AppTypography.labelMedium.copyWith(
        color: selected ? Colors.white : AppColors.warmBrown,
      ),
      backgroundColor: AppColors.warmWhite,
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
