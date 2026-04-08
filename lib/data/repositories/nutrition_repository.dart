// ─────────────────────────────────────────────────────────────
//  NutritionRepository – FastAPI /api/v1/nutrition/ endpoint'leri
// ─────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';

class NutritionRepository {
  final _dio = ApiClient.dio;

  /// Fotoğraftan yemek tahmini yap
  Future<Map<String, dynamic>> predictFood(File imageFile, {double gram = 0}) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'food_image.jpg',
        ),
        if (gram > 0) 'gram': gram,
      });

      final response = await _dio.post('/nutrition/predict', data: formData);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  /// Yemek ara
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    try {
      final response = await _dio.get('/nutrition/foods', queryParameters: {'q': query});
      final data = response.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['foods'] ?? []);
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  /// Besin değeri hesapla
  Future<Map<String, dynamic>> calculateNutrition(String foodName, double gram) async {
    try {
      final response = await _dio.post('/nutrition/calculate', data: {
        'food_name': foodName,
        'gram': gram,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  /// Öğün kaydet
  Future<Map<String, dynamic>> logMeal({
    required String foodName,
    required String mealType,
    required double gram,
    required double protein,
    required double carbs,
    required double fat,
    required double calories,
  }) async {
    try {
      final response = await _dio.post('/nutrition/meals', data: {
        'food_name': foodName,
        'meal_type': mealType,
        'gram': gram,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'calories': calories,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  /// Bugünkü öğünleri getir
  Future<List<Map<String, dynamic>>> getTodayMeals() async {
    try {
      final response = await _dio.get('/nutrition/meals');
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }

  /// Kişiselleştirilmiş kalori ve makro hedeflerini getir
  Future<Map<String, dynamic>> getNutritionTargets() async {
    try {
      final response = await _dio.get('/nutrition/targets');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(ApiClient.extractError(e));
    }
  }
}
