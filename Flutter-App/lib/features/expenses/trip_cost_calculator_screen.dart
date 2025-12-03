import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/fueling_service.dart';
import '../../core/api/meta_service.dart';

class TripCostCalculatorScreen extends StatefulWidget {
  final Vehicle vehicle;

  const TripCostCalculatorScreen({super.key, required this.vehicle});

  @override
  State<TripCostCalculatorScreen> createState() =>
      _TripCostCalculatorScreenState();
}

class _TripCostCalculatorScreenState extends State<TripCostCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final FuelingService _fuelingService = FuelingService();
  final MetaService _metaService = MetaService();

  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _fuelPriceController = TextEditingController();

  String? _selectedDrivingCycle;
  String? _selectedFuelType;
  List<EnumItem> _drivingCycles = [];
  List<FuelTypeEnum> _fuelTypes = [];
  bool _isLoadingEnums = true;
  bool _isCalculating = false;

  double? _avgConsumption;
  double? _calculatedCost;
  double? _fuelNeeded;

  @override
  void initState() {
    super.initState();
    _loadEnums();
  }

  Future<void> _loadEnums() async {
    try {
      final cycles = await _metaService.getDrivingCycles();
      final fuels = await _metaService.getFuelTypes();

      setState(() {
        _drivingCycles = cycles;
        _fuelTypes = fuels;
        _isLoadingEnums = false;

        // Set defaults
        if (_drivingCycles.isNotEmpty) {
          _selectedDrivingCycle = _drivingCycles.first.value;
        }
        if (_fuelTypes.isNotEmpty) {
          _selectedFuelType = _fuelTypes.first.value;
        }
      });
    } catch (e) {
      setState(() => _isLoadingEnums = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load options: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _fuelPriceController.dispose();
    super.dispose();
  }

  Future<void> _calculateCost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCalculating = true;
      _avgConsumption = null;
      _calculatedCost = null;
      _fuelNeeded = null;
    });

    try {
      final distance = double.parse(_distanceController.text);
      final fuelPrice = double.parse(_fuelPriceController.text);

      // Get fueling records to calculate average consumption
      final fuelings = await _fuelingService.getFuelings(widget.vehicle.id);

      // Filter by driving cycle and fuel type if applicable
      final filteredFuelings = fuelings.where((f) {
        if (_selectedDrivingCycle != null &&
            f.drivingCycle != null &&
            f.drivingCycle != _selectedDrivingCycle) {
          return false;
        }
        if (widget.vehicle.dualTank &&
            _selectedFuelType != null &&
            f.fuel != _selectedFuelType) {
          return false;
        }
        return true;
      }).toList();

      if (filteredFuelings.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Not enough fueling data. Please add at least 2 fuelings with the selected options.',
              ),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isCalculating = false);
        return;
      }

      // Sort by odometer (newest first)
      filteredFuelings.sort((a, b) => b.odometerKm.compareTo(a.odometerKm));

      double totalConsumption = 0;
      int consumptionCount = 0;
      final tankCapacity = widget.vehicle.tankCapacityL;

      // Calculate consumption for each fueling
      for (int i = 0; i < filteredFuelings.length - 1; i++) {
        final current = filteredFuelings[i];

        // Method 1: Full tank method (accurate)
        if (current.fullTank) {
          // Find the previous full tank fueling with SAME fuel type
          for (int j = i + 1; j < filteredFuelings.length; j++) {
            final previous = filteredFuelings[j];
            if (previous.fullTank && previous.fuel == current.fuel) {
              final distanceKm = current.odometerKm - previous.odometerKm;
              if (distanceKm > 0 && distanceKm < 2000) {
                // Reasonable distance
                final consumption = (current.volume / distanceKm) * 100;
                if (consumption > 0 && consumption < 50) {
                  // Reasonable consumption
                  totalConsumption += consumption;
                  consumptionCount++;
                  break; // Found match, move to next fueling
                }
              }
            }
          }
        }
        // Method 2: Estimated method using fuel levels
        else if (tankCapacity != null && tankCapacity > 0) {
          // Try to estimate using available fuel level data
          // Check if current has fuelLevelBefore - we can use it with any previous fueling
          if (current.fuelLevelBefore != null) {
            // Find the nearest previous fueling with SAME fuel type
            for (int j = i + 1; j < filteredFuelings.length; j++) {
              final previous = filteredFuelings[j];

              if (previous.fuel == current.fuel) {
                final distanceKm = current.odometerKm - previous.odometerKm;
                if (distanceKm > 0 && distanceKm < 2000) {
                  double? fuelConsumed;

                  // Case 1: Previous has fuelLevelAfter, current has fuelLevelBefore
                  if (previous.fuelLevelAfter != null) {
                    final startingFuel =
                        (previous.fuelLevelAfter! / 100) * tankCapacity;
                    final endingFuel =
                        (current.fuelLevelBefore! / 100) * tankCapacity;
                    fuelConsumed = startingFuel - endingFuel;
                  }
                  // Case 2: Previous is full tank, current has fuelLevelBefore
                  else if (previous.fullTank) {
                    final startingFuel = tankCapacity; // Full tank
                    final endingFuel =
                        (current.fuelLevelBefore! / 100) * tankCapacity;
                    fuelConsumed = startingFuel - endingFuel;
                  }

                  if (fuelConsumed != null &&
                      fuelConsumed > 0 &&
                      fuelConsumed < tankCapacity * 3) {
                    final consumption = (fuelConsumed / distanceKm) * 100;
                    if (consumption > 0 && consumption < 50) {
                      totalConsumption += consumption;
                      consumptionCount++;
                      break;
                    }
                  } else {
                    continue; // Try next previous
                  }
                }
              }
            }
          }
          // Fallback: only fuelLevelAfter available on current
          else if (current.fuelLevelAfter != null) {
            for (int j = i + 1; j < filteredFuelings.length; j++) {
              final previous = filteredFuelings[j];

              if (previous.fuelLevelAfter != null &&
                  previous.fuel == current.fuel) {
                final distanceKm = current.odometerKm - previous.odometerKm;
                if (distanceKm > 0 && distanceKm < 2000) {
                  final previousFuel =
                      (previous.fuelLevelAfter! / 100) * tankCapacity;
                  final currentFuel =
                      (current.fuelLevelAfter! / 100) * tankCapacity;
                  final fuelConsumed =
                      previousFuel - currentFuel + current.volume;

                  if (fuelConsumed > 0 && fuelConsumed < tankCapacity * 3) {
                    final consumption = (fuelConsumed / distanceKm) * 100;
                    if (consumption > 0 && consumption < 50) {
                      totalConsumption += consumption;
                      consumptionCount++;
                      break;
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (consumptionCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tankCapacity == null || tankCapacity <= 0
                    ? 'Unable to calculate consumption. Please set your vehicle\'s tank capacity in settings or add full tank fuelings.'
                    : 'Unable to calculate consumption. Please ensure you have either:\n- Full tank fuelings, or\n- Fuelings with fuel level data (before/after %)',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isCalculating = false);
        return;
      }

      final avgConsumption = totalConsumption / consumptionCount;
      final fuelNeeded = (avgConsumption * distance) / 100;
      final cost = fuelNeeded * fuelPrice;

      setState(() {
        _avgConsumption = avgConsumption;
        _fuelNeeded = fuelNeeded;
        _calculatedCost = cost;
        _isCalculating = false;
      });
    } catch (e) {
      setState(() => _isCalculating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calculation failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _distanceController.clear();
      _fuelPriceController.clear();
      _avgConsumption = null;
      _calculatedCost = null;
      _fuelNeeded = null;
      if (_drivingCycles.isNotEmpty) {
        _selectedDrivingCycle = _drivingCycles.first.value;
      }
      if (_fuelTypes.isNotEmpty) {
        _selectedFuelType = _fuelTypes.first.value;
      }
    });
  }

  String _getDrivingCycleLabel(String value) {
    final cycle = _drivingCycles.firstWhere(
      (c) => c.value == value,
      orElse: () => EnumItem(value: value, label: value),
    );
    return cycle.label;
  }

  String _getFuelTypeLabel(String value) {
    final fuel = _fuelTypes.firstWhere(
      (f) => f.value == value,
      orElse: () => FuelTypeEnum(value: value, label: value),
    );
    return fuel.label;
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
            const Text('Trip Cost Calculator'),
            Text(
              widget.vehicle.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: _isLoadingEnums
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.accentPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Calculate estimated fuel cost for your trip based on historical consumption data.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Distance field
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
                            'Distance (km)',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _distanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g., 350',
                              prefixIcon: Icon(
                                Icons.straighten,
                                color: AppColors.accentPrimary,
                              ),
                              suffixText: 'km',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: AppColors.bgMain,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter distance';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              if (double.parse(value) <= 0) {
                                return 'Distance must be greater than 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fuel price field
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
                            'Fuel Price per Liter (PLN)',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _fuelPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g., 6.50',
                              prefixIcon: Icon(
                                Icons.local_gas_station,
                                color: AppColors.accentPrimary,
                              ),
                              suffixText: 'PLN/L',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: AppColors.bgMain,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter fuel price';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              if (double.parse(value) <= 0) {
                                return 'Price must be greater than 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Driving cycle dropdown
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedDrivingCycle,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: AppColors.bgMain,
                              prefixIcon: Icon(
                                Icons.route,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                            dropdownColor: AppColors.bgSurface,
                            items: _drivingCycles.map((cycle) {
                              return DropdownMenuItem<String>(
                                value: cycle.value,
                                child: Text(cycle.label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedDrivingCycle = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fuel type dropdown (only if dual tank)
                    if (widget.vehicle.dualTank)
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
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedFuelType,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: AppColors.bgMain,
                                prefixIcon: Icon(
                                  Icons.oil_barrel,
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                              dropdownColor: AppColors.bgSurface,
                              items: _fuelTypes.map((fuel) {
                                return DropdownMenuItem<String>(
                                  value: fuel.value,
                                  child: Text(fuel.label),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedFuelType = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    if (widget.vehicle.dualTank) const SizedBox(height: 24),

                    // Calculate button
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isCalculating ? null : _calculateCost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isCalculating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.calculate),
                            label: Text(
                              'Calculate Cost',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _reset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.bgSurface,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.refresh),
                        ),
                      ],
                    ),

                    // Results
                    if (_calculatedCost != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.accentPrimary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Trip Cost Estimate',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildResultRow(
                              'Average Consumption',
                              '${_avgConsumption!.toStringAsFixed(2)} L/100km',
                              Icons.speed,
                            ),
                            const SizedBox(height: 12),
                            _buildResultRow(
                              'Fuel Needed',
                              '${_fuelNeeded!.toStringAsFixed(2)} L',
                              Icons.local_gas_station,
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 12),
                            _buildResultRow(
                              'Estimated Cost',
                              '${_calculatedCost!.toStringAsFixed(2)} PLN',
                              Icons.attach_money,
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value,
    IconData icon, {
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: isTotal ? AppColors.accentPrimary : AppColors.textSecondary,
          size: isTotal ? 24 : 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isTotal ? AppColors.accentPrimary : AppColors.textPrimary,
            fontSize: isTotal ? 20 : 16,
          ),
        ),
      ],
    );
  }
}
