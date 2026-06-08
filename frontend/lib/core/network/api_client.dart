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
    int rewardPriceKrw = 5000,
    String rewardDescription = '무료 음료 1잔',
  }) async {
    final response = await _dio.post('/api/v1/stores/', data: {
      'owner_phone': ownerPhone,
      'store_name': storeName,
      'stamp_goal': stampGoal,
      'reward_price_krw': rewardPriceKrw,
      'reward_description': rewardDescription,
    });
    return response.data;
  }

  /// 대시보드 통계
  Future<Map<String, dynamic>> getDashboard(String storeId) async {
    final response = await _dio.get('/api/v1/stores/$storeId/dashboard');
    return response.data;
  }

  // ── Marketing API (세그먼트 / AI 에이전트) ───────────

  /// 단골 TOP 고객
  Future<List<dynamic>> getTopCustomers(String storeId, {int limit = 5}) async {
    final response = await _dio.get(
      '/api/v1/marketing/stores/$storeId/top-customers',
      queryParameters: {'limit': limit},
    );
    return response.data;
  }

  /// 세그먼트별 고객 수
  Future<Map<String, dynamic>> getSegmentCounts(String storeId) async {
    final response =
        await _dio.get('/api/v1/marketing/stores/$storeId/segments');
    return response.data;
  }

  /// AI 마케팅 에이전트 1회 실행 (예산 한도 내 복귀 도장 발급)
  Future<Map<String, dynamic>> runAgent(String storeId) async {
    final response =
        await _dio.post('/api/v1/marketing/stores/$storeId/agent/run');
    return response.data;
  }

  /// AI 에이전트 정책 조회
  Future<Map<String, dynamic>> getAgentPolicy(String storeId) async {
    final response =
        await _dio.get('/api/v1/marketing/stores/$storeId/agent/policy');
    return response.data;
  }

  /// AI 에이전트 정책 수정 (예산/모드)
  Future<Map<String, dynamic>> updateAgentPolicy(
    String storeId, {
    int? budgetStampsMax,
    String? automationMode,
    int? atRiskDays,
  }) async {
    final data = <String, dynamic>{};
    if (budgetStampsMax != null) data['budget_stamps_max'] = budgetStampsMax;
    if (automationMode != null) data['automation_mode'] = automationMode;
    if (atRiskDays != null) data['at_risk_days'] = atRiskDays;
    final response = await _dio.put(
      '/api/v1/marketing/stores/$storeId/agent/policy',
      data: data,
    );
    return response.data;
  }

  /// AI 에이전트 월간 성과 리포트
  Future<Map<String, dynamic>> getAgentReport(String storeId,
      {String? period}) async {
    final response = await _dio.get(
      '/api/v1/marketing/stores/$storeId/agent/report',
      queryParameters: period != null ? {'period': period} : null,
    );
    return response.data;
  }

  // ── Exchange / Money API ─────────────────────────

  /// 머니 잔액 조회
  Future<int> getMoneyBalance(String guestId) async {
    final response = await _dio.get('/api/v1/exchange/money/$guestId');
    return response.data['balance_krw'] ?? 0;
  }

  /// 머니 충전
  Future<int> topupMoney(String guestId, int amountKrw) async {
    final response = await _dio.post(
      '/api/v1/exchange/money/$guestId/topup',
      data: {'amount_krw': amountKrw},
    );
    return response.data['balance_krw'] ?? 0;
  }

  /// 열린 거래소 매물 목록
  Future<List<dynamic>> getListings({String? storeId}) async {
    final response = await _dio.get(
      '/api/v1/exchange/listings',
      queryParameters: storeId != null ? {'store_id': storeId} : null,
    );
    return response.data;
  }

  /// C2C 매물 등록 (도장 팔기)
  Future<Map<String, dynamic>> createListing({
    required String guestId,
    required String storeId,
    required int qty,
    required int askPriceKrw,
  }) async {
    final response = await _dio.post(
      '/api/v1/exchange/$guestId/listings',
      data: {'store_id': storeId, 'qty': qty, 'ask_price_krw': askPriceKrw},
    );
    return response.data;
  }

  /// C2C 매물 구매
  Future<Map<String, dynamic>> buyListing({
    required String guestId,
    required String listingId,
  }) async {
    final response = await _dio
        .post('/api/v1/exchange/$guestId/listings/$listingId/buy');
    return response.data;
  }

  /// 매장 도장 직접 구매
  Future<Map<String, dynamic>> buyStoreStamps({
    required String guestId,
    required String storeId,
    required int qty,
  }) async {
    final response = await _dio.post(
      '/api/v1/exchange/$guestId/buy-stamps',
      data: {'store_id': storeId, 'qty': qty},
    );
    return response.data;
  }

  // ── Affiliate / 상생망 API ───────────────────────

  /// 이웃 매장 웰컴 프로모 (아직 방문 안 한 연합 매장)
  Future<List<dynamic>> getCrossPromos(String guestId) async {
    final response =
        await _dio.get('/api/v1/affiliate/cross-promos/$guestId');
    return response.data;
  }

  /// 이웃 프로모 수령
  Future<Map<String, dynamic>> claimCrossPromo({
    required String promoId,
    required String guestId,
  }) async {
    final response = await _dio
        .post('/api/v1/affiliate/cross-promos/$promoId/claim/$guestId');
    return response.data;
  }

  /// 공동 적립 이벤트 진행 상황
  Future<Map<String, dynamic>> getEventProgress({
    required String eventId,
    required String guestId,
  }) async {
    final response = await _dio
        .get('/api/v1/affiliate/events/$eventId/progress/$guestId');
    return response.data;
  }

  /// 이벤트 보너스 수령
  Future<Map<String, dynamic>> claimEvent({
    required String eventId,
    required String guestId,
  }) async {
    final response =
        await _dio.post('/api/v1/affiliate/events/$eventId/claim/$guestId');
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
