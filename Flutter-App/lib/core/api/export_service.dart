import 'api_client.dart';

class ExportService {
  final ApiClient _apiClient;

  ExportService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Export vehicle data as CSV
  Future<String> exportData({
    required String vehicleId,
    required String dataType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _apiClient.get(
      '/vehicles/$vehicleId/export/$dataType?start_date=${_formatDate(startDate)}&end_date=${_formatDate(endDate)}',
    );

    // API returns CSV as a string
    return response['csv_data'] as String;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
