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
      // Fiziksel cihaz veya emülatör fark etmeksizin aynı Wi-Fi'daki Mac'e bağlanması için
      return 'http://192.168.1.95:8000';
    }
    // iOS Simulator için: http://localhost:8000
    // Fiziksel iPhone cihazı için Mac'in yerel IP'sini girdim.
    return 'http://192.168.1.95:8000';
  }

  static Dio? _dio;
  static SharedPreferences? _prefs;

  /// main() içinde SharedPreferences önceden başlatılarak buraya iletilir.
  static void initPrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }

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
            // Her istekte SharedPreferences'tan token'ı taze oku
            final prefs = _prefs ?? await SharedPreferences.getInstance();
            _prefs = prefs; // önbelleği güncelle
            final token = prefs.getString(_tokenKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
          onError: (DioException error, handler) async {
            // 401 gelirse → token'lı bile olsa RETRY yap
            // Sunucu restart sonrası race condition'dan korur
            if (error.response?.statusCode == 401 &&
                error.requestOptions.extra['_retried'] != true) {
              // Token hâlâ geçerli mi diye bir kez daha dene
              final prefs = _prefs ?? await SharedPreferences.getInstance();
              final token = prefs.getString(_tokenKey);
              if (token != null && token.isNotEmpty) {
                // Token varsa, isteği token ekleyerek tekrar gönder
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $token';
                opts.extra['_retried'] = true;
                try {
                  final response = await _dio!.fetch(opts);
                  return handler.resolve(response);
                } catch (_) {
                  // Retry de 401 verdiyse token gerçekten geçersiz → sil
                  // B15: Kullanıcı login'e yönlendirilmeli — hata
                  //       mesajı extractError için 401 olarak kalır
                  await prefs.remove(_tokenKey);
                  _prefs = prefs;
                }
              }
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

  // ── Hata mesajı çıkar ───────────────────────────────────────────────────
  static String extractError(DioException e) {
    // Ağ bağlantısı hatası
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Sunucuya ulaşılamadı. Uygulamanın şu anda açık olduğundan emin olun.';
    }

    if (e.response?.data is Map) {
      final data = e.response?.data as Map;
      final detail = data['detail'];
      
      if (detail is String && detail.isNotEmpty) return detail;
      
      if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;
        if (firstError is Map && firstError['msg'] is String) {
          return firstError['msg'] as String;
        }
      }
    }

    final status = e.response?.statusCode;
    if (status == 401) return 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
    if (status == 403) return 'Bu işleme yetkiniz yok.';
    if (status == 404) return 'İstenen kaynak bulunamadı.';
    if (status == 422) return 'Geçersiz istek. Lütfen bilgilerinizi kontrol edin.';
    if (status != null && status >= 500) return 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.';

    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
