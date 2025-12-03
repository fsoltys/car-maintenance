import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/reminder_service.dart';
import '../../core/api/meta_service.dart';

class AddReminderScreen extends StatefulWidget {
  final Vehicle vehicle;
  final Reminder? reminder;

  const AddReminderScreen({super.key, required this.vehicle, this.reminder});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final ReminderService _reminderService = ReminderService();
  final MetaService _metaService = MetaService();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _daysController;
  late TextEditingController _kmController;

  String? _selectedServiceType;
  bool _isRecurring = true;
  bool _autoResetOnService = false;
  bool _isSubmitting = false;
  List<ServiceTypeEnum> _serviceTypes = [];

  bool get _isEditMode => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.reminder?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.reminder?.description ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.reminder?.category ?? '',
    );
    _daysController = TextEditingController(
      text: widget.reminder?.dueEveryDays?.toString() ?? '',
    );
    _kmController = TextEditingController(
      text: widget.reminder?.dueEveryKm?.toString() ?? '',
    );
    _selectedServiceType = widget.reminder?.serviceType;
    _isRecurring = widget.reminder?.isRecurring ?? true;
    _autoResetOnService = widget.reminder?.autoResetOnService ?? false;

    _loadServiceTypes();
  }

  Future<void> _loadServiceTypes() async {
    try {
      final types = await _metaService.getServiceTypes();
      setState(() {
        _serviceTypes = types;
      });
    } catch (e) {
      // Keep default empty list
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _daysController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // At least one interval must be set
    if (_daysController.text.isEmpty && _kmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set at least one interval (days or km)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isEditMode) {
        final update = ReminderUpdate(
          name: _nameController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          category: _categoryController.text.isEmpty
              ? null
              : _categoryController.text,
          serviceType: _selectedServiceType,
          isRecurring: _isRecurring,
          dueEveryDays: _daysController.text.isEmpty
              ? null
              : int.parse(_daysController.text),
          dueEveryKm: _kmController.text.isEmpty
              ? null
              : int.parse(_kmController.text),
          autoResetOnService: _autoResetOnService,
        );

        await _reminderService.updateReminder(widget.reminder!.id, update);
      } else {
        final create = ReminderCreate(
          name: _nameController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          category: _categoryController.text.isEmpty
              ? null
              : _categoryController.text,
          serviceType: _selectedServiceType,
          isRecurring: _isRecurring,
          dueEveryDays: _daysController.text.isEmpty
              ? null
              : int.parse(_daysController.text),
          dueEveryKm: _kmController.text.isEmpty
              ? null
              : int.parse(_kmController.text),
          autoResetOnService: _autoResetOnService,
        );

        await _reminderService.createReminder(widget.vehicle.id, create);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'Reminder updated' : 'Reminder created',
            ),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditMode ? 'Edit Reminder' : 'Add Reminder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Name',
                  hintText: 'e.g., Oil Change',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  if (value.length > 160) {
                    return 'Name must be 160 characters or less';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Add any notes or details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 16),

              // Service Type
              DropdownButtonFormField<String>(
                value: _selectedServiceType,
                decoration: const InputDecoration(
                  labelText: 'Service Type (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: _serviceTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type.value,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedServiceType = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Category
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  hintText: 'e.g., Maintenance, Safety',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 24),

              // Section header
              Text(
                'Reminder Intervals',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _isRecurring
                    ? 'Set how often this reminder should repeat'
                    : 'Set when this one-time reminder is due',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 16),

              // Recurring toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recurring reminder',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRecurring
                                ? 'This reminder will repeat automatically'
                                : 'This reminder will only trigger once',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isRecurring,
                      onChanged: (value) {
                        setState(() {
                          _isRecurring = value;
                          // Disable auto-reset for non-recurring reminders
                          if (!value) {
                            _autoResetOnService = false;
                          }
                        });
                      },
                      activeColor: AppColors.accentPrimary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Time-based interval
              TextFormField(
                controller: _daysController,
                decoration: InputDecoration(
                  labelText: _isRecurring ? 'Every (Days)' : 'Due in (Days)',
                  hintText: _isRecurring ? 'e.g., 180' : 'e.g., 30',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              const SizedBox(height: 16),

              // Distance-based interval
              TextFormField(
                controller: _kmController,
                decoration: InputDecoration(
                  labelText: _isRecurring
                      ? 'Every (Kilometers)'
                      : 'Due in (Kilometers)',
                  hintText: _isRecurring ? 'e.g., 10000' : 'e.g., 5000',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.speed),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              const SizedBox(height: 24),

              // Auto-reset option (only for recurring reminders)
              if (_isRecurring)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-reset on service',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Automatically reset this reminder when a matching service is recorded',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoResetOnService,
                        onChanged: (value) {
                          setState(() {
                            _autoResetOnService = value;
                          });
                        },
                        activeColor: AppColors.accentPrimary,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditMode ? 'UPDATE REMINDER' : 'CREATE REMINDER',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
