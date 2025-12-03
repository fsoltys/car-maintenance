import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/service_service.dart';
import '../../core/api/meta_service.dart';
import '../../core/api/reminder_service.dart';

class AddServiceScreen extends StatefulWidget {
  final Vehicle vehicle;
  final Service? service; // If provided, this is edit mode

  const AddServiceScreen({super.key, required this.vehicle, this.service});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final ServiceService _serviceService = ServiceService();
  final MetaService _metaService = MetaService();
  final ReminderService _reminderService = ReminderService();

  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _totalCostController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedType;
  List<ServiceTypeEnum> _serviceTypes = [];
  List<ServiceItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingItems = false;
  bool _isLoadingTypes = true;

  bool get _isEditMode => widget.service != null;

  @override
  void initState() {
    super.initState();
    _loadServiceTypes();
  }

  Future<void> _loadServiceTypes() async {
    try {
      final types = await _metaService.getServiceTypes();
      setState(() {
        _serviceTypes = types;
        _isLoadingTypes = false;
      });

      if (_isEditMode) {
        _selectedDate = widget.service!.serviceDate;
        _selectedType = widget.service!.serviceType;
        _odometerController.text = widget.service!.odometerKm?.toString() ?? '';
        _totalCostController.text = widget.service!.totalCost?.toString() ?? '';
        _referenceController.text = widget.service!.reference ?? '';
        _noteController.text = widget.service!.note ?? '';
        _loadServiceItems();
      } else if (_serviceTypes.isNotEmpty) {
        // Set default to first type
        _selectedType = _serviceTypes.first.value;
      }
    } catch (e) {
      setState(() => _isLoadingTypes = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load service types: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadServiceItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final items = await _serviceService.getServiceItems(widget.service!.id);
      setState(() {
        _items = items;
        _isLoadingItems = false;
      });
    } catch (e) {
      setState(() => _isLoadingItems = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load service items: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _totalCostController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _deleteService() async {
    try {
      await _serviceService.deleteService(widget.service!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete service: $e'),
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
        title: const Text('Delete Service'),
        content: const Text(
          'Are you sure you want to delete this service record? All service items will also be deleted.',
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
              _deleteService();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service type'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final odometerKm = _odometerController.text.trim().isEmpty
          ? null
          : double.parse(_odometerController.text);
      final totalCost = _totalCostController.text.trim().isEmpty
          ? null
          : double.parse(_totalCostController.text);
      final reference = _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim();
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();

      Service savedService;

      if (_isEditMode) {
        savedService = await _serviceService.updateService(
          widget.service!.id,
          serviceDate: _selectedDate,
          serviceType: _selectedType!,
          odometerKm: odometerKm,
          totalCost: totalCost,
          reference: reference,
          note: note,
        );
      } else {
        savedService = await _serviceService.createService(
          vehicleId: widget.vehicle.id,
          serviceDate: _selectedDate,
          serviceType: _selectedType!,
          odometerKm: odometerKm,
          totalCost: totalCost,
          reference: reference,
          note: note,
        );
      }

      // Save service items if any
      if (_items.isNotEmpty) {
        await _serviceService.setServiceItems(savedService.id, _items);
      }

      // Check for matching reminders and prompt for renewal
      if (!_isEditMode) {
        await _checkAndPromptReminderRenewal(savedService);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Service updated successfully'
                  : 'Service added successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save service: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _checkAndPromptReminderRenewal(Service service) async {
    try {
      // Get all reminders for this vehicle
      final reminders = await _reminderService.getVehicleReminders(
        widget.vehicle.id,
      );

      // Find reminders that match the service type AND have auto-reset enabled
      final matchingReminders = reminders.where((reminder) {
        // Only process reminders with auto-reset enabled
        if (!reminder.autoResetOnService) {
          return false;
        }

        // Match by service type
        if (reminder.serviceType != null &&
            reminder.serviceType == service.serviceType) {
          return true;
        }
        return false;
      }).toList();

      if (matchingReminders.isEmpty || !mounted) {
        return;
      }

      // Show prompt for each matching reminder
      for (final reminder in matchingReminders) {
        final shouldRenew = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reminder Found'),
            content: Text(
              'You have a reminder set for "${reminder.name}". '
              'Would you like to renew it based on this service?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                ),
                child: const Text('Yes, Renew'),
              ),
            ],
          ),
        );

        if (shouldRenew == true && mounted) {
          try {
            await _reminderService.renewReminder(
              reminder.id,
              reason: 'Service completed: ${service.serviceType}',
              odometer: service.odometerKm,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reminder "${reminder.name}" renewed'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to renew reminder: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // Silently fail - don't interrupt the service creation flow
      debugPrint('Error checking reminders: $e');
    }
  }

  void _addServiceItem() {
    showDialog(
      context: context,
      builder: (context) => _ServiceItemDialog(
        onSave: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  void _editServiceItem(int index) {
    showDialog(
      context: context,
      builder: (context) => _ServiceItemDialog(
        item: _items[index],
        onSave: (item) {
          setState(() {
            _items[index] = item;
          });
        },
      ),
    );
  }

  void _deleteServiceItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
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
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditMode ? 'Edit Service' : 'Add Service',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        actions: _isEditMode && widget.vehicle.userRole != 'VIEWER'
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: _showDeleteConfirmation,
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
                      color: AppColors.accentSecondary,
                      size: 24,
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

              // Service Type
              Text(
                'Service Type',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _isLoadingTypes
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedType,
                      dropdownColor: AppColors.bgSurface,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: _serviceTypes.map((type) {
                        return DropdownMenuItem(
                          value: type.value,
                          child: Text(type.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                    ),
              const SizedBox(height: 16),

              // Service Date
              Text(
                'Service Date',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Odometer
              Text(
                'Odometer (km)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _odometerController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Optional',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed < 0) {
                      return 'Please enter a valid odometer value';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Total Cost
              Text('Total Cost', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalCostController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Optional',
                  prefixText: '\$ ',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed < 0) {
                      return 'Please enter a valid cost';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reference
              Text(
                'Reference / Invoice #',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referenceController,
                maxLength: 64,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Optional',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),

              // Note
              Text('Notes', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Optional',
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),

              // Service Items Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Service Items',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: _addServiceItem,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Item'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textMuted.withOpacity(0.2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No items added yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.partName ?? 'Unnamed Part',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (item.partNumber != null)
                                Text(
                                  'P/N: ${item.partNumber}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              if (item.quantity != null &&
                                  item.unitPrice != null)
                                Text(
                                  '${item.quantity} × \$${item.unitPrice!.toStringAsFixed(2)} = \$${item.totalPrice.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          color: AppColors.accentSecondary,
                          onPressed: () => _editServiceItem(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          color: AppColors.error,
                          onPressed: () => _deleteServiceItem(index),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // Save Button
              if (widget.vehicle.userRole != 'VIEWER')
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
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
                          _isEditMode ? 'Update Service' : 'Add Service',
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

class _ServiceItemDialog extends StatefulWidget {
  final ServiceItem? item;
  final Function(ServiceItem) onSave;

  const _ServiceItemDialog({this.item, required this.onSave});

  @override
  State<_ServiceItemDialog> createState() => _ServiceItemDialogState();
}

class _ServiceItemDialogState extends State<_ServiceItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _partNameController;
  late TextEditingController _partNumberController;
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;

  @override
  void initState() {
    super.initState();
    _partNameController = TextEditingController(
      text: widget.item?.partName ?? '',
    );
    _partNumberController = TextEditingController(
      text: widget.item?.partNumber ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.item?.quantity?.toString() ?? '',
    );
    _unitPriceController = TextEditingController(
      text: widget.item?.unitPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _partNameController.dispose();
    _partNumberController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final item = ServiceItem(
      id: widget.item?.id ?? '',
      serviceId: widget.item?.serviceId ?? '',
      partName: _partNameController.text.trim().isEmpty
          ? null
          : _partNameController.text.trim(),
      partNumber: _partNumberController.text.trim().isEmpty
          ? null
          : _partNumberController.text.trim(),
      quantity: _quantityController.text.trim().isEmpty
          ? null
          : double.parse(_quantityController.text),
      unitPrice: _unitPriceController.text.trim().isEmpty
          ? null
          : double.parse(_unitPriceController.text),
    );

    widget.onSave(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgSurface,
      title: Text(
        widget.item == null ? 'Add Service Item' : 'Edit Service Item',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _partNameController,
                decoration: const InputDecoration(
                  labelText: 'Part Name',
                  hintText: 'e.g., Oil Filter',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a part name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _partNumberController,
                decoration: const InputDecoration(
                  labelText: 'Part Number (Optional)',
                  hintText: 'e.g., OEM-12345',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'e.g., 1',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed <= 0) {
                      return 'Please enter a valid quantity';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unit Price',
                  hintText: 'e.g., 25.99',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed < 0) {
                      return 'Please enter a valid price';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentPrimary,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
