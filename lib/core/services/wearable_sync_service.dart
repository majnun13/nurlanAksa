// ─────────────────────────────────────────────────────────────
//  WearableSyncService – Apple HealthKit verilerini backend'e gönderir
//
//  Akış:
//    1. HealthConnectService'ten bugünkü adım, nabız, uyku, kalori çek
//    2. POST /api/v1/wearable/sync → daily_wearable_logs tablosuna yaz
//    3. Son senkronizasyon zamanını SharedPreferences'a kaydet
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'health_connect_service.dart';
import '../network/api_client.dart';

class WearableSyncService {
  WearableSyncService._();
  static final instance = WearableSyncService._();

  static const String _lastSyncKey = 'last_wearable_sync';

  final HealthConnectService _health = HealthConnectService.instance;
  bool _isSyncing = false;

  /// Son senkronizasyon zamanını döner (human-readable)
  static Future<String> getLastSyncLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final isoStr = prefs.getString(_lastSyncKey);
    if (isoStr == null) return 'Henüz senkronize edilmedi';

    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return 'Bilinmiyor';

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return 'Son sync: ${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return 'Son sync: ${diff.inHours} sa önce';
    return 'Son sync: ${diff.inDays} gün önce';
  }

  /// Verileri Apple Health'ten okur ve backend'e gönderir.
  /// Birden fazla çağrıya karşı korumalıdır (debounce).
  Future<bool> syncNow() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      // 1. Yetki var mı kontrol et
      final authorized = await _health.checkAuthorization();
      if (!authorized) {
        // Yetki yoksa sessizce çık (zorla istemiyoruz)
        _isSyncing = false;
        return false;
      }

      // 2. Gerçek verileri oku
      final steps = await _health.getStepsToday();
      final avgHr = await _health.getAverageHeartRateToday();
      final calories = await _health.getActiveCaloriesToday();
      final sleepHours = await _health.getLastNightSleepHours();

      // 3. Payload hazırla
      final payload = {
        'step_count': steps,
        'avg_hr_bpm': avgHr?.round(),
        'resting_hr_bpm': avgHr != null ? (avgHr * 0.85).round() : null,
        'calories_burned': calories.round(),
        'sleep_hours': double.parse(sleepHours.toStringAsFixed(1)),
        // Adımlardan aktif dakika tahmini (her 100 adım ≈ 1 dk)
        'active_minutes': (steps / 100).round().clamp(0, 120),
        // Uyku kalitesi tahmini (7-9 saat = iyi)
        'sleep_score': _estimateSleepScore(sleepHours),
        // SpO2 ve HRV default (Apple Watch olmadan gelmiyor)
        'spo2_pct': 98.0,
        'hrv_ms': 45.0,
      };

      // 4. Backend'e gönder
      final dio = ApiClient.dio;
      await dio.post('/wearable/sync', data: payload);

      // 5. Son sync zamanını kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      _isSyncing = false;
      return true;
    } on DioException catch (_) {
      // Bağlantı hatası – sessizce başarısız ol, uygulama çökmemeli
      _isSyncing = false;
      return false;
    } catch (_) {
      _isSyncing = false;
      return false;
    }
  }

  /// Uyku saatinden 0–100 arası bir kalite skoru tahmin eder
  int _estimateSleepScore(double hours) {
    if (hours >= 7 && hours <= 9) return 85;
    if (hours >= 6 && hours < 7) return 65;
    if (hours >= 5 && hours < 6) return 45;
    if (hours > 9) return 70;
    return 30; // 5 saatten az
  }
}
