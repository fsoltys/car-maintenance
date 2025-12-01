import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/fueling_service.dart';

class EditFuelingScreen extends StatefulWidget {
  final Vehicle vehicle;
  final Fueling fueling;

  const EditFuelingScreen({
    super.key,
    required this.vehicle,
    required this.fueling,
  });

  @override
  State<EditFuelingScreen> createState() => _EditFuelingScreenState();
}

class _EditFuelingScreenState extends State<EditFuelingScreen> {
  final _formKey = GlobalKey<FormState>();
  final FuelingService _fuelingService = FuelingService();
  final VehicleService _vehicleService = VehicleService();

  // Form fields
  late DateTime _filledAt;
  final TextEditingController _pricePerUnitController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  late bool _fullTank;
  late DrivingCycle? _drivingCycle;
  late FuelType _selectedFuel;
  final TextEditingController _noteController = TextEditingController();

  // Fuel level estimation
  late double _fuelLevelPercent;
  late bool _skipFuelEstimate;

  bool _isSubmitting = false;
  bool _isDeleting = false;
  List<FuelType> _availableFuels = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableFuels();
    _populateFields();
  }

  void _populateFields() {
    _filledAt = widget.fueling.filledAt;
    _pricePerUnitController.text = widget.fueling.pricePerUnit.toString();
    _volumeController.text = widget.fueling.volume.toString();
    _odometerController.text = widget.fueling.odometerKm.toString();
    _fullTank = widget.fueling.fullTank;
    _drivingCycle = widget.fueling.drivingCycle;
    _selectedFuel = widget.fueling.fuel;
    _noteController.text = widget.fueling.note ?? '';

    // Set fuel level from existing data
    if (widget.fueling.fuelLevelBefore != null) {
      _fuelLevelPercent = widget.fueling.fuelLevelBefore!;
      _skipFuelEstimate = false;
    } else {
      _fuelLevelPercent = 50.0;
      _skipFuelEstimate = true;
    }
  }

  Future<void> _loadAvailableFuels() async {
    try {
      final fuels = await _vehicleService.getVehicleFuels(widget.vehicle.id);

      if (fuels.isNotEmpty) {
        setState(() {
          _availableFuels = fuels
              .map((fuelConfig) => _parseFuelType(fuelConfig.fuel))
              .toList();
        });
      } else {
        setState(() {
          _availableFuels = FuelType.values;
        });
      }
    } catch (e) {
      setState(() {
        _availableFuels = FuelType.values;
      });
    }
  }

  FuelType _parseFuelType(String fuelString) {
    return FuelType.values.firstWhere(
      (e) => e.name == fuelString,
      orElse: () => FuelType.Petrol,
    );
  }

  @override
  void dispose() {
    _pricePerUnitController.dispose();
    _volumeController.dispose();
    _odometerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filledAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_filledAt),
      );

      if (time != null) {
        setState(() {
          _filledAt = DateTime(
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

  Future<void> _submitFueling() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      double? fuelLevelBefore;
      double? fuelLevelAfter;

      if (_fullTank) {
        fuelLevelAfter = 100.0;
      } else if (!_skipFuelEstimate) {
        fuelLevelBefore = _fuelLevelPercent;
        final tankCapacity = widget.vehicle.tankCapacityL ?? 50.0;
        fuelLevelAfter =
            _fuelLevelPercent +
            (double.parse(_volumeController.text) / tankCapacity * 100);
        if (fuelLevelAfter > 100) fuelLevelAfter = 100;
      }

      final fueling = FuelingUpdate(
        filledAt: _filledAt,
        pricePerUnit: double.parse(_pricePerUnitController.text),
        volume: double.parse(_volumeController.text),
        odometerKm: double.parse(_odometerController.text),
        fullTank: _fullTank,
        drivingCycle: _drivingCycle,
        fuel: _selectedFuel,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        fuelLevelBefore: fuelLevelBefore,
        fuelLevelAfter: fuelLevelAfter,
      );

      await _fuelingService.updateFueling(widget.fueling.id, fueling);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fueling updated successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  Future<void> _deleteFueling() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fueling'),
        content: const Text(
          'Are you sure you want to delete this fueling record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _fuelingService.deleteFueling(widget.fueling.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fueling deleted successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit Fueling'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isDeleting ? null : _deleteFueling,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date/Time picker
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
                    'Date & Time',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDate,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_filledAt.day.toString().padLeft(2, '0')}.${_filledAt.month.toString().padLeft(2, '0')}.${_filledAt.year} ${_filledAt.hour.toString().padLeft(2, '0')}:${_filledAt.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: AppColors.accentPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Fuel type selector
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
                    'Fuel Type',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FuelType>(
                    value: _selectedFuel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _availableFuels.map((fuel) {
                      return DropdownMenuItem(
                        value: fuel,
                        child: Text(fuel.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFuel = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Price per unit and volume
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _pricePerUnitController,
                    label: 'Price per unit',
                    suffix: 'PLN/L',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      if (double.parse(value) <= 0) {
                        return 'Must be > 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _volumeController,
                    label: 'Volume',
                    suffix: 'L',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      if (double.parse(value) <= 0) {
                        return 'Must be > 0';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Odometer
            _buildTextField(
              controller: _odometerController,
              label: 'Odometer',
              suffix: 'km',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (double.tryParse(value) == null) {
                  return 'Invalid number';
                }
                if (double.parse(value) <= 0) {
                  return 'Must be greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Full tank switch
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Tank',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enable for accurate consumption',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _fullTank,
                    onChanged: (value) {
                      setState(() {
                        _fullTank = value;
                      });
                    },
                    activeColor: AppColors.accentPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Fuel level slider (only for partial tanks)
            if (!_fullTank) ...[
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
                      'Tank Level Before Fueling',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For consumption estimation',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fuel level slider
                    Text(
                      'Tank Level: ${_fuelLevelPercent.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.accentSecondary,
                        inactiveTrackColor: AppColors.accentSecondary
                            .withOpacity(0.2),
                        thumbColor: AppColors.accentSecondary,
                        overlayColor: AppColors.accentSecondary.withOpacity(
                          0.2,
                        ),
                        valueIndicatorColor: AppColors.accentSecondary,
                      ),
                      child: Slider(
                        value: _fuelLevelPercent,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${_fuelLevelPercent.toStringAsFixed(0)}%',
                        onChanged: (value) {
                          setState(() {
                            _fuelLevelPercent = value;
                          });
                        },
                      ),
                    ),

                    // Visual fuel gauge
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: _fuelLevelPercent / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accentSecondary.withOpacity(0.8),
                                    AppColors.accentSecondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_gas_station,
                                  size: 16,
                                  color: _fuelLevelPercent > 50
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Before Fueling',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: _fuelLevelPercent > 50
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Skip fuel estimate checkbox
                    InkWell(
                      onTap: () {
                        setState(() {
                          _skipFuelEstimate = !_skipFuelEstimate;
                        });
                      },
                      child: Row(
                        children: [
                          Checkbox(
                            value: _skipFuelEstimate,
                            onChanged: (value) {
                              setState(() {
                                _skipFuelEstimate = value ?? false;
                              });
                            },
                            activeColor: AppColors.textSecondary,
                          ),
                          Expanded(
                            child: Text(
                              'Skip fuel estimate - won\'t show consumption rate',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Driving cycle
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
                    'Driving Cycle',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDrivingCycleButton(
                          DrivingCycle.CITY,
                          Icons.location_city,
                          'City',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDrivingCycleButton(
                          DrivingCycle.HIGHWAY,
                          Icons.route,
                          'Highway',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDrivingCycleButton(
                          DrivingCycle.MIX,
                          Icons.merge,
                          'Mix',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Note
            _buildTextField(
              controller: _noteController,
              label: 'Note (optional)',
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFueling,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Update Fueling',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              suffixText: suffix,
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }

  Widget _buildDrivingCycleButton(
    DrivingCycle cycle,
    IconData icon,
    String label,
  ) {
    final isSelected = _drivingCycle == cycle;

    return InkWell(
      onTap: () {
        setState(() {
          _drivingCycle = cycle;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withOpacity(0.1)
              : AppColors.textSecondary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
