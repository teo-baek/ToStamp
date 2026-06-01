import 'package:dio/dio.dart';

/// API 클라이언트 — FastAPI 백엔드 통신
class ApiClient {
  static const String _baseUrl = 'http://10.0.2.2:8080'; // Android emulator
  // static const String _baseUrl = 'http://localhost:8080'; // iOS simulator

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Request/Response logging (debug only)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  // ── Auth API ─────────────────────────────────────

  /// 게스트 즉시 등록
  Future<Map<String, dynamic>> registerGuest() async {
    final response = await _dio.post('/api/v1/auth/guest');
    return response.data;
  }

  /// QR 토큰 갱신
  Future<Map<String, dynamic>> refreshQRToken(String guestId) async {
    final response = await _dio.post(
      '/api/v1/auth/qr/refresh',
      queryParameters: {'guest_id': guestId},
    );
    return response.data;
  }

  /// 카카오 로그인 + 계정 병합
  Future<Map<String, dynamic>> kakaoLogin({
    required String kakaoAccessToken,
    required String guestId,
  }) async {
    final response = await _dio.post('/api/v1/auth/kakao', data: {
      'kakao_access_token': kakaoAccessToken,
      'guest_id': guestId,
    });
    return response.data;
  }

  // ── Stamps API ───────────────────────────────────

  /// 도장 적립 (사장님 스캔 시)
  Future<Map<String, dynamic>> earnStamp({
    required String qrToken,
    required String storeId,
  }) async {
    final response = await _dio.post('/api/v1/stamps/earn', data: {
      'qr_token': qrToken,
      'store_id': storeId,
    });
    return response.data;
  }

  /// 내 스탬프 카드 조회
  Future<List<dynamic>> getStampCards(String guestId) async {
    final response = await _dio.get('/api/v1/stamps/cards/$guestId');
    return response.data;
  }

  /// 내 쿠폰 조회
  Future<List<dynamic>> getCoupons(String guestId) async {
    final response = await _dio.get('/api/v1/stamps/coupons/$guestId');
    return response.data;
  }

  /// 쿠폰 사용
  Future<Map<String, dynamic>> useCoupon({
    required String couponId,
    required String storeId,
  }) async {
    final response = await _dio.post('/api/v1/stamps/coupons/use', data: {
      'coupon_id': couponId,
      'store_id': storeId,
    });
    return response.data;
  }

  // ── Stores API ───────────────────────────────────

  /// 매장 등록
  Future<Map<String, dynamic>> createStore({
    required String ownerPhone,
    required String storeName,
    int stampGoal = 10,
    String rewardDescription = '무료 음료 1잔',
  }) async {
    final response = await _dio.post('/api/v1/stores/', data: {
      'owner_phone': ownerPhone,
      'store_name': storeName,
      'stamp_goal': stampGoal,
      'reward_description': rewardDescription,
    });
    return response.data;
  }

  /// 대시보드 통계
  Future<Map<String, dynamic>> getDashboard(String storeId) async {
    final response = await _dio.get('/api/v1/stores/$storeId/dashboard');
    return response.data;
  }

  // ── Customers API ────────────────────────────────

  /// FCM 토큰 업데이트
  Future<void> updateFCMToken({
    required String guestId,
    required String fcmToken,
  }) async {
    await _dio.patch(
      '/api/v1/customers/$guestId/fcm-token',
      queryParameters: {'fcm_token': fcmToken},
    );
  }
}
