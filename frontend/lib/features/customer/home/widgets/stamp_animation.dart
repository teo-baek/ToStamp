import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// 도장 찍힘 애니메이션 오버레이
/// 스캔 성공 시 화면 위에 도장이 날아와 찍히는 효과 + 햅틱
class StampAnimationOverlay extends StatefulWidget {
  const StampAnimationOverlay({super.key});

  @override
  State<StampAnimationOverlay> createState() => StampAnimationOverlayState();
}

class StampAnimationOverlayState extends State<StampAnimationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _stampController;
  late AnimationController _rippleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rippleAnimation;

  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    // 도장 찍히는 애니메이션
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 3.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_stampController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_stampController);

    // 잉크 퍼짐 효과
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _stampController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isVisible = false);
      }
    });
  }

  /// 도장 찍힘 애니메이션 실행
  void playStampAnimation() {
    setState(() => _isVisible = true);
    _stampController.reset();
    _rippleController.reset();
    _stampController.forward();
    _rippleController.forward();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _stampController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_stampController, _rippleController]),
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // 잉크 퍼짐 원
                  Opacity(
                    opacity: (1.0 - _rippleAnimation.value) * 0.3,
                    child: Container(
                      width: 200 * _rippleAnimation.value,
                      height: 200 * _rippleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.stampGold.withOpacity(0.2),
                      ),
                    ),
                  ),

                  // 도장 아이콘
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.stampGold,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.stampGold.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
