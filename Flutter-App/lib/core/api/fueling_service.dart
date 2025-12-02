import 'api_client.dart';

class FuelingService {
  final ApiClient _apiClient;

  FuelingService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Get all fuelings for a vehicle
  Future<List<Fueling>> getFuelings(String vehicleId) async {
    final response = await _apiClient.get('/vehicles/$vehicleId/fuelings');
    if (response is List) {
      return response
          .map((json) => Fueling.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get fuelings within a date range
  Future<List<Fueling>> getFuelingsInRange(
    String vehicleId, {
    DateTime? fromDateTime,
    DateTime? toDateTime,
  }) async {
    final queryParams = <String, String>{};
    if (fromDateTime != null) {
      queryParams['from_datetime'] = fromDateTime.toIso8601String();
    }
    if (toDateTime != null) {
      queryParams['to_datetime'] = toDateTime.toIso8601String();
    }

    final uri = Uri.parse(
      '/vehicles/$vehicleId/fuelings',
    ).replace(queryParameters: queryParams);

    final response = await _apiClient.get(uri.toString());
    if (response is List) {
      return response
          .map((json) => Fueling.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get a single fueling by ID
  Future<Fueling> getFueling(String fuelingId) async {
    final response = await _apiClient.get('/fuelings/$fuelingId');
    return Fueling.fromJson(response as Map<String, dynamic>);
  }

  /// Create a new fueling
  Future<Fueling> createFueling(String vehicleId, FuelingCreate fueling) async {
    final response = await _apiClient.post(
      '/vehicles/$vehicleId/fuelings',
      body: fueling.toJson(),
    );
    return Fueling.fromJson(response);
  }

  /// Update a fueling
  Future<Fueling> updateFueling(String fuelingId, FuelingUpdate fueling) async {
    final response = await _apiClient.patch(
      '/fuelings/$fuelingId',
      body: fueling.toJson(),
    );
    return Fueling.fromJson(response);
  }

  /// Delete a fueling
  Future<void> deleteFueling(String fuelingId) async {
    await _apiClient.delete('/fuelings/$fuelingId');
  }
}

// Models

class Fueling {
  final String id;
  final String vehicleId;
  final String userId;
  final DateTime filledAt;
  final double pricePerUnit;
  final double volume;
  final double odometerKm;
  final bool fullTank;
  final String? drivingCycle;
  final String fuel;
  final String? note;
  final DateTime? createdAt;
  final double? fuelLevelBefore; // Tank level before fueling (0-100%)
  final double? fuelLevelAfter; // Tank level after fueling (0-100%)

  Fueling({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.filledAt,
    required this.pricePerUnit,
    required this.volume,
    required this.odometerKm,
    required this.fullTank,
    this.drivingCycle,
    required this.fuel,
    this.note,
    this.createdAt,
    this.fuelLevelBefore,
    this.fuelLevelAfter,
  });

  factory Fueling.fromJson(Map<String, dynamic> json) {
    return Fueling(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      userId: json['user_id'] as String,
      filledAt: DateTime.parse(json['filled_at'] as String),
      pricePerUnit: (json['price_per_unit'] as num).toDouble(),
      volume: (json['volume'] as num).toDouble(),
      odometerKm: (json['odometer_km'] as num).toDouble(),
      fullTank: json['full_tank'] as bool,
      drivingCycle: json['driving_cycle'] as String?,
      fuel: json['fuel'] as String,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      fuelLevelBefore: json['fuel_level_before'] != null
          ? (json['fuel_level_before'] as num).toDouble()
          : null,
      fuelLevelAfter: json['fuel_level_after'] != null
          ? (json['fuel_level_after'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'user_id': userId,
      'filled_at': filledAt.toIso8601String(),
      'price_per_unit': pricePerUnit,
      'volume': volume,
      'odometer_km': odometerKm,
      'full_tank': fullTank,
      'driving_cycle': drivingCycle,
      'fuel': fuel,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'fuel_level_before': fuelLevelBefore,
      'fuel_level_after': fuelLevelAfter,
    };
  }

  /// Calculate total price
  double get totalPrice => pricePerUnit * volume;
}

class FuelingCreate {
  final DateTime filledAt;
  final double pricePerUnit;
  final double volume;
  final double odometerKm;
  final bool fullTank;
  final String? drivingCycle;
  final String fuel;
  final String? note;
  final double? fuelLevelBefore;
  final double? fuelLevelAfter;

  FuelingCreate({
    required this.filledAt,
    required this.pricePerUnit,
    required this.volume,
    required this.odometerKm,
    required this.fullTank,
    this.drivingCycle,
    required this.fuel,
    this.note,
    this.fuelLevelBefore,
    this.fuelLevelAfter,
  });

  Map<String, dynamic> toJson() {
    return {
      'filled_at': filledAt.toIso8601String(),
      'price_per_unit': pricePerUnit,
      'volume': volume,
      'odometer_km': odometerKm,
      'full_tank': fullTank,
      'driving_cycle': drivingCycle,
      'fuel': fuel,
      'note': note,
      'fuel_level_before': fuelLevelBefore,
      'fuel_level_after': fuelLevelAfter,
    };
  }
}

class FuelingUpdate {
  final DateTime? filledAt;
  final double? pricePerUnit;
  final double? volume;
  final double? odometerKm;
  final bool? fullTank;
  final String? drivingCycle;
  final String? fuel;
  final String? note;
  final double? fuelLevelBefore;
  final double? fuelLevelAfter;

  FuelingUpdate({
    this.filledAt,
    this.pricePerUnit,
    this.volume,
    this.odometerKm,
    this.fullTank,
    this.drivingCycle,
    this.fuel,
    this.note,
    this.fuelLevelBefore,
    this.fuelLevelAfter,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (filledAt != null) map['filled_at'] = filledAt!.toIso8601String();
    if (pricePerUnit != null) map['price_per_unit'] = pricePerUnit;
    if (volume != null) map['volume'] = volume;
    if (odometerKm != null) map['odometer_km'] = odometerKm;
    if (fullTank != null) map['full_tank'] = fullTank;
    if (drivingCycle != null) map['driving_cycle'] = drivingCycle;
    if (fuel != null) map['fuel'] = fuel;
    if (note != null) map['note'] = note;
    if (fuelLevelBefore != null) map['fuel_level_before'] = fuelLevelBefore;
    if (fuelLevelAfter != null) map['fuel_level_after'] = fuelLevelAfter;
    return map;
  }
}
