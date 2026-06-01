import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// 동적 QR 코드 위젯 — 3분마다 자동 갱신 + 카운트다운
class DynamicQRWidget extends StatefulWidget {
  final String qrToken;
  final DateTime? expiresAt;
  final VoidCallback? onRefresh;

  const DynamicQRWidget({
    super.key,
    required this.qrToken,
    this.expiresAt,
    this.onRefresh,
  });

  @override
  State<DynamicQRWidget> createState() => _DynamicQRWidgetState();
}

class _DynamicQRWidgetState extends State<DynamicQRWidget>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 180;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _startCountdown();
    _startAutoRefresh();
  }

  @override
  void didUpdateWidget(DynamicQRWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qrToken != widget.qrToken) {
      _remainingSeconds = 180;
      _fadeController.forward(from: 0.0);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 175), (_) {
      // 5초 전에 미리 갱신 요청
      widget.onRefresh?.call();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / 180.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // QR 코드
          FadeTransition(
            opacity: _fadeController,
            child: widget.qrToken.isNotEmpty
                ? QrImageView(
                    data: widget.qrToken,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.roundedRect,
                      color: AppColors.darkBrown,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.roundedRect,
                      color: AppColors.darkBrown,
                    ),
                  )
                : Container(
                    width: 200,
                    height: 200,
                    color: AppColors.softBeige,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.stampGold,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // 안내 텍스트
          Text(
            'QR로 사장님께 쿠폰 보여주기',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.warmGray,
            ),
          ),

          const SizedBox(height: 12),

          // 만료 카운트다운 (원형 프로그레스)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  backgroundColor: AppColors.stampEmpty,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _remainingSeconds < 30
                        ? AppColors.error
                        : AppColors.stampGold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                style: AppTypography.labelMedium.copyWith(
                  color: _remainingSeconds < 30
                      ? AppColors.error
                      : AppColors.warmGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
