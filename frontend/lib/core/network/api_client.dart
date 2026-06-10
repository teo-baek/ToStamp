import 'dart:typed_data';
import 'package:dio/dio.dart';

/// API 클라이언트 — FastAPI 백엔드 통신
class ApiClient {
  // 빌드 시 --dart-define=API_BASE=http://<서버주소>:8080 로 주입
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator 기본값
  );

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

  /// 세그먼트별 고객 목록
  Future<List<dynamic>> getSegmentMembers(
      String storeId, String segment) async {
    final response = await _dio.get(
      '/api/v1/marketing/stores/$storeId/segments/$segment',
    );
    return response.data;
  }

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

  /// 매장 쿠폰 이미지 업로드
  Future<String> uploadStoreImage(String storeId, Uint8List bytes,
      {String fileName = 'coupon.jpg'}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _dio.post(
      '/api/v1/stores/$storeId/image',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data['coupon_image_url'] as String;
  }

  // ── Affiliate admin (사장님) ─────────────────────

  /// 매장 목록 (멤버 선택용)
  Future<List<dynamic>> listStores({int limit = 100}) async {
    final response = await _dio
        .get('/api/v1/stores/', queryParameters: {'limit': limit});
    return response.data;
  }

  /// 내 매장이 속한 상권 연합 그룹
  Future<List<dynamic>> getMyGroups(String storeId) async {
    final response =
        await _dio.get('/api/v1/affiliate/stores/$storeId/groups');
    return response.data;
  }

  /// 상권 연합 그룹 생성
  Future<Map<String, dynamic>> createGroup(String name) async {
    final response =
        await _dio.post('/api/v1/affiliate/groups', data: {'name': name});
    return response.data;
  }

  /// 그룹에 매장 추가
  Future<void> addGroupMember(String groupId, String storeId) async {
    await _dio.post('/api/v1/affiliate/groups/$groupId/members',
        data: {'store_id': storeId});
  }

  /// 그룹 멤버 매장 목록
  Future<List<dynamic>> getGroupMembers(String groupId) async {
    final response =
        await _dio.get('/api/v1/affiliate/groups/$groupId/members');
    return response.data;
  }

  /// 이웃 쿠폰 교차 노출 프로모 생성
  Future<void> createCrossPromo({
    required String groupId,
    required String storeId,
    required String title,
    required int bonusStamps,
  }) async {
    await _dio.post('/api/v1/affiliate/groups/$groupId/cross-promos', data: {
      'store_id': storeId,
      'title': title,
      'bonus_stamps': bonusStamps,
    });
  }

  /// 공동 적립 이벤트 생성
  Future<void> createCoStampEvent({
    required String groupId,
    required String title,
    required int requiredVisits,
    required String rewardStoreId,
    required String startAtIso,
    required String endAtIso,
    String rewardDescription = '상권 투어 완성 보너스',
  }) async {
    await _dio.post('/api/v1/affiliate/groups/$groupId/events', data: {
      'title': title,
      'required_visits': requiredVisits,
      'reward_store_id': rewardStoreId,
      'start_at': startAtIso,
      'end_at': endAtIso,
      'reward_description': rewardDescription,
    });
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
