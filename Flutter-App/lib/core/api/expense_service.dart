import 'api_client.dart';
import 'meta_service.dart';

class ExpenseService {
  final ApiClient _apiClient;
  final MetaService _metaService;

  ExpenseService({ApiClient? apiClient, MetaService? metaService})
    : _apiClient = apiClient ?? ApiClient(),
      _metaService = metaService ?? MetaService();

  /// Get all expenses for a vehicle
  Future<List<Expense>> getVehicleExpenses(
    String vehicleId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? category,
  }) async {
    final queryParams = <String, String>{};
    if (fromDate != null) {
      queryParams['from_date'] = fromDate.toIso8601String().split('T')[0];
    }
    if (toDate != null) {
      queryParams['to_date'] = toDate.toIso8601String().split('T')[0];
    }
    if (category != null) {
      queryParams['category'] = category;
    }

    String url = '/vehicles/$vehicleId/expenses';
    if (queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      url = '$url?$query';
    }

    final response = await _apiClient.get(url);
    if (response is List) {
      return response
          .map((json) => Expense.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get expenses summary for a vehicle
  Future<ExpenseSummary> getExpensesSummary(
    String vehicleId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final queryParams = <String, String>{};
    if (fromDate != null) {
      queryParams['from_date'] = fromDate.toIso8601String().split('T')[0];
    }
    if (toDate != null) {
      queryParams['to_date'] = toDate.toIso8601String().split('T')[0];
    }

    String url = '/vehicles/$vehicleId/expenses/summary';
    if (queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      url = '$url?$query';
    }

    final response = await _apiClient.get(url);
    return ExpenseSummary.fromJson(response as Map<String, dynamic>);
  }

  /// Create a new expense
  Future<Expense> createExpense(String vehicleId, ExpenseCreate expense) async {
    final response = await _apiClient.post(
      '/vehicles/$vehicleId/expenses',
      body: expense.toJson(),
    );
    return Expense.fromJson(response);
  }

  /// Update an expense
  Future<Expense> updateExpense(String expenseId, ExpenseUpdate expense) async {
    final response = await _apiClient.patch(
      '/expenses/$expenseId',
      body: expense.toJson(),
    );
    return Expense.fromJson(response);
  }

  /// Delete an expense
  Future<void> deleteExpense(String expenseId) async {
    await _apiClient.delete('/expenses/$expenseId');
  }

  /// Get expense categories
  Future<List<ExpenseCategoryEnum>> getExpenseCategories({
    bool forceRefresh = false,
  }) async {
    return _metaService.getExpenseCategories(forceRefresh: forceRefresh);
  }
}

// Models

class Expense {
  final String id;
  final String vehicleId;
  final String userId;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final double? vatRate;
  final String? note;
  final DateTime? createdAt;

  Expense({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.expenseDate,
    required this.category,
    required this.amount,
    this.vatRate,
    this.note,
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      userId: json['user_id'] as String,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      vatRate: json['vat_rate'] != null
          ? (json['vat_rate'] as num).toDouble()
          : null,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'user_id': userId,
      'expense_date': expenseDate.toIso8601String().split('T')[0],
      'category': category,
      'amount': amount,
      'vat_rate': vatRate,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class ExpenseCreate {
  final DateTime expenseDate;
  final String category;
  final double amount;
  final double? vatRate;
  final String? note;

  ExpenseCreate({
    required this.expenseDate,
    required this.category,
    required this.amount,
    this.vatRate,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'expense_date': expenseDate.toIso8601String().split('T')[0],
      'category': category,
      'amount': amount,
      'vat_rate': vatRate,
      'note': note,
    };
  }
}

class ExpenseUpdate {
  final DateTime? expenseDate;
  final String? category;
  final double? amount;
  final double? vatRate;
  final String? note;

  ExpenseUpdate({
    this.expenseDate,
    this.category,
    this.amount,
    this.vatRate,
    this.note,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (expenseDate != null) {
      data['expense_date'] = expenseDate!.toIso8601String().split('T')[0];
    }
    if (category != null) data['category'] = category;
    if (amount != null) data['amount'] = amount;
    if (vatRate != null) data['vat_rate'] = vatRate;
    if (note != null) data['note'] = note;
    return data;
  }
}

class CategoryTotal {
  final String category;
  final double totalAmount;
  final int count;

  CategoryTotal({
    required this.category,
    required this.totalAmount,
    required this.count,
  });

  factory CategoryTotal.fromJson(Map<String, dynamic> json) {
    return CategoryTotal(
      category: json['category'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      count: json['cnt'] as int,
    );
  }
}

class ExpenseSummary {
  final double? totalAmount;
  final double? periodKm;
  final double? costPer100Km;
  final List<CategoryTotal>? perCategory;
  final List<dynamic>? monthlySeries;

  ExpenseSummary({
    this.totalAmount,
    this.periodKm,
    this.costPer100Km,
    this.perCategory,
    this.monthlySeries,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    List<CategoryTotal>? categoryTotals;
    if (json['per_category'] != null && json['per_category'] is List) {
      categoryTotals = (json['per_category'] as List)
          .map((item) => CategoryTotal.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return ExpenseSummary(
      totalAmount: json['total_amount'] != null
          ? (json['total_amount'] as num).toDouble()
          : null,
      periodKm: json['period_km'] != null
          ? (json['period_km'] as num).toDouble()
          : null,
      costPer100Km: json['cost_per_100km'] != null
          ? (json['cost_per_100km'] as num).toDouble()
          : null,
      perCategory: categoryTotals,
      monthlySeries: json['monthly_series'] as List?,
    );
  }
}
