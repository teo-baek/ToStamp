import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

/// QR 스캐너 화면 — 사장님이 고객 QR 스캔
class ScannerScreen extends StatefulWidget {
  final String storeId;

  const ScannerScreen({super.key, required this.storeId});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final ApiClient _api = ApiClient();

  bool _isProcessing = false;
  String? _lastResult;
  bool? _lastSuccess;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _api.earnStamp(
        qrToken: barcode!.rawValue!,
        storeId: widget.storeId,
      );

      HapticFeedback.heavyImpact();

      setState(() {
        _lastResult = '${result['store_name']} — '
            '도장 ${result['current_stamps']}/${result['stamp_goal']}';
        _lastSuccess = true;
      });

      // 2초 후 다시 스캔 가능
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() {
        _lastResult = '스캔 실패: QR이 만료되었거나 유효하지 않습니다';
        _lastSuccess = false;
      });
      await Future.delayed(const Duration(seconds: 1));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 카메라 뷰
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // 상단 바
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      '고객 QR 스캔',
                      style: AppTypography.h3.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _scannerController.toggleTorch(),
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // 스캔 영역 가이드
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing
                      ? AppColors.stampGold
                      : Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          // 하단 결과 표시
          if (_lastResult != null)
            Positioned(
              bottom: 100,
              left: 24,
              right: 24,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _lastSuccess == true
                      ? AppColors.success.withOpacity(0.95)
                      : AppColors.error.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastSuccess == true
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastResult!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 처리 중 인디케이터
          if (_isProcessing)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.stampGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '적립 중...',
                        style: AppTypography.labelMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
