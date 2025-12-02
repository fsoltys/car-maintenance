import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/odometer_service.dart';

class AddManualEntryScreen extends StatefulWidget {
  final Vehicle vehicle;
  final String? entryId; // If provided, this is edit mode

  const AddManualEntryScreen({super.key, required this.vehicle, this.entryId});

  @override
  State<AddManualEntryScreen> createState() => _AddManualEntryScreenState();
}

class _AddManualEntryScreenState extends State<AddManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final OdometerService _odometerService = OdometerService();

  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingEntry = false;
  OdometerEntry? _existingEntry;

  bool get _isEditMode => widget.entryId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExistingEntry();
    }
  }

  Future<void> _loadExistingEntry() async {
    setState(() => _isLoadingEntry = true);

    try {
      // Load the entry from odometer history
      final history = await _odometerService.getOdometerGraph(
        widget.vehicle.id,
      );
      final entry = history.firstWhere(
        (e) =>
            e.sourceId == widget.entryId && e.source.toLowerCase() == 'manual',
      );

      setState(() {
        _selectedDate = entry.timestamp;
        _odometerController.text = entry.odometerKm.toStringAsFixed(1);
        _isLoadingEntry = false;
      });
    } catch (e) {
      setState(() => _isLoadingEntry = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load entry: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _noteController.dispose();
    super.dispose();
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

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
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

      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final odometerValue = double.parse(_odometerController.text);
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();

      if (_isEditMode) {
        await _odometerService.updateOdometerEntry(
          widget.entryId!,
          entryDate: _selectedDate,
          valueKm: odometerValue,
          note: note,
        );
      } else {
        await _odometerService.createOdometerEntry(
          widget.vehicle.id,
          _selectedDate,
          odometerValue,
          note: note,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Entry updated successfully'
                  : 'Entry added successfully',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save entry: $e')));
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
          _isEditMode ? 'Edit Manual Entry' : 'Add Manual Entry',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: _isLoadingEntry
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date/Time picker
                    Text(
                      'Date & Time',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgMain,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.accentSecondary.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: AppColors.accentSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat(
                                'dd MMM yyyy, HH:mm',
                              ).format(_selectedDate),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Odometer value
                    Text(
                      'Odometer Reading (km)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _odometerController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter odometer value',
                        prefixIcon: Icon(
                          Icons.speed,
                          color: AppColors.accentSecondary,
                        ),
                        suffixText: 'km',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter odometer value';
                        }
                        final numValue = double.tryParse(value);
                        if (numValue == null || numValue < 0) {
                          return 'Please enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Note (optional)
                    Text(
                      'Note (optional)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add a note about this reading',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveEntry,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.accentPrimary,
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
                              _isEditMode ? 'Update Entry' : 'Add Entry',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
