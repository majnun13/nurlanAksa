// ─────────────────────────────────────────────────────────────
//  ExerciseRepository – FastAPI /api/v1/exercise/ endpoint'leri
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import '../models/exercise_model.dart';

class ExerciseRepository {
  final Dio _dio;

  ExerciseRepository(this._dio);

  /// [difficulty] : 'normal' (varsayılan) veya 'easy' (Bugün Yorgunum)
  /// Token ApiClient interceptor tarafından otomatik eklenir.
  Future<ExerciseModel> getExerciseSummary({String difficulty = 'normal'}) async {
    try {
      final response = await _dio.get(
        '/exercise/summary',
        queryParameters: {'difficulty': difficulty},
      );
      return ExerciseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Egzersiz verileri alınamadı: ${e.response?.data ?? e.message}');
    }
  }

  /// Tamamlanan veya yarıda bırakılan antrenmanı backend'e kaydet.
  Future<void> completeSession({
    required String exerciseName,
    required int durationSeconds,
    required int caloriesBurned,
    required bool completed,
    bool markedTooHard = false,
  }) async {
    try {
      await _dio.post(
        '/exercise/complete-session',
        data: {
          'exercise_name':    exerciseName,
          'duration_seconds': durationSeconds,
          'calories_burned':  caloriesBurned,
          'completed':        completed,
          'marked_too_hard':  markedTooHard,
        },
      );
    } on DioException catch (e) {
      // Sessizce hata yakala — kayıt başarısız olsa da UI'ı bloke etme
      // ignore: avoid_print
      print('completeSession hata: ${e.response?.data ?? e.message}');
    }
  }
}
