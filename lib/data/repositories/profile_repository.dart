// ─────────────────────────────────────────────────────────────
//  ProfileRepository – FastAPI /api/v1/profile/ endpoint'leri
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/health_profile_model.dart';

class ProfileRepository {
  final _dio = ApiClient.dio;

  // ── Sağlık profilini kaydet / güncelle ────────────────────
  Future<HealthProfileModel> saveHealthProfile({
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
    String? lifestyle,
    String? healthGoal,
    List<String>? dietaryRestrictions,
    List<String>? medicalConditions,
    String? medications,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (age != null) data['age'] = age;
      if (weightKg != null) data['weight_kg'] = weightKg;
      if (heightCm != null) data['height_cm'] = heightCm;
      if (gender != null) data['gender'] = gender;
      if (lifestyle != null) data['lifestyle'] = lifestyle;
      if (healthGoal != null) data['health_goal'] = healthGoal;
      if (dietaryRestrictions != null) data['dietary_restrictions'] = dietaryRestrictions;
      if (medicalConditions != null) data['medical_conditions'] = medicalConditions;
      if (medications != null && medications.isNotEmpty) data['medications'] = medications;

      final response = await _dio.post('/profile/health', data: data);
      return HealthProfileModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  // ── Sağlık profilini getir ────────────────────────────────
  Future<HealthProfileModel> getHealthProfile() async {
    try {
      final response = await _dio.get('/profile/health');
      return HealthProfileModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }
}

