import 'dart:io';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/network/api_client.dart';
import '../../data/models/user_model.dart';

class AuthRepository {
  final _dio = ApiClient.dio;

  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
    clientId: Platform.isIOS ? dotenv.env['GOOGLE_IOS_CLIENT_ID'] : null,
  );

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
      final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
      await ApiClient.saveUserName(user.fullName);
      return user;
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
      final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
      await ApiClient.saveUserName(user.fullName);
      return user;
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  // ── GOOGLE İLE GİRİŞ ─────────────────────────────────────
  /// Google Sign-In akışını başlatır, id_token'ı backend'e gönderir.
  /// Döner: ({user: UserModel, isNew: bool})
  Future<Map<String, dynamic>> googleSignIn() async {
    try {
      // Önce mevcut oturumu temizle
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Google ile giriş iptal edildi.');
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Google token alınamadı.');
      }

      // Backend'e gönder
      final response = await _dio.post(
        '/auth/google',
        data: {'id_token': idToken},
      );

      final token = response.data['access_token'] as String;
      await ApiClient.saveToken(token);

      final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
      await ApiClient.saveUserName(user.fullName);
      final isNew = response.data['is_new'] as bool? ?? false;

      return {'user': user, 'isNew': isNew};
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
    await _googleSignIn.signOut();
    await ApiClient.clearToken();
  }

  // ── HESAP SİL ────────────────────────────────────────────
  Future<void> deleteAccount() async {
    try {
      await _dio.delete('/auth/delete-account');
      await _googleSignIn.signOut();
      await ApiClient.clearToken();
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }
}
