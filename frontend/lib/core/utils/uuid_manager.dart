import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Guest UUID Manager — 로컬 디바이스 기반 게스트 ID 관리
/// 앱 첫 실행 시 UUID 생성, SecureStorage에 안전 보관
class UUIDManager {
  static const _guestIdKey = 'tostamp_guest_id';
  static const _customerIdKey = 'tostamp_customer_id';
  static const _qrTokenKey = 'tostamp_qr_token';

  final FlutterSecureStorage _storage;

  UUIDManager() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 게스트 ID 가져오기 (없으면 null)
  Future<String?> getGuestId() async {
    return await _storage.read(key: _guestIdKey);
  }

  /// 게스트 ID 저장
  Future<void> setGuestId(String guestId) async {
    await _storage.write(key: _guestIdKey, value: guestId);
  }

  /// Customer ID 가져오기
  Future<String?> getCustomerId() async {
    return await _storage.read(key: _customerIdKey);
  }

  /// Customer ID 저장
  Future<void> setCustomerId(String customerId) async {
    await _storage.write(key: _customerIdKey, value: customerId);
  }

  /// QR 토큰 저장
  Future<void> setQRToken(String token) async {
    await _storage.write(key: _qrTokenKey, value: token);
  }

  /// QR 토큰 가져오기
  Future<String?> getQRToken() async {
    return await _storage.read(key: _qrTokenKey);
  }

  /// 로컬 UUID 생성 (게스트 ID 미등록 시)
  String generateLocalUUID() {
    return const Uuid().v4();
  }

  /// 게스트 등록 여부 확인
  Future<bool> isRegistered() async {
    final guestId = await getGuestId();
    return guestId != null;
  }

  /// 전체 데이터 초기화 (로그아웃 시)
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
