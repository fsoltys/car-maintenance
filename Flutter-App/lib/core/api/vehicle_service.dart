import 'api_client.dart';

class VehicleService {
  final ApiClient _apiClient;

  VehicleService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Get all vehicles for the current user
  Future<List<Vehicle>> getVehicles() async {
    final response = await _apiClient.get('/vehicles/');
    if (response is List) {
      return response
          .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get a single vehicle by ID
  Future<Vehicle> getVehicle(String vehicleId) async {
    final response = await _apiClient.get('/vehicles/$vehicleId');
    return Vehicle.fromJson(response as Map<String, dynamic>);
  }

  /// Create a new vehicle
  Future<Vehicle> createVehicle(VehicleCreate vehicle) async {
    final response = await _apiClient.post(
      '/vehicles/',
      body: vehicle.toJson(),
    );
    return Vehicle.fromJson(response);
  }

  /// Update a vehicle
  Future<Vehicle> updateVehicle(String vehicleId, VehicleUpdate vehicle) async {
    final response = await _apiClient.patch(
      '/vehicles/$vehicleId',
      body: vehicle.toJson(),
    );
    return Vehicle.fromJson(response);
  }

  /// Delete a vehicle
  Future<void> deleteVehicle(String vehicleId) async {
    await _apiClient.delete('/vehicles/$vehicleId');
  }

  /// Add vehicle fuels configuration (POST - for new vehicles)
  Future<List<VehicleFuelConfig>> addVehicleFuels(
    String vehicleId,
    List<VehicleFuelConfig> fuels,
  ) async {
    final response =
        await _apiClient.postList(
              '/vehicles/$vehicleId/fuels',
              body: fuels.map((f) => f.toJson()).toList(),
            )
            as List;
    return response
        .map((json) => VehicleFuelConfig.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get vehicle fuels configuration
  Future<List<VehicleFuelConfig>> getVehicleFuels(String vehicleId) async {
    final response = await _apiClient.get('/vehicles/$vehicleId/fuels');
    if (response is List) {
      return response
          .map(
            (json) => VehicleFuelConfig.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  /// Replace vehicle fuels configuration (PUT - for editing)
  Future<List<VehicleFuelConfig>> replaceVehicleFuels(
    String vehicleId,
    List<VehicleFuelConfig> fuels,
  ) async {
    final response = await _apiClient.put(
      '/vehicles/$vehicleId/fuels',
      body: fuels.map((f) => f.toJson()).toList(),
    );
    if (response is List) {
      return response
          .map(
            (json) => VehicleFuelConfig.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }
}

class VehicleFuelConfig {
  final String fuel; // Use string value from API
  final bool isPrimary;

  VehicleFuelConfig({required this.fuel, required this.isPrimary});

  factory VehicleFuelConfig.fromJson(Map<String, dynamic> json) {
    return VehicleFuelConfig(
      fuel: json['fuel'] as String,
      isPrimary: json['is_primary'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'fuel': fuel, 'is_primary': isPrimary};
  }
}

class Vehicle {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? vin;
  final String? plate;
  final String? policyNumber;
  final String? model;
  final int? productionYear;
  final double? tankCapacityL;
  final double? batteryCapacityKwh;
  final double? initialOdometerKm;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final DateTime? lastInspectionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? userRole; // OWNER, EDITOR, VIEWER

  Vehicle({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.vin,
    this.plate,
    this.policyNumber,
    this.model,
    this.productionYear,
    this.tankCapacityL,
    this.batteryCapacityKwh,
    this.initialOdometerKm,
    this.purchasePrice,
    this.purchaseDate,
    this.lastInspectionDate,
    this.createdAt,
    this.updatedAt,
    this.userRole,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      description: json['description'],
      vin: json['vin'],
      plate: json['plate'],
      policyNumber: json['policy_number'],
      model: json['model'],
      productionYear: json['production_year'],
      tankCapacityL: json['tank_capacity_l']?.toDouble(),
      batteryCapacityKwh: json['battery_capacity_kwh']?.toDouble(),
      initialOdometerKm: json['initial_odometer_km']?.toDouble(),
      purchasePrice: json['purchase_price']?.toDouble(),
      purchaseDate: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'])
          : null,
      lastInspectionDate: json['last_inspection_date'] != null
          ? DateTime.parse(json['last_inspection_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      userRole: json['user_role'],
    );
  }
}

class VehicleCreate {
  final String name;
  final String? description;
  final String? vin;
  final String? plate;
  final String? policyNumber;
  final String? model;
  final int? productionYear;
  final double? tankCapacityL;
  final double? batteryCapacityKwh;
  final double? initialOdometerKm;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final DateTime? lastInspectionDate;

  VehicleCreate({
    required this.name,
    this.description,
    this.vin,
    this.plate,
    this.policyNumber,
    this.model,
    this.productionYear,
    this.tankCapacityL,
    this.batteryCapacityKwh,
    this.initialOdometerKm,
    this.purchasePrice,
    this.purchaseDate,
    this.lastInspectionDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'vin': vin,
      'plate': plate,
      'policy_number': policyNumber,
      'model': model,
      'production_year': productionYear,
      'tank_capacity_l': tankCapacityL,
      'battery_capacity_kwh': batteryCapacityKwh,
      'initial_odometer_km': initialOdometerKm,
      'purchase_price': purchasePrice,
      'purchase_date': purchaseDate?.toIso8601String().split('T')[0],
      'last_inspection_date': lastInspectionDate?.toIso8601String().split(
        'T',
      )[0],
    };
  }
}

class VehicleUpdate {
  final String? name;
  final String? description;
  final String? vin;
  final String? plate;
  final String? policyNumber;
  final String? model;
  final int? productionYear;
  final double? tankCapacityL;
  final double? batteryCapacityKwh;
  final double? initialOdometerKm;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final DateTime? lastInspectionDate;

  VehicleUpdate({
    this.name,
    this.description,
    this.vin,
    this.plate,
    this.policyNumber,
    this.model,
    this.productionYear,
    this.tankCapacityL,
    this.batteryCapacityKwh,
    this.initialOdometerKm,
    this.purchasePrice,
    this.purchaseDate,
    this.lastInspectionDate,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (vin != null) data['vin'] = vin;
    if (plate != null) data['plate'] = plate;
    if (policyNumber != null) data['policy_number'] = policyNumber;
    if (model != null) data['model'] = model;
    if (productionYear != null) data['production_year'] = productionYear;
    if (tankCapacityL != null) data['tank_capacity_l'] = tankCapacityL;
    if (batteryCapacityKwh != null)
      data['battery_capacity_kwh'] = batteryCapacityKwh;
    if (initialOdometerKm != null)
      data['initial_odometer_km'] = initialOdometerKm;
    if (purchasePrice != null) data['purchase_price'] = purchasePrice;
    if (purchaseDate != null)
      data['purchase_date'] = purchaseDate!.toIso8601String().split('T')[0];
    if (lastInspectionDate != null)
      data['last_inspection_date'] = lastInspectionDate!
          .toIso8601String()
          .split('T')[0];
    return data;
  }
}
