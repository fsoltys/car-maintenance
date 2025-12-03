import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/export_service.dart';

class ExportDataScreen extends StatefulWidget {
  final Vehicle vehicle;

  const ExportDataScreen({super.key, required this.vehicle});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  final ExportService _exportService = ExportService();

  String _selectedDataType = 'fuelings';
  String _selectedFileType = 'csv';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isExporting = false;

  final Map<String, String> _dataTypes = {
    'fuelings': 'Fuel Entries',
    'services': 'Service Records',
    'expenses': 'Expenses',
    'odometer': 'Odometer History',
  };

  @override
  void initState() {
    super.initState();
    // Default to last 12 months
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate!.year - 1, _endDate!.month, _endDate!.day);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentPrimary,
              onPrimary: Colors.white,
              surface: AppColors.bgSurface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _exportData() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range'),
          backgroundColor: AppColors.accentPrimary,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final csvData = await _exportService.exportData(
        vehicleId: widget.vehicle.id,
        dataType: _selectedDataType,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Could not access storage');
      }

      final fileName =
          '${widget.vehicle.name}_${_selectedDataType}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(csvData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported: $fileName\nLocation: Internal Storage/Android/data/com.example.car_maintenance/files',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        title: const Text('Export Data'),
        backgroundColor: AppColors.bgSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle Info
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
                    widget.vehicle.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.vehicle.model != null)
                    Text(
                      widget.vehicle.model!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data Type Selection
            Text('Data Type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _dataTypes.entries.map((entry) {
                  return RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                    groupValue: _selectedDataType,
                    activeColor: AppColors.accentPrimary,
                    onChanged: (value) {
                      setState(() => _selectedDataType = value!);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // File Type Selection (disabled for now, only CSV)
            Text('File Type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart, color: AppColors.accentPrimary),
                  const SizedBox(width: 12),
                  const Text('CSV (Comma-Separated Values)'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        color: AppColors.accentPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date Range Selection
            Text('Date Range', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accentPrimary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_startDate != null && _endDate != null)
                            Text(
                              '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            const Text(
                              'Select date range',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Export Button
            ElevatedButton(
              onPressed: _isExporting ? null : _exportData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isExporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download),
                        SizedBox(width: 8),
                        Text(
                          'Export Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
