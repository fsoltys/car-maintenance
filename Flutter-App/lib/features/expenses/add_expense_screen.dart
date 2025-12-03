import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/expense_service.dart';
import '../../core/api/meta_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final Vehicle vehicle;
  final Expense? expense; // If provided, this is edit mode

  const AddExpenseScreen({super.key, required this.vehicle, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ExpenseService _expenseService = ExpenseService();
  final MetaService _metaService = MetaService();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _vatRateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  List<ExpenseCategoryEnum> _categories = [];
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isEditMode => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _metaService.getExpenseCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });

      if (_isEditMode) {
        _selectedDate = widget.expense!.expenseDate;
        _selectedCategory = widget.expense!.category;
        _amountController.text = widget.expense!.amount.toString();
        _vatRateController.text = widget.expense!.vatRate?.toString() ?? '';
        _noteController.text = widget.expense!.note ?? '';
      } else if (_categories.isNotEmpty) {
        // Set default to first category
        _selectedCategory = _categories.first.value;
      }
    } catch (e) {
      setState(() => _isLoadingCategories = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _vatRateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _deleteExpense() async {
    setState(() => _isDeleting = true);
    try {
      await _expenseService.deleteExpense(widget.expense!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete expense: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Delete Expense'),
        content: const Text(
          'Are you sure you want to delete this expense record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteExpense();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);
      final vatRate = _vatRateController.text.isNotEmpty
          ? double.parse(_vatRateController.text)
          : null;

      if (_isEditMode) {
        await _expenseService.updateExpense(
          widget.expense!.id,
          ExpenseUpdate(
            expenseDate: _selectedDate,
            category: _selectedCategory!,
            amount: amount,
            vatRate: vatRate,
            note: _noteController.text.isNotEmpty ? _noteController.text : null,
          ),
        );
      } else {
        await _expenseService.createExpense(
          widget.vehicle.id,
          ExpenseCreate(
            expenseDate: _selectedDate,
            category: _selectedCategory!,
            amount: amount,
            vatRate: vatRate,
            note: _noteController.text.isNotEmpty ? _noteController.text : null,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Expense updated successfully'
                  : 'Expense added successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save expense: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.accentPrimary,
              onPrimary: AppColors.textPrimary,
              surface: AppColors.bgSurface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  String _getCategoryLabel(String value) {
    final category = _categories.firstWhere(
      (c) => c.value == value,
      orElse: () => ExpenseCategoryEnum(value: value, label: value),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCategories) {
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
          title: Text(
            _isEditMode ? 'Edit Expense' : 'Add Expense',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
        title: Text(
          _isEditMode ? 'Edit Expense' : 'Add Expense',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        actions: _isEditMode && widget.vehicle.userRole != 'VIEWER'
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: _isDeleting ? null : _showDeleteConfirmation,
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vehicle info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: AppColors.accentPrimary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vehicle.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (widget.vehicle.model != null)
                            Text(
                              widget.vehicle.model!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date picker
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense Date',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: widget.vehicle.userRole != 'VIEWER'
                          ? _selectDate
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.textMuted.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(_selectedDate),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: AppColors.accentPrimary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category dropdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AppColors.textMuted.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AppColors.textMuted.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AppColors.accentPrimary,
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.bgMain,
                      ),
                      dropdownColor: AppColors.bgSurface,
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.value,
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(category.value),
                                size: 20,
                                color: AppColors.accentPrimary,
                              ),
                              const SizedBox(width: 12),
                              Text(category.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: widget.vehicle.userRole != 'VIEWER'
                          ? (value) {
                              setState(() => _selectedCategory = value);
                            }
                          : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount field
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount (PLN)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: widget.vehicle.userRole != 'VIEWER',
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: AppColors.accentPrimary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: AppColors.bgMain,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // VAT rate field (optional)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VAT Rate (%) - Optional',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _vatRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: widget.vehicle.userRole != 'VIEWER',
                      decoration: InputDecoration(
                        hintText: '23.0',
                        prefixIcon: Icon(
                          Icons.percent,
                          color: AppColors.accentPrimary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: AppColors.bgMain,
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final val = double.tryParse(value);
                          if (val == null) {
                            return 'Please enter a valid number';
                          }
                          if (val < 0 || val > 100) {
                            return 'VAT rate must be between 0 and 100';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Note field (optional)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note - Optional',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      enabled: widget.vehicle.userRole != 'VIEWER',
                      decoration: InputDecoration(
                        hintText: 'Add any additional notes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: AppColors.bgMain,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              if (widget.vehicle.userRole != 'VIEWER')
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textPrimary,
                            ),
                          ),
                        )
                      : Text(
                          _isEditMode ? 'Update Expense' : 'Add Expense',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
