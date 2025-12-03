import 'api_client.dart';

class BudgetService {
  final ApiClient _apiClient;

  BudgetService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get budget forecast for a vehicle
  Future<BudgetForecastResponse> getBudgetForecast(
    String vehicleId, {
    int monthsAhead = 6,
    bool includeIrregular = false,
  }) async {
    final response = await _apiClient.get(
      '/vehicles/$vehicleId/budget/forecast?months_ahead=$monthsAhead&include_irregular=$includeIrregular',
    );
    return BudgetForecastResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Get budget statistics for a vehicle
  Future<BudgetStatistics> getBudgetStatistics(String vehicleId) async {
    final response = await _apiClient.get(
      '/vehicles/$vehicleId/budget/statistics',
    );
    return BudgetStatistics.fromJson(response as Map<String, dynamic>);
  }

  /// Manually trigger expense classification
  Future<Map<String, dynamic>> classifyExpenses(String vehicleId) async {
    final response = await _apiClient.post(
      '/vehicles/$vehicleId/budget/classify-expenses',
    );
    return response as Map<String, dynamic>;
  }
}

// ===== Models =====

class ScheduledServiceDetail {
  final String ruleId;
  final String name;
  final double cost;
  final DateTime date;
  final String confidence;

  ScheduledServiceDetail({
    required this.ruleId,
    required this.name,
    required this.cost,
    required this.date,
    required this.confidence,
  });

  factory ScheduledServiceDetail.fromJson(Map<String, dynamic> json) {
    return ScheduledServiceDetail(
      ruleId: json['rule_id'] as String,
      name: json['name'] as String,
      cost: (json['cost'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      confidence: json['confidence'] as String,
    );
  }
}

class MonthlyBudgetForecast {
  final DateTime month;
  final double regularCosts;
  final double scheduledMaintenance;
  final List<ScheduledServiceDetail> scheduledMaintenanceDetails;
  final double irregularBuffer;
  final double totalPredicted;
  final String confidenceLevel;

  MonthlyBudgetForecast({
    required this.month,
    required this.regularCosts,
    required this.scheduledMaintenance,
    required this.scheduledMaintenanceDetails,
    required this.irregularBuffer,
    required this.totalPredicted,
    required this.confidenceLevel,
  });

  factory MonthlyBudgetForecast.fromJson(Map<String, dynamic> json) {
    return MonthlyBudgetForecast(
      month: DateTime.parse(json['month'] as String),
      regularCosts: (json['regular_costs'] as num).toDouble(),
      scheduledMaintenance: (json['scheduled_maintenance'] as num).toDouble(),
      scheduledMaintenanceDetails:
          (json['scheduled_maintenance_details'] as List)
              .map(
                (e) =>
                    ScheduledServiceDetail.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
      irregularBuffer: (json['irregular_buffer'] as num).toDouble(),
      totalPredicted: (json['total_predicted'] as num).toDouble(),
      confidenceLevel: json['confidence_level'] as String,
    );
  }
}

class BudgetForecastResponse {
  final String vehicleId;
  final int forecastMonths;
  final bool includeIrregular;
  final double avgMonthlyMileage;
  final List<MonthlyBudgetForecast> forecasts;

  BudgetForecastResponse({
    required this.vehicleId,
    required this.forecastMonths,
    required this.includeIrregular,
    required this.avgMonthlyMileage,
    required this.forecasts,
  });

  factory BudgetForecastResponse.fromJson(Map<String, dynamic> json) {
    return BudgetForecastResponse(
      vehicleId: json['vehicle_id'] as String,
      forecastMonths: json['forecast_months'] as int,
      includeIrregular: json['include_irregular'] as bool,
      avgMonthlyMileage: (json['avg_monthly_mileage'] as num).toDouble(),
      forecasts: (json['forecasts'] as List)
          .map((e) => MonthlyBudgetForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BudgetStatistics {
  final double totalRegularLast12m;
  final double totalIrregularLast12m;
  final double avgMonthlyRegular;
  final double avgMonthlyIrregular;
  final double? largestExpenseLast12m;
  final String? largestExpenseCategory;

  BudgetStatistics({
    required this.totalRegularLast12m,
    required this.totalIrregularLast12m,
    required this.avgMonthlyRegular,
    required this.avgMonthlyIrregular,
    this.largestExpenseLast12m,
    this.largestExpenseCategory,
  });

  factory BudgetStatistics.fromJson(Map<String, dynamic> json) {
    return BudgetStatistics(
      totalRegularLast12m: (json['total_regular_last_12m'] as num).toDouble(),
      totalIrregularLast12m: (json['total_irregular_last_12m'] as num)
          .toDouble(),
      avgMonthlyRegular: (json['avg_monthly_regular'] as num).toDouble(),
      avgMonthlyIrregular: (json['avg_monthly_irregular'] as num).toDouble(),
      largestExpenseLast12m: json['largest_expense_last_12m'] != null
          ? (json['largest_expense_last_12m'] as num).toDouble()
          : null,
      largestExpenseCategory: json['largest_expense_category'] as String?,
    );
  }
}
