import 'api_client.dart';

class ReminderService {
  final ApiClient _client = ApiClient();

  /// Get all reminders for a vehicle
  Future<List<Reminder>> getVehicleReminders(String vehicleId) async {
    final response = await _client.get('/vehicles/$vehicleId/reminders');
    return (response as List).map((json) => Reminder.fromJson(json)).toList();
  }

  /// Create a new reminder
  Future<Reminder> createReminder(
    String vehicleId,
    ReminderCreate reminder,
  ) async {
    final response = await _client.post(
      '/vehicles/$vehicleId/reminders',
      body: reminder.toJson(),
    );
    return Reminder.fromJson(response);
  }

  /// Update a reminder
  Future<Reminder> updateReminder(
    String reminderId,
    ReminderUpdate reminder,
  ) async {
    final response = await _client.patch(
      '/reminders/$reminderId',
      body: reminder.toJson(),
    );
    return Reminder.fromJson(response);
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    await _client.delete('/reminders/$reminderId');
  }

  /// Trigger/Renew a reminder
  Future<Reminder> renewReminder(
    String reminderId, {
    String? reason,
    double? odometer,
  }) async {
    final response = await _client.post(
      '/reminders/$reminderId/renew',
      body: {'reason': reason, 'odometer': odometer},
    );
    return Reminder.fromJson(response);
  }

  /// Estimate how many days until a kilometer-based reminder is due
  /// Returns null if there's insufficient historical data
  Future<int?> estimateDaysUntilDue(String reminderId) async {
    try {
      final response = await _client.get(
        '/reminders/$reminderId/estimate-days-until-due',
      );
      return response['estimated_days'] as int?;
    } catch (e) {
      // Return null if the reminder doesn't have a km interval or there's insufficient data
      return null;
    }
  }

  /// Check if a reminder is due soon based on a time threshold
  /// Use daysThreshold=7 for DUE status check
  /// Use daysThreshold=30 for upcoming reminders carousel
  Future<bool> isReminderDueSoon(
    String reminderId, {
    int daysThreshold = 7,
  }) async {
    final response = await _client.post(
      '/reminders/$reminderId/check-due-soon',
      body: {'days_threshold': daysThreshold},
    );
    return response['is_due_soon'] as bool? ?? false;
  }
}

// Models

class Reminder {
  final String id;
  final String vehicleId;
  final String name;
  final String? description;
  final String? category;
  final String? serviceType;
  final bool isRecurring;
  final int? dueEveryDays;
  final int? dueEveryKm;
  final DateTime? lastResetAt;
  final double? lastResetOdometerKm;
  final DateTime? nextDueDate;
  final double? nextDueOdometerKm;
  final String? status;
  final bool autoResetOnService;
  final int? estimatedDaysUntilDue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Reminder({
    required this.id,
    required this.vehicleId,
    required this.name,
    this.description,
    this.category,
    this.serviceType,
    this.isRecurring = true,
    this.dueEveryDays,
    this.dueEveryKm,
    this.lastResetAt,
    this.lastResetOdometerKm,
    this.nextDueDate,
    this.nextDueOdometerKm,
    this.status,
    this.autoResetOnService = false,
    this.estimatedDaysUntilDue,
    this.createdAt,
    this.updatedAt,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      serviceType: json['service_type'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? true,
      dueEveryDays: json['due_every_days'] as int?,
      dueEveryKm: json['due_every_km'] as int?,
      lastResetAt: json['last_reset_at'] != null
          ? DateTime.parse(json['last_reset_at'] as String)
          : null,
      lastResetOdometerKm: json['last_reset_odometer_km'] != null
          ? (json['last_reset_odometer_km'] as num).toDouble()
          : null,
      nextDueDate: json['next_due_date'] != null
          ? DateTime.parse(json['next_due_date'] as String)
          : null,
      nextDueOdometerKm: json['next_due_odometer_km'] != null
          ? (json['next_due_odometer_km'] as num).toDouble()
          : null,
      status: json['status'] as String?,
      autoResetOnService: json['auto_reset_on_service'] as bool? ?? false,
      estimatedDaysUntilDue: json['estimated_days_until_due'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

class ReminderCreate {
  final String name;
  final String? description;
  final String? category;
  final String? serviceType;
  final bool isRecurring;
  final int? dueEveryDays;
  final int? dueEveryKm;
  final bool autoResetOnService;

  ReminderCreate({
    required this.name,
    this.description,
    this.category,
    this.serviceType,
    this.isRecurring = true,
    this.dueEveryDays,
    this.dueEveryKm,
    this.autoResetOnService = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'service_type': serviceType,
      'is_recurring': isRecurring,
      'due_every_days': dueEveryDays,
      'due_every_km': dueEveryKm,
      'auto_reset_on_service': autoResetOnService,
    };
  }
}

class ReminderUpdate {
  final String? name;
  final String? description;
  final String? category;
  final String? serviceType;
  final bool? isRecurring;
  final int? dueEveryDays;
  final int? dueEveryKm;
  final String? status;
  final bool? autoResetOnService;

  // Track which fields were explicitly set (even to null)
  final bool _nameSet;
  final bool _descriptionSet;
  final bool _categorySet;
  final bool _serviceTypeSet;
  final bool _isRecurringSet;
  final bool _dueEveryDaysSet;
  final bool _dueEveryKmSet;
  final bool _statusSet;
  final bool _autoResetOnServiceSet;

  ReminderUpdate({
    this.name,
    this.description,
    this.category,
    this.serviceType,
    this.isRecurring,
    this.dueEveryDays,
    this.dueEveryKm,
    this.status,
    this.autoResetOnService,
  }) : _nameSet = true,
       _descriptionSet = true,
       _categorySet = true,
       _serviceTypeSet = true,
       _isRecurringSet = true,
       _dueEveryDaysSet = true,
       _dueEveryKmSet = true,
       _statusSet = false,
       _autoResetOnServiceSet = true;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (_nameSet) data['name'] = name;
    if (_descriptionSet) data['description'] = description;
    if (_categorySet) data['category'] = category;
    if (_serviceTypeSet) data['service_type'] = serviceType;
    if (_isRecurringSet) data['is_recurring'] = isRecurring;
    if (_dueEveryDaysSet) data['due_every_days'] = dueEveryDays;
    if (_dueEveryKmSet) data['due_every_km'] = dueEveryKm;
    if (_statusSet) data['status'] = status;
    if (_autoResetOnServiceSet)
      data['auto_reset_on_service'] = autoResetOnService;
    return data;
  }
}
