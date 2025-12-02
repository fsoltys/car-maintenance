import 'dart:convert';
import 'api_client.dart';
import 'meta_service.dart';

class ServiceItem {
  final String id;
  final String serviceId;
  final String? partName;
  final String? partNumber;
  final double? quantity;
  final double? unitPrice;

  ServiceItem({
    required this.id,
    required this.serviceId,
    this.partName,
    this.partNumber,
    this.quantity,
    this.unitPrice,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['id'],
      serviceId: json['service_id'],
      partName: json['part_name'],
      partNumber: json['part_number'],
      quantity: json['quantity']?.toDouble(),
      unitPrice: json['unit_price']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'part_name': partName,
      'part_number': partNumber,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  double get totalPrice => (quantity ?? 0) * (unitPrice ?? 0);
}

class Service {
  final String id;
  final String vehicleId;
  final String userId;
  final DateTime serviceDate;
  final String serviceType;
  final double? odometerKm;
  final double? totalCost;
  final String? reference;
  final String? note;
  final DateTime? createdAt;

  Service({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.serviceDate,
    required this.serviceType,
    this.odometerKm,
    this.totalCost,
    this.reference,
    this.note,
    this.createdAt,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'],
      vehicleId: json['vehicle_id'],
      userId: json['user_id'],
      serviceDate: DateTime.parse(json['service_date']),
      serviceType: json['service_type'] as String,
      odometerKm: json['odometer_km']?.toDouble(),
      totalCost: json['total_cost']?.toDouble(),
      reference: json['reference'],
      note: json['note'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class ServiceService {
  final ApiClient _apiClient;

  ServiceService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<Service>> getVehicleServices(String vehicleId) async {
    final response = await _apiClient.get(
      '/services/vehicles/$vehicleId/services',
    );
    if (response is List) {
      return response.map((json) => Service.fromJson(json)).toList();
    }
    return [];
  }

  Future<Service> getService(String serviceId) async {
    final response = await _apiClient.get('/services/services/$serviceId');
    return Service.fromJson(response);
  }

  Future<Service> createService({
    required String vehicleId,
    required DateTime serviceDate,
    required String serviceType,
    double? odometerKm,
    double? totalCost,
    String? reference,
    String? note,
  }) async {
    final response = await _apiClient.post(
      '/services/vehicles/$vehicleId/services',
      body: {
        'service_date': serviceDate.toIso8601String().split('T')[0],
        'service_type': serviceType,
        'odometer_km': odometerKm,
        'total_cost': totalCost,
        'reference': reference,
        'note': note,
      },
    );
    return Service.fromJson(response);
  }

  Future<Service> updateService(
    String serviceId, {
    DateTime? serviceDate,
    String? serviceType,
    double? odometerKm,
    double? totalCost,
    String? reference,
    String? note,
  }) async {
    final Map<String, dynamic> body = {};
    if (serviceDate != null) {
      body['service_date'] = serviceDate.toIso8601String().split('T')[0];
    }
    if (serviceType != null) body['service_type'] = serviceType;
    if (odometerKm != null) body['odometer_km'] = odometerKm;
    if (totalCost != null) body['total_cost'] = totalCost;
    if (reference != null) body['reference'] = reference;
    if (note != null) body['note'] = note;

    final response = await _apiClient.patch(
      '/services/services/$serviceId',
      body: body,
    );
    return Service.fromJson(response);
  }

  Future<void> deleteService(String serviceId) async {
    await _apiClient.delete('/services/services/$serviceId');
  }

  // Service Items

  Future<List<ServiceItem>> getServiceItems(String serviceId) async {
    final response = await _apiClient.get(
      '/services/services/$serviceId/items',
    );
    if (response is List) {
      return response.map((json) => ServiceItem.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<ServiceItem>> setServiceItems(
    String serviceId,
    List<ServiceItem> items,
  ) async {
    final response = await _apiClient.put(
      '/services/services/$serviceId/items',
      body: items.map((item) => item.toJson()).toList(),
    );
    if (response is List) {
      return response.map((json) => ServiceItem.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> deleteServiceItem(String itemId) async {
    await _apiClient.delete('/services/services/items/$itemId');
  }
}
