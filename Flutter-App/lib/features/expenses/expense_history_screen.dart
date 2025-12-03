import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/expense_service.dart';
import '../../core/api/meta_service.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  final Vehicle vehicle;

  const ExpenseHistoryScreen({super.key, required this.vehicle});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  final ExpenseService _expenseService = ExpenseService();
  List<Expense> _allExpenses = [];
  List<Expense> _filteredExpenses = [];
  List<ExpenseCategoryEnum> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;

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
      final expenses = await _expenseService.getVehicleExpenses(
        widget.vehicle.id,
      );
      final categories = await _expenseService.getExpenseCategories();

      // Sort by date descending (newest first)
      expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

      setState(() {
        _allExpenses = expenses;
        _filteredExpenses = expenses;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      if (category == null) {
        _filteredExpenses = _allExpenses;
      } else {
        _filteredExpenses = _allExpenses
            .where((expense) => expense.category == category)
            .toList();
      }
    });
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatMonth(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  String _getCategoryLabel(String categoryValue) {
    final category = _categories.firstWhere(
      (c) => c.value == categoryValue,
      orElse: () =>
          ExpenseCategoryEnum(value: categoryValue, label: categoryValue),
    );
    return category.label;
  }

  IconData _getCategoryIcon(String categoryValue) {
    switch (categoryValue.toUpperCase()) {
      case 'FUEL':
        return Icons.local_gas_station;
      case 'SERVICE':
        return Icons.build;
      case 'INSURANCE':
        return Icons.shield;
      case 'TAX':
        return Icons.account_balance;
      case 'TOLLS':
        return Icons.toll;
      case 'PARKING':
        return Icons.local_parking;
      case 'ACCESSORIES':
        return Icons.shopping_bag;
      case 'WASH':
        return Icons.local_car_wash;
      default:
        return Icons.more_horiz;
    }
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

  Map<String, List<Expense>> _groupByMonth(List<Expense> expenses) {
    final Map<String, List<Expense>> grouped = {};
    for (final expense in expenses) {
      final monthKey = DateFormat('yyyy-MM').format(expense.expenseDate);
      if (!grouped.containsKey(monthKey)) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(expense);
    }
    return grouped;
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
            const Text('Expense History'),
            Text(
              widget.vehicle.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: _selectedCategory != null ? AppColors.accentPrimary : null,
            ),
            tooltip: 'Filter by category',
            onSelected: _filterByCategory,
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 12),
                    Text('All Categories'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ..._categories.map(
                (category) => PopupMenuItem<String>(
                  value: category.value,
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(category.value),
                        size: 20,
                        color: _getCategoryColor(category.value),
                      ),
                      const SizedBox(width: 12),
                      Text(category.label),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
              child: _filteredExpenses.isEmpty
                  ? ListView(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: AppColors.textSecondary.withOpacity(
                                    0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedCategory == null
                                      ? 'No expenses yet'
                                      : 'No expenses in this category',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildGroupedExpensesList(),
            ),
    );
  }

  Widget _buildGroupedExpensesList() {
    final groupedExpenses = _groupByMonth(_filteredExpenses);
    final sortedMonths = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final monthKey = sortedMonths[index];
        final expenses = groupedExpenses[monthKey]!;
        final monthDate = DateTime.parse('$monthKey-01');
        final monthTotal = expenses.fold<double>(
          0.0,
          (sum, expense) => sum + expense.amount,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatMonth(monthDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${monthTotal.toStringAsFixed(2)} PLN',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Expenses in this month
            ...expenses.map((expense) => _buildExpenseCard(expense)),

            // Divider between months (except last)
            if (index < sortedMonths.length - 1) ...[
              const SizedBox(height: 8),
              Divider(
                color: AppColors.textMuted.withOpacity(0.3),
                thickness: 1,
              ),
            ],
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final categoryColor = _getCategoryColor(expense.category);
    final categoryIcon = _getCategoryIcon(expense.category);
    final categoryLabel = _getCategoryLabel(expense.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon, color: categoryColor, size: 24),
          ),
          const SizedBox(width: 16),

          // Expense details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(expense.expenseDate),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (expense.note != null && expense.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    expense.note!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Amount
          Text(
            '${expense.amount.toStringAsFixed(2)} PLN',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: categoryColor,
            ),
          ),
        ],
      ),
    );
  }
}
