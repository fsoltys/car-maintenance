import 'api_client.dart';

class OdometerService {
  final ApiClient _apiClient;

  OdometerService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Get odometer graph data for a vehicle
  Future<List<OdometerHistoryItem>> getOdometerGraph(
    String vehicleId, {
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 1000,
  }) async {
    final queryParams = <String, String>{};
    if (fromDate != null) {
      queryParams['from_date'] = fromDate.toIso8601String();
    }
    if (toDate != null) {
      queryParams['to_date'] = toDate.toIso8601String();
    }
    queryParams['limit'] = limit.toString();

    final uri = Uri.parse(
      '/vehicles/$vehicleId/odometer-graph',
    ).replace(queryParameters: queryParams);

    final response = await _apiClient.get(uri.toString());
    if (response is List) {
      if (response.isNotEmpty) {}
      return response
          .map(
            (json) =>
                OdometerHistoryItem.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  /// Create a manual odometer entry
  Future<OdometerEntry> createOdometerEntry(
    String vehicleId,
    DateTime entryDate,
    double valueKm, {
    String? note,
  }) async {
    final response = await _apiClient.post(
      '/vehicles/$vehicleId/odometer-entries',
      body: {
        'entry_date': entryDate.toIso8601String(),
        'value_km': valueKm,
        if (note != null) 'note': note,
      },
    );
    return OdometerEntry.fromJson(response as Map<String, dynamic>);
  }

  /// Update a manual odometer entry
  Future<OdometerEntry> updateOdometerEntry(
    String entryId, {
    DateTime? entryDate,
    double? valueKm,
    String? note,
  }) async {
    final response = await _apiClient.patch(
      '/odometer-entries/$entryId',
      body: {
        if (entryDate != null) 'entry_date': entryDate.toIso8601String(),
        if (valueKm != null) 'value_km': valueKm,
        if (note != null) 'note': note,
      },
    );
    return OdometerEntry.fromJson(response as Map<String, dynamic>);
  }

  /// Delete a manual odometer entry
  Future<void> deleteOdometerEntry(String entryId) async {
    await _apiClient.delete('/odometer-entries/$entryId');
  }
}

// Models

class OdometerEntry {
  final String id;
  final String vehicleId;
  final DateTime entryDate;
  final double valueKm;
  final String? note;

  OdometerEntry({
    required this.id,
    required this.vehicleId,
    required this.entryDate,
    required this.valueKm,
    this.note,
  });

  factory OdometerEntry.fromJson(Map<String, dynamic> json) {
    return OdometerEntry(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      valueKm: (json['value_km'] as num).toDouble(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'entry_date': entryDate.toIso8601String(),
      'value_km': valueKm,
      'note': note,
    };
  }
}

class OdometerHistoryItem {
  final DateTime timestamp;
  final double odometerKm;
  final String source; // 'fueling', 'service', or 'manual'
  final String? sourceId;

  OdometerHistoryItem({
    required this.timestamp,
    required this.odometerKm,
    required this.source,
    this.sourceId,
  });

  factory OdometerHistoryItem.fromJson(Map<String, dynamic> json) {
    return OdometerHistoryItem(
      timestamp: DateTime.parse(json['event_date'] as String),
      odometerKm: (json['odometer_km'] as num).toDouble(),
      source: json['event_type'] as String,
      sourceId: json['source_id'] != null ? json['source_id'] as String : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_date': timestamp.toIso8601String(),
      'odometer_km': odometerKm,
      'event_type': source,
      'source_id': sourceId,
    };
  }
}
