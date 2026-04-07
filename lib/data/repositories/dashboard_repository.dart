import '../models/dashboard_model.dart';
import '../../core/network/api_client.dart';
import 'package:dio/dio.dart';

class DashboardRepository {
  final Dio _dio;

  DashboardRepository(this._dio);

  Future<DashboardModel> getDashboardSummary() async {
    try {
      final response = await _dio.get('/dashboard/summary');
      return DashboardModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Dashboard verileri alınamadı: $e');
    }
  }
}
