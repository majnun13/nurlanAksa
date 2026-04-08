// ─────────────────────────────────────────────────────────────
//  ApiClient – FastAPI backend ile iletişim
//
//  Base URL:
//    Android Emülatör → http://10.0.2.2:8000
//    iOS Simulator    → http://localhost:8000
//    Fiziksel Cihaz   → http://<Mac IP>:8000  (ör. 192.168.1.42)
// ─────────────────────────────────────────────────────────────

import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._();

  static const String _apiVersion = '/api/v1';
  static const String _tokenKey = 'access_token';

  static String get _baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    // Gerçek iPhone cihazının Mac'teki sunucuya bağlanabilmesi için Mac'in Wi-Fi / Hotspot IP'si:
    return 'http://192.168.1.101:8000';
  }

  static Dio? _dio;

  static Dio get dio {
    _dio ??= Dio(
      BaseOptions(
        baseUrl: '$_baseUrl$_apiVersion',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // JWT varsa her isteğe ekle
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString(_tokenKey);
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
          onError: (error, handler) {
            // 401 → token sil (ileride logout yönlendirmesi eklenebilir)
            if (error.response?.statusCode == 401) {
              SharedPreferences.getInstance()
                  .then((p) => p.remove(_tokenKey));
            }
            handler.next(error);
          },
        ),
      );
    return _dio!;
  }

  // ── Token yönetimi ────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ── Hata mesajı çıkar ─────────────────────────────────────
  static String extractError(DioException e) {
    if (e.response?.data is! Map) {
       return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
    
    final data = e.response?.data as Map;
    final detail = data['detail'];
    
    if (detail is String) return detail;
    
    if (detail is List && detail.isNotEmpty) {
      final firstError = detail.first;
      if (firstError is Map && firstError['msg'] is String) {
        return firstError['msg'] as String;
      }
    }
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
