import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/expense_service.dart';
import '../../core/api/meta_service.dart';

class ExpenseDetailsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const ExpenseDetailsScreen({super.key, required this.vehicle});

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final MetaService _metaService = MetaService();

  List<ExpenseCategoryEnum> _categories = [];
  ExpenseSummary? _summary;
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedCategoryFilter; // null means "All"

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get last 12 months
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));

      final categories = await _metaService.getExpenseCategories();
      final summary = await _expenseService.getExpensesSummary(
        widget.vehicle.id,
        fromDate: oneYearAgo,
      );
      final expenses = await _expenseService.getVehicleExpenses(
        widget.vehicle.id,
        fromDate: oneYearAgo,
      );

      setState(() {
        _categories = categories;
        _summary = summary;
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getCategoryLabel(String categoryValue) {
    final category = _categories.firstWhere(
      (c) => c.value == categoryValue,
      orElse: () =>
          ExpenseCategoryEnum(value: categoryValue, label: categoryValue),
    );
    return category.label;
  }

  Color _getCategoryColor(String categoryValue) {
    switch (categoryValue.toUpperCase()) {
      case 'FUEL':
        return const Color(0xFF10B981);
      case 'SERVICE':
        return AppColors.accentPrimary;
      case 'INSURANCE':
        return const Color(0xFF8B5CF6);
      case 'TAX':
        return const Color(0xFFF59E0B);
      case 'TOLLS':
        return const Color(0xFF3B82F6);
      case 'PARKING':
        return AppColors.accentSecondary;
      case 'ACCESSORIES':
        return const Color(0xFFEC4899);
      case 'WASH':
        return const Color(0xFF06B6D4);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text('Expense Details'),
            Text(
              widget.vehicle.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Pie Chart Card
                  _buildPieChartCard(),
                  const SizedBox(height: 16),

                  // Bar Chart Card
                  _buildBarChartCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildPieChartCard() {
    final perCategory = _summary?.perCategory ?? [];

    if (perCategory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No expense data available')),
      );
    }

    final total = perCategory.fold<double>(
      0.0,
      (sum, cat) => sum + cat.totalAmount,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expense Breakdown by Category',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Last 12 months',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: perCategory.map((cat) {
                  final percentage = (cat.totalAmount / total) * 100;
                  return PieChartSectionData(
                    value: cat.totalAmount,
                    title: '${percentage.toStringAsFixed(1)}%',
                    color: _getCategoryColor(cat.category),
                    radius: 100,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: perCategory.map((cat) {
              final percentage = (cat.totalAmount / total) * 100;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(cat.category),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_getCategoryLabel(cat.category)}: ${percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard() {
    // Group expenses by month
    final monthlyData = <String, Map<String, double>>{};

    for (final expense in _expenses) {
      final monthKey = DateFormat('yyyy-MM').format(expense.expenseDate);

      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {};
      }

      if (_selectedCategoryFilter == null ||
          expense.category == _selectedCategoryFilter) {
        monthlyData[monthKey]![expense.category] =
            (monthlyData[monthKey]![expense.category] ?? 0.0) + expense.amount;
      }
    }

    // Sort by month
    final sortedMonths = monthlyData.keys.toList()..sort();
    final last6Months = sortedMonths.length > 6
        ? sortedMonths.sublist(sortedMonths.length - 6)
        : sortedMonths;

    if (last6Months.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No expense data available')),
      );
    }

    final maxY = last6Months.fold<double>(0.0, (max, month) {
      final total = monthlyData[month]!.values.fold<double>(
        0.0,
        (sum, amount) => sum + amount,
      );
      return total > max ? total : max;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Expenses',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last 6 months',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Category filter
              PopupMenuButton<String?>(
                icon: Icon(Icons.filter_list, color: AppColors.accentPrimary),
                onSelected: (value) {
                  setState(() => _selectedCategoryFilter = value);
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(
                          Icons.all_inclusive,
                          color: _selectedCategoryFilter == null
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        const Text('All Categories'),
                      ],
                    ),
                  ),
                  ..._categories.map((cat) {
                    return PopupMenuItem<String>(
                      value: cat.value,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _getCategoryColor(cat.value),
                          ),
                          const SizedBox(width: 8),
                          Text(cat.label),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.1,
                barGroups: last6Months.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final month = entry.value;
                  final total = monthlyData[month]!.values.fold<double>(
                    0.0,
                    (sum, amount) => sum + amount,
                  );

                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: total,
                        color: _selectedCategoryFilter != null
                            ? _getCategoryColor(_selectedCategoryFilter!)
                            : AppColors.accentPrimary,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < last6Months.length) {
                          final month = last6Months[value.toInt()];
                          final date = DateTime.parse('$month-01');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM').format(date),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.textMuted.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
