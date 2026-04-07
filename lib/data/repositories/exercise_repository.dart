import 'package:dio/dio.dart';
import '../models/exercise_model.dart';

class ExerciseRepository {
  final Dio _dio;

  ExerciseRepository(this._dio);

  Future<ExerciseModel> getExerciseSummary() async {
    try {
      final response = await _dio.get('/exercise/summary');
      return ExerciseModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Egzersiz verileri alınamadı: $e');
    }
  }
}
