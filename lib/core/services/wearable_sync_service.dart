// ─────────────────────────────────────────────────────────────
//  WearableSyncService – Apple HealthKit verilerini backend'e gönderir
//
//  ÖNEMLİ: iOS'ta Apple, hasPermissions() her zaman null döndürür
//  (gizlilik kuralı). Bu yüzden yetki kontrolü yapılmaz — doğrudan
//  veri okumaya çalışılır, veri gelmezse 0 değeri gönderilmez.
// ─────────────────────────────────────────────────────────────

import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

class WearableSyncService {
  WearableSyncService._();
  static final instance = WearableSyncService._();

  static const String _lastSyncKey = 'last_wearable_sync';

  final Health _health = Health();
  bool _isSyncing = false;

  static final List<HealthDataType> _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
  ];

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

  /// Apple HealthKit'ten veri okumaya çalışır.
  /// iOS'ta izin önce istenir (requestAuthorization), ardından veri çekilir.
  Future<bool> syncNow() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      // iOS'ta configure gerekmez; Android'de Health Connect için gerekir
      if (Platform.isAndroid) {
        await _health.configure();
      }

      // İzin iste (zaten verilmişse sessizce geçer, yeni bir popup açmaz)
      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );

      // İzin verilmediyse çık (kullanıcı reddetmiş)
      if (!granted) {
        _isSyncing = false;
        return false;
      }

      // ── Veri okuma ─────────────────────────────────────────
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final yesterday = midnight.subtract(const Duration(hours: 24));

      // Bugünkü adım sayısı
      final steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;

      // Aktif kalori (kcal)
      double calories = 0;
      try {
        final calData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: midnight,
          endTime: now,
        );
        calories = calData.fold<double>(
          0,
          (sum, d) =>
              sum +
              (d.value as NumericHealthValue).numericValue.toDouble(),
        );
      } catch (_) {}

      // Ortalama kalp atış hızı
      double? avgHr;
      try {
        final hrData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: midnight,
          endTime: now,
        );
        if (hrData.isNotEmpty) {
          final vals = hrData
              .map((d) =>
                  (d.value as NumericHealthValue).numericValue.toDouble())
              .toList();
          avgHr = vals.reduce((a, b) => a + b) / vals.length;
        }
      } catch (_) {}

      // Dünden bu yana uyku
      double sleepHours = 0;
      try {
        final sleepData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED],
          startTime: yesterday,
          endTime: now,
        );
        if (sleepData.isNotEmpty) {
          double totalMinutes = 0;
          for (final d in sleepData) {
            totalMinutes +=
                (d.value as NumericHealthValue).numericValue.toDouble();
          }
          sleepHours = totalMinutes / 60.0;
        }
      } catch (_) {}

      // ── Payload oluştur ──────────────────────────────────────
      // Sıfır gelen alanları null bırak ki backend mevcut değeri silmesin
      final Map<String, dynamic> payload = {};

      if (steps > 0) {
        payload['step_count'] = steps;
        payload['active_minutes'] = (steps / 100).round().clamp(0, 120);
      }
      if (calories > 0) {
        payload['calories_burned'] = calories.round();
      }
      if (avgHr != null && avgHr > 0) {
        payload['avg_hr_bpm'] = avgHr.round();
        payload['resting_hr_bpm'] = (avgHr * 0.85).round();
      }
      if (sleepHours > 0) {
        payload['sleep_hours'] = double.parse(sleepHours.toStringAsFixed(1));
        payload['sleep_score'] = _estimateSleepScore(sleepHours);
      }

      // Hiç veri yoksa (Apple Watch yok, HK verisi boş) gönderme
      if (payload.isEmpty) {
        _isSyncing = false;
        return false;
      }

      // ── Backend'e gönder ─────────────────────────────────────
      final dio = ApiClient.dio;
      await dio.post('/wearable/sync', data: payload);

      // ── Son sync zamanını kaydet ─────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      _isSyncing = false;
      return true;
    } on DioException catch (_) {
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
    return 30;
  }
}
