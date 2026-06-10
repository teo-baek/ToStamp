import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/utils/uuid_manager.dart';
import '../../../shared/widgets/glass_card.dart';
import 'widgets/dynamic_qr.dart';
import 'widgets/stamp_card.dart';
import 'widgets/stamp_animation.dart';
import '../exchange/exchange_screen.dart';
import '../affiliate/neighbors_screen.dart';

/// 고객 홈 화면 — QR + 스탬프 카드
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final ApiClient _api = ApiClient();
  final WSClient _ws = WSClient();
  final UUIDManager _uuid = UUIDManager();

  String? _guestId;
  String? _qrToken;
  DateTime? _qrExpiresAt;
  List<Map<String, dynamic>> _stampCards = [];
  bool _isLoading = true;

  // 도장 애니메이션 컨트롤
  final GlobalKey<StampAnimationOverlayState> _animationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initGuest();
  }

  Future<void> _initGuest() async {
    // 1. 로컬에 Guest ID가 있는지 확인
    var guestId = await _uuid.getGuestId();

    if (guestId == null) {
      // 2. 없으면 서버에 게스트 등록 → 0초 지연 목표
      try {
        final result = await _api.registerGuest();
        guestId = result['guest_id'];
        await _uuid.setGuestId(guestId!);
        await _uuid.setCustomerId(result['customer_id']);
        _qrToken = result['qr_token'];
        _qrExpiresAt = DateTime.parse(result['qr_expires_at']);
      } catch (e) {
        // Offline fallback: 로컬 UUID 생성
        guestId = _uuid.generateLocalUUID();
        await _uuid.setGuestId(guestId);
      }
    } else {
      // 3. 있으면 QR 토큰 갱신
      try {
        final result = await _api.refreshQRToken(guestId);
        _qrToken = result['qr_token'];
        _qrExpiresAt = DateTime.parse(result['qr_expires_at']);
      } catch (e) {
        // Use cached token or show offline state
      }
    }

    _guestId = guestId;

    // 4. WebSocket 연결
    _setupWebSocket();

    // 5. 스탬프 카드 로드
    await _loadStampCards();

    setState(() => _isLoading = false);
  }

  void _setupWebSocket() {
    if (_guestId == null) return;

    _ws.onStampEarned = (data) {
      // 도장 적립 이벤트 수신 → 애니메이션 + 햅틱
      HapticFeedback.heavyImpact();
      _animationKey.currentState?.playStampAnimation();
      _loadStampCards(); // 갱신
    };

    _ws.onCouponEarned = (data) {
      // 쿠폰 달성 → 축하 다이얼로그
      HapticFeedback.heavyImpact();
      _showCouponEarnedDialog(data);
    };

    _ws.connect(_guestId!);
  }

  Future<void> _loadStampCards() async {
    if (_guestId == null) return;
    try {
      final cards = await _api.getStampCards(_guestId!);
      setState(() {
        _stampCards = cards.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      // Handle error silently
    }
  }

  void _showCouponEarnedDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '🎉 축하해요!',
          style: AppTypography.h2.copyWith(color: AppColors.darkBrown),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data['store_name'] ?? '',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.warmBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['reward_description'] ?? '무료 혜택을 받으세요!',
              style: AppTypography.h3.copyWith(color: AppColors.stampGold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('쿠폰 확인하기'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadStampCards,
                    color: AppColors.stampGold,
                    child: CustomScrollView(
                      slivers: [
                        // 헤더
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '안녕하세요 👋',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.warmGray,
                                        ),
                                      ),
                                      Text(
                                        '내 스탬프 카드',
                                        style: AppTypography.h1.copyWith(
                                          color: AppColors.darkBrown,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 이웃 매장(상생) 진입
                                IconButton(
                                  onPressed: _guestId == null
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => NeighborsScreen(
                                                guestId: _guestId!,
                                              ),
                                            ),
                                          ),
                                  icon: const Icon(
                                    Icons.holiday_village_outlined,
                                    color: AppColors.warmBrown,
                                  ),
                                  tooltip: '우리 동네 이웃 매장',
                                ),
                                // 거래소 진입
                                IconButton(
                                  onPressed: _guestId == null
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ExchangeScreen(
                                                guestId: _guestId!,
                                              ),
                                            ),
                                          ),
                                  icon: const Icon(
                                    Icons.storefront_outlined,
                                    color: AppColors.warmBrown,
                                  ),
                                  tooltip: '도장 거래소',
                                ),
                                // 프로필 아바타
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.stampGoldLight,
                                  child: Text(
                                    '👤',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 동적 QR 코드
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: DynamicQRWidget(
                              qrToken: _qrToken ?? '',
                              expiresAt: _qrExpiresAt,
                              onRefresh: () async {
                                if (_guestId != null) {
                                  final result =
                                      await _api.refreshQRToken(_guestId!);
                                  setState(() {
                                    _qrToken = result['qr_token'];
                                    _qrExpiresAt =
                                        DateTime.parse(result['qr_expires_at']);
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        // 스탬프 카드 목록
                        if (_stampCards.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: GlassCard(
                                child: Column(
                                  children: [
                                    const Text('🏪', style: TextStyle(fontSize: 48)),
                                    const SizedBox(height: 12),
                                    Text(
                                      '아직 방문한 매장이 없어요',
                                      style: AppTypography.bodyLarge.copyWith(
                                        color: AppColors.warmGray,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'QR코드를 사장님께 보여주세요!',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.lightGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final card = _stampCards[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                child: StampCardWidget(
                                  storeName: card['store_name'] ?? '',
                                  currentStamps: card['current_stamps'] ?? 0,
                                  stampGoal: card['stamp_goal'] ?? 10,
                                  rewardDescription:
                                      card['reward_description'] ?? '',
                                  couponImageUrl: card['coupon_image_url'],
                                  isCompleted: card['is_completed'] ?? false,
                                  guestId: _guestId,
                                ),
                              );
                            },
                            childCount: _stampCards.length,
                          ),
                        ),

                        // 하단 여백
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
          ),

          // 도장 애니메이션 오버레이
          StampAnimationOverlay(key: _animationKey),
        ],
      ),
    );
  }
}
