import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/expense_service.dart';
import '../../core/api/meta_service.dart';
import 'expense_history_screen.dart';
import 'add_expense_screen.dart';
import 'expense_details_screen.dart';
import 'trip_cost_calculator_screen.dart';

class ExpensesScreen extends StatefulWidget {
  final Vehicle vehicle;

  const ExpensesScreen({super.key, required this.vehicle});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  final ExpenseService _expenseService = ExpenseService();
  List<Expense> _recentExpenses = [];
  List<ExpenseCategoryEnum> _categories = [];
  ExpenseSummary? _summary;
  bool _isLoading = true;
  String? _error;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get date 3 months ago for recent expenses
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));

      // Get expenses from this month for the summary card
      final thisMonthStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );

      final expenses = await _expenseService.getVehicleExpenses(
        widget.vehicle.id,
        fromDate: threeMonthsAgo,
      );
      final summary = await _expenseService.getExpensesSummary(
        widget.vehicle.id,
        fromDate: thisMonthStart,
      );
      final categories = await _expenseService.getExpenseCategories();

      // Sort by date descending (newest first)
      expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

      setState(() {
        _recentExpenses = expenses;
        _summary = summary;
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
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

  double _getCategoryTotal(String categoryValue) {
    if (_summary?.perCategory == null) return 0.0;
    final categoryData = _summary!.perCategory!.firstWhere(
      (c) => c.category == categoryValue,
      orElse: () =>
          CategoryTotal(category: categoryValue, totalAmount: 0.0, count: 0),
    );
    return categoryData.totalAmount;
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
            const Text('Expenses'),
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
                    onPressed: _loadExpenses,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary Card
                  _buildSummaryCard(),
                  const SizedBox(height: 24),

                  // Recent Expenses Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Expenses (Last 3 Months)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Recent Expenses List
                  if (_recentExpenses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recent expenses',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._recentExpenses.map(
                      (expense) => _buildExpenseCard(expense),
                    ),

                  // View All Button
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ExpenseHistoryScreen(vehicle: widget.vehicle),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('View All Expense History'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      side: BorderSide(color: AppColors.accentPrimary),
                      foregroundColor: AppColors.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: widget.vehicle.userRole != 'VIEWER'
          ? _buildExpandableFab()
          : null,
    );
  }

  Widget _buildSummaryCard() {
    final totalCosts = _summary?.totalAmount ?? 0.0;
    final expenseCount =
        _summary?.perCategory?.fold<int>(0, (sum, cat) => sum + cat.count) ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textMuted.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.calendar_month,
                color: AppColors.accentPrimary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'This Month',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total amount
          Text(
            '${totalCosts.toStringAsFixed(2)} PLN',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 36,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$expenseCount ${expenseCount == 1 ? 'expense' : 'expenses'}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final categoryColor = _getCategoryColor(expense.category);
    final categoryIcon = _getCategoryIcon(expense.category);
    final categoryLabel = _getCategoryLabel(expense.category);

    return InkWell(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                AddExpenseScreen(vehicle: widget.vehicle, expense: expense),
          ),
        );
        if (result == true) {
          _loadExpenses();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
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
      ),
    );
  }

  Widget _buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabExpanded) ...[
          // Cost Calculator FAB
          _buildSmallFab(
            icon: Icons.calculate,
            label: 'Cost Calculator',
            onPressed: () {
              setState(() => _isFabExpanded = false);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      TripCostCalculatorScreen(vehicle: widget.vehicle),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Expense Details FAB
          _buildSmallFab(
            icon: Icons.bar_chart,
            label: 'Expense Details',
            onPressed: () {
              setState(() => _isFabExpanded = false);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ExpenseDetailsScreen(vehicle: widget.vehicle),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Add Expense FAB
          _buildSmallFab(
            icon: Icons.receipt_long,
            label: 'Add Expense',
            onPressed: () async {
              setState(() => _isFabExpanded = false);
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AddExpenseScreen(vehicle: widget.vehicle),
                ),
              );
              if (result == true) {
                _loadExpenses();
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        // Main FAB
        FloatingActionButton(
          onPressed: () {
            setState(() => _isFabExpanded = !_isFabExpanded);
          },
          backgroundColor: AppColors.accentPrimary,
          child: AnimatedRotation(
            turns: _isFabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_isFabExpanded ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallFab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: label,
          mini: true,
          onPressed: onPressed,
          backgroundColor: AppColors.accentPrimary,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }
}
