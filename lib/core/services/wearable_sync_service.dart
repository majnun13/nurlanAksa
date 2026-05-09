// ─────────────────────────────────────────────────────────────
//  WearableSyncService – Apple HealthKit verilerini backend'e gönderir
//
//  ÖNEMLİ: iOS'ta Apple, hasPermissions() her zaman null döndürür
//  (gizlilik kuralı). Bu yüzden yetki kontrolü yapılmaz — doğrudan
//  veri okumaya çalışılır, veri gelmezse 0 değeri gönderilmez.
// ─────────────────────────────────────────────────────────────

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
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

  /// Platforma göre farklı veri türleri kullanılır.
  /// Android Health Connect ve iOS HealthKit farklı türleri destekler.
  static List<HealthDataType> get _readTypes {
    if (Platform.isAndroid) {
      return [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        HealthDataType.BODY_TEMPERATURE,
      ];
    }
    // iOS
    return [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.BODY_TEMPERATURE,
    ];
  }

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
      // Android'de Health Connect kurulumunu kontrol et ve yapılandır
      if (Platform.isAndroid) {
        // Health Connect uygulamasının yüklü/aktif olup olmadığını kontrol et
        final status = await _health.getHealthConnectSdkStatus();
        debugPrint('[WearableSync] Health Connect SDK status: $status');

        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint('[WearableSync] Health Connect mevcut değil. Status: $status');
          // Health Connect yüklü değilse kullanıcıyı yönlendir
          await _health.installHealthConnect();
          _isSyncing = false;
          return false;
        }

        await _health.configure();
      }

      // İzin iste — Android'de Health Connect izin ekranı açılır
      debugPrint('[WearableSync] İzin isteniyor...');
      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      debugPrint('[WearableSync] İzin sonucu: $granted');

      // İzin verilmediyse çık (kullanıcı reddetmiş)
      if (!granted) {
        debugPrint('[WearableSync] İzin reddedildi');
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
      } catch (e) {
        // B25: Kalori okuma hatası sessizce yutulmuyor
        debugPrint('[WearableSync] Kalori okuma hatası: $e');
      }

      // Ortalama kalp atış hızı
      double? avgHr;
      int? lastHr;
      try {
        final hrData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: midnight,
          endTime: now,
        );
        if (hrData.isNotEmpty) {
          // Önce Apple Watch verilerini filtrele
          final watchData = hrData.where((d) => d.sourceName.toLowerCase().contains('watch')).toList();
          final dataToUse = watchData.isNotEmpty ? watchData : hrData;

          if (dataToUse.isNotEmpty) {
            final vals = dataToUse
                .map((d) =>
                    (d.value as NumericHealthValue).numericValue.toDouble())
                .toList();
            avgHr = vals.reduce((a, b) => a + b) / vals.length;
            lastHr = (dataToUse.last.value as NumericHealthValue).numericValue.toInt();
          }
        }
      } catch (e) {
        // B25: HR okuma hatası sessizce yutulmuyor
        debugPrint('[WearableSync] Kalp hızı okuma hatası: $e');
      }

      // Dünden bu yana uyku
      double sleepHours = 0;
      try {
        final sleepTypes = Platform.isAndroid
            ? [HealthDataType.SLEEP_SESSION]
            : [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED];
        final sleepData = await _health.getHealthDataFromTypes(
          types: sleepTypes,
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
      } catch (e) {
        // B25: Uyku verisi okuma hatası
        debugPrint('[WearableSync] Uyku verisi okuma hatası: $e');
      }

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
      }

      // Resting HR — Apple Watch varsa doğrudan oku, yoksa avgHr'den tahmin et
      int? restingHr;
      try {
        final restingData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.RESTING_HEART_RATE],
          startTime: midnight,
          endTime: now,
        );
        if (restingData.isNotEmpty) {
          // Önce Apple Watch verilerini filtrele
          final watchData = restingData.where((d) => d.sourceName.toLowerCase().contains('watch')).toList();
          final dataToUse = watchData.isNotEmpty ? watchData : restingData;
          
          if (dataToUse.isNotEmpty) {
            // En son resting HR değerini al
            final lastResting = dataToUse.last;
            restingHr = (lastResting.value as NumericHealthValue)
                .numericValue
                .toInt();
          }
        }
      } catch (e) {
        // B25: Dinlenme nabzı okuma hatası
        debugPrint('[WearableSync] Dinlenme nabzı okuma hatası: $e');
      }

      // 1. Fallback: Apple Watch yoksa, son HEART_RATE ölçümünü resting HR kabul et
      if (restingHr == null && lastHr != null) {
        restingHr = lastHr;
      }

      // 2. Fallback: Eğer hiçbiri yoksa avgHr'den kaba tahmin
      if (restingHr == null && avgHr != null && avgHr > 0) {
        restingHr = (avgHr * 0.85).round();
      }

      if (restingHr != null && restingHr > 0) {
        payload['resting_hr_bpm'] = restingHr;
      }
      if (sleepHours > 0) {
        payload['sleep_hours'] = double.parse(sleepHours.toStringAsFixed(1));
        payload['sleep_score'] = _estimateSleepScore(sleepHours);
      }

      // SpO2 (Kan Oksijeni)
      double? spo2;
      try {
        final spo2Data = await _health.getHealthDataFromTypes(
          types: [HealthDataType.BLOOD_OXYGEN],
          startTime: midnight,
          endTime: now,
        );
        if (spo2Data.isNotEmpty) {
          final watchData = spo2Data.where(
            (d) => d.sourceName.toLowerCase().contains('watch')).toList();
          final dataToUse = watchData.isNotEmpty ? watchData : spo2Data;
          if (dataToUse.isNotEmpty) {
            spo2 = (dataToUse.last.value as NumericHealthValue)
                .numericValue.toDouble();
          }
        }
      } catch (e) {
        debugPrint('[WearableSync] SpO2 okuma hatası: $e');
      }

      // HRV (Kalp Atış Değişkenliği)
      double? hrvMs;
      try {
        final hrvData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
          startTime: midnight,
          endTime: now,
        );
        if (hrvData.isNotEmpty) {
          final watchData = hrvData.where(
            (d) => d.sourceName.toLowerCase().contains('watch')).toList();
          final dataToUse = watchData.isNotEmpty ? watchData : hrvData;
          if (dataToUse.isNotEmpty) {
            hrvMs = (dataToUse.last.value as NumericHealthValue)
                .numericValue.toDouble();
          }
        }
      } catch (e) {
        debugPrint('[WearableSync] HRV okuma hatası: $e');
      }

      // Vücut Sıcaklığı
      double? bodyTemp;
      try {
        final tempData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.BODY_TEMPERATURE],
          startTime: yesterday, // Sıcaklık genelde gece ölçülür
          endTime: now,
        );
        if (tempData.isNotEmpty) {
          bodyTemp = (tempData.last.value as NumericHealthValue)
              .numericValue.toDouble();
        }
      } catch (e) {
        debugPrint('[WearableSync] Vücut sıcaklığı okuma hatası: $e');
      }

      if (spo2 != null && spo2 > 0) {
        payload['spo2_pct'] = spo2.round();
      }
      if (hrvMs != null && hrvMs > 0) {
        payload['hrv_ms'] = hrvMs.round();
      }
      if (bodyTemp != null && bodyTemp > 30) {
        payload['temp_celsius'] = double.parse(bodyTemp.toStringAsFixed(1));
      }

      // Hiç veri yoksa bile bağlantıyı başarılı say
      // (izinler verildi ama henüz veri kaydedilmemiş olabilir)
      if (payload.isEmpty) {
        debugPrint('[WearableSync] İzinler verildi ama henüz sağlık verisi yok. Bağlantı başarılı sayılıyor.');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        _isSyncing = false;
        return true;
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
