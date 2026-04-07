// ─────────────────────────────────────────────────────────────
//  AuthRepository – FastAPI backend üzerinden auth işlemleri
//
//  Tüm HTTP çağrıları ApiClient.dio üzerinden yapılır.
//  Hata mesajları API'nin `detail` alanından alınır.
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../data/models/user_model.dart';

class AuthRepository {
  final _dio = ApiClient.dio;

  // ── KAYIT ────────────────────────────────────────────────
  /// Kullanıcı oluşturur ve doğrulama maili gönderir.
  /// Başarılıysa [UserModel] döner.
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  // ── GİRİŞ ────────────────────────────────────────────────
  /// Giriş yapar. Başarılıysa JWT token'ı kaydeder ve [UserModel] döner.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      final token = response.data['access_token'] as String;
      await ApiClient.saveToken(token);
      return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  // ── E-POSTA DOĞRULAMA ─────────────────────────────────────
  /// E-posta doğrulandığında giriş yapmış sayılır ve token kaydedilir.
  Future<void> verifyCode({
    required String userId,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify-email',
        data: {'user_id': userId, 'code': code},
      );
      final token = response.data['access_token'] as String;
      await ApiClient.saveToken(token);
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  // ── KODU TEKRAR GÖNDER ────────────────────────────────────
  Future<void> sendVerificationCode({
    required String userId,
    required String email,    // API'de gerekmiyor ama eski arayüzle uyumluluk için
    required String userName, // API'de gerekmiyor ama eski arayüzle uyumluluk için
  }) async {
    try {
      await _dio.post(
        '/auth/resend-code',
        data: {'user_id': userId},
      );
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  // ── ÇIKIŞ ────────────────────────────────────────────────
  Future<void> logout() async {
    await ApiClient.clearToken();
  }
}
