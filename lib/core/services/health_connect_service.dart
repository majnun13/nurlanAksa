// ─────────────────────────────────────────────────────────────
//  HealthConnectService – Google Fit & Apple HealthKit entegrasyonu
//  `health` paketi ile gerçek cihaz sağlık verilerine erişim sağlar.
// ─────────────────────────────────────────────────────────────

import 'dart:io' show Platform;
import 'package:health/health.dart';

class HealthConnectService {
  HealthConnectService._();
  static final instance = HealthConnectService._();

  final Health _health = Health();
  bool _isAuthorized = false;

  // Okunacak veri tipleri
  static final List<HealthDataType> _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.BODY_TEMPERATURE,
  ];

  // Erişim yetkileri
  static final List<HealthDataAccess> _permissions =
      _readTypes.map((_) => HealthDataAccess.READ).toList();

  bool get isAuthorized => _isAuthorized;

  /// Sağlık verilerine erişim izni iste
  Future<bool> requestAuthorization() async {
    try {
      // B26: _health field'ı kullan, yeni Health() instance oluşturma
      if (Platform.isAndroid) {
        await _health.configure();
      }

      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: _permissions,
      );
      _isAuthorized = granted;
      return granted;
    } catch (e) {
      _isAuthorized = false;
      return false;
    }
  }

  /// Yetki durumunu kontrol et
  Future<bool> checkAuthorization() async {
    try {
      final result = await _health.hasPermissions(
        _readTypes,
        permissions: _permissions,
      );
      _isAuthorized = result ?? false;
      return _isAuthorized;
    } catch (_) {
      return false;
    }
  }

  /// Bugünkü adım sayısını getir
  Future<int> getStepsToday() async {
    if (!_isAuthorized) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Belirli zaman aralığındaki sağlık verilerini getir
  Future<List<HealthDataPoint>> getHealthData({
    required DateTime start,
    required DateTime end,
    List<HealthDataType>? types,
  }) async {
    if (!_isAuthorized) return [];
    try {
      final data = await _health.getHealthDataFromTypes(
        types: types ?? _readTypes,
        startTime: start,
        endTime: end,
      );
      return Health().removeDuplicates(data);
    } catch (_) {
      return [];
    }
  }

  /// Bugünkü kalp atış hızı ortalaması
  Future<double?> getAverageHeartRateToday() async {
    if (!_isAuthorized) return null;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: midnight,
        endTime: now,
      );
      if (data.isEmpty) return null;
      final values = data
          .map((d) => (d.value as NumericHealthValue).numericValue.toDouble())
          .toList();
      return values.reduce((a, b) => a + b) / values.length;
    } catch (_) {
      return null;
    }
  }

  /// Bugün yakılan aktif kalori
  Future<double> getActiveCaloriesToday() async {
    if (!_isAuthorized) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );
      if (data.isEmpty) return 0;
      return data.fold<double>(
        0,
        (sum, d) => sum + (d.value as NumericHealthValue).numericValue.toDouble(),
      );
    } catch (_) {
      return 0;
    }
  }

  /// Son gece uyku süresi (saat)
  Future<double> getLastNightSleepHours() async {
    if (!_isAuthorized) return 0;
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED],
        startTime: yesterday,
        endTime: now,
      );
      if (data.isEmpty) return 0;
      // Toplam uyku süresini dakikadan saate çevir
      double totalMinutes = 0;
      for (final d in data) {
        totalMinutes += (d.value as NumericHealthValue).numericValue.toDouble();
      }
      return totalMinutes / 60.0;
    } catch (_) {
      return 0;
    }
  }

  /// Yetkileri iptal et / bağlantıyı kes
  Future<void> revokeAccess() async {
    try {
      await _health.revokePermissions();
      _isAuthorized = false;
    } catch (_) {
      _isAuthorized = false;
    }
  }
}
