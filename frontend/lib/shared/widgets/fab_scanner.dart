import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 고속 스캐너 진입용 FAB (Floating Action Button)
/// 하단 중앙에 시선을 끄는 짙은 브라운 컬러
class FabScanner extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;

  const FabScanner({
    super.key,
    required this.onPressed,
    this.icon = Icons.qr_code_scanner_rounded,
    this.tooltip = 'QR 스캔',
  });

  @override
  State<FabScanner> createState() => _FabScannerState();
}

class _FabScannerState extends State<FabScanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.fabDark,
              boxShadow: [
                BoxShadow(
                  color: AppColors.fabDark.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.stampGold.withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                customBorder: const CircleBorder(),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
