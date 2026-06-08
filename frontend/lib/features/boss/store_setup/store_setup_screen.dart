import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

/// 매장 설정 화면 — 최초 1회 + 이후 수정 가능
class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _rewardController = TextEditingController(text: '무료 음료 1잔');
  final _rewardPriceController = TextEditingController(text: '5000');
  int _stampGoal = 10;
  bool _isLoading = false;

  int get _rewardPrice => int.tryParse(_rewardPriceController.text.trim()) ?? 0;
  int get _faceValue => _stampGoal > 0 ? _rewardPrice ~/ _stampGoal : 0;

  final ApiClient _api = ApiClient();

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _api.createStore(
        ownerPhone: _phoneController.text,
        storeName: _storeNameController.text,
        stampGoal: _stampGoal,
        rewardPriceKrw: _rewardPrice,
        rewardDescription: _rewardController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('매장이 등록되었습니다! 🎉'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        // Navigate to dashboard with store data
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: result,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _phoneController.dispose();
    _rewardController.dispose();
    _rewardPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      appBar: AppBar(
        title: Text(
          '매장 설정',
          style: AppTypography.h3.copyWith(color: AppColors.darkBrown),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 안내 텍스트
              Text(
                '매장 정보를 입력해주세요',
                style: AppTypography.h2.copyWith(color: AppColors.darkBrown),
              ),
              const SizedBox(height: 4),
              Text(
                '고객에게 보여질 정보입니다',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.warmGray,
                ),
              ),

              const SizedBox(height: 32),

              // 매장명
              _buildLabel('매장명'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  hintText: '예: 모닝 커피 · 강남점',
                ),
                validator: (v) => (v == null || v.isEmpty) ? '매장명을 입력해주세요' : null,
              ),

              const SizedBox(height: 24),

              // 전화번호
              _buildLabel('사장님 전화번호'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '010-0000-0000',
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? '전화번호를 입력해주세요' : null,
              ),

              const SizedBox(height: 24),

              // 도장 개수
              _buildLabel('도장 목표 개수'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warmWhite,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _stampGoal > 3
                          ? () => setState(() => _stampGoal--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.warmGray,
                    ),
                    Expanded(
                      child: Text(
                        '$_stampGoal개',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.darkBrown,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: _stampGoal < 30
                          ? () => setState(() => _stampGoal++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.stampGold,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 리워드 설명
              _buildLabel('도장 완성 혜택'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rewardController,
                decoration: const InputDecoration(
                  hintText: '예: 무료 아메리카노 1잔',
                ),
              ),

              const SizedBox(height: 24),

              // 보상 금액 (원) — 도장 1개 액면가 산출의 기준
              _buildLabel('보상 금액 (원)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rewardPriceController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '예: 5000',
                  suffixText: '원',
                ),
                validator: (v) {
                  final price = int.tryParse((v ?? '').trim());
                  if (price == null || price <= 0) {
                    return '보상 금액을 입력해주세요';
                  }
                  if (price % _stampGoal != 0) {
                    return '도장 개수($_stampGoal개)로 나누어떨어지는 금액이어야 해요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Text(
                _rewardPrice > 0 && _rewardPrice % _stampGoal == 0
                    ? '도장 1개 가치 = $_faceValue원 ($_rewardPrice원 ÷ $_stampGoal개)'
                    : '도장 개수로 나누어떨어지는 금액을 입력하면 도장당 가치가 계산돼요',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warmGray,
                ),
              ),

              const SizedBox(height: 24),

              // 쿠폰 이미지 업로드
              _buildLabel('종이 쿠폰 사진 (선택)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  // TODO: Image picker
                },
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.warmWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.stampEmpty,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.warmGray,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '기존 쿠폰 사진 업로드',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.warmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveStore,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          '매장 등록하기',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTypography.labelLarge.copyWith(color: AppColors.warmBrown),
    );
  }
}
