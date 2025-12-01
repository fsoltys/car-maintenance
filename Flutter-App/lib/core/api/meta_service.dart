import 'dart:convert';
import 'api_client.dart';

class MetaService {
  final ApiClient _apiClient;
  static MetaService? _instance;
  
  Map<String, dynamic>? _cachedEnums;

  MetaService._({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  factory MetaService({ApiClient? apiClient}) {
    _instance ??= MetaService._(apiClient: apiClient);
    return _instance!;
  }

  /// Get all enums from the API
  Future<Map<String, dynamic>> getEnums({bool forceRefresh = false}) async {
    if (_cachedEnums != null && !forceRefresh) {
      return _cachedEnums!;
    }

    final response = await _apiClient.get('/meta/enums', includeAuth: false);
    _cachedEnums = response as Map<String, dynamic>;
    return _cachedEnums!;
  }

  /// Get fuel types from enums
  Future<List<FuelTypeEnum>> getFuelTypes({bool forceRefresh = false}) async {
    final enums = await getEnums(forceRefresh: forceRefresh);
    final fuelTypes = enums['fuel_type'] as List<dynamic>?;
    
    if (fuelTypes == null) return [];
    
    return fuelTypes
        .map((item) => FuelTypeEnum.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Get service types from enums
  Future<List<ServiceTypeEnum>> getServiceTypes({bool forceRefresh = false}) async {
    final enums = await getEnums(forceRefresh: forceRefresh);
    final serviceTypes = enums['service_type'] as List<dynamic>?;
    
    if (serviceTypes == null) return [];
    
    return serviceTypes
        .map((item) => ServiceTypeEnum.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Get unit systems from enums
  Future<List<EnumItem>> getUnitSystems({bool forceRefresh = false}) async {
    final enums = await getEnums(forceRefresh: forceRefresh);
    final unitSystems = enums['unit_system'] as List<dynamic>?;
    
    if (unitSystems == null) return [];
    
    return unitSystems
        .map((item) => EnumItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Get role types from enums
  Future<List<EnumItem>> getRoleTypes({bool forceRefresh = false}) async {
    final enums = await getEnums(forceRefresh: forceRefresh);
    final roleTypes = enums['role_type'] as List<dynamic>?;
    
    if (roleTypes == null) return [];
    
    return roleTypes
        .map((item) => EnumItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Get driving cycles from enums
  Future<List<EnumItem>> getDrivingCycles({bool forceRefresh = false}) async {
    final enums = await getEnums(forceRefresh: forceRefresh);
    final drivingCycles = enums['driving_cycle'] as List<dynamic>?;
    
    if (drivingCycles == null) return [];
    
    return drivingCycles
        .map((item) => EnumItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Clear cached enums
  void clearCache() {
    _cachedEnums = null;
  }
}

/// Generic enum item
class EnumItem {
  final String value;
  final String label;

  EnumItem({
    required this.value,
    required this.label,
  });

  factory EnumItem.fromJson(Map<String, dynamic> json) {
    return EnumItem(
      value: json['value'] as String,
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
    };
  }
}

/// Fuel type enum item
class FuelTypeEnum extends EnumItem {
  FuelTypeEnum({
    required super.value,
    required super.label,
  });

  factory FuelTypeEnum.fromJson(Map<String, dynamic> json) {
    return FuelTypeEnum(
      value: json['value'] as String,
      label: json['label'] as String,
    );
  }
}

/// Service type enum item
class ServiceTypeEnum extends EnumItem {
  ServiceTypeEnum({
    required super.value,
    required super.label,
  });

  factory ServiceTypeEnum.fromJson(Map<String, dynamic> json) {
    return ServiceTypeEnum(
      value: json['value'] as String,
      label: json['label'] as String,
    );
  }
}
