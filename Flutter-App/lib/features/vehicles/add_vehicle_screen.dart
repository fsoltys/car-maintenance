import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/meta_service.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleService = VehicleService();
  final _metaService = MetaService();
  bool _isLoading = false;
  bool _isDualTank = false;
  List<FuelTypeEnum> _availableFuels = [];

  // Required field
  final _nameController = TextEditingController();

  // Optional fields - basic info
  final _modelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vinController = TextEditingController();
  final _plateController = TextEditingController();
  final _policyNumberController = TextEditingController();

  // Optional fields - technical
  final _productionYearController = TextEditingController();
  final _tankCapacityController = TextEditingController();
  final _secondaryTankCapacityController = TextEditingController();
  final _batteryCapacityController = TextEditingController();
  final _initialOdometerController = TextEditingController();

  // Optional fields - purchase
  final _purchasePriceController = TextEditingController();
  DateTime? _purchaseDate;
  DateTime? _lastInspectionDate;

  // Fuel configuration
  final List<VehicleFuelConfig> _selectedFuels = [];
  String? _primaryFuel;

  @override
  void initState() {
    super.initState();
    _loadFuelTypes();
  }

  Future<void> _loadFuelTypes() async {
    try {
      final fuels = await _metaService.getFuelTypes();
      setState(() {
        _availableFuels = fuels;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load fuel types: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _descriptionController.dispose();
    _vinController.dispose();
    _plateController.dispose();
    _policyNumberController.dispose();
    _productionYearController.dispose();
    _tankCapacityController.dispose();
    _secondaryTankCapacityController.dispose();
    _batteryCapacityController.dispose();
    _initialOdometerController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vehicle = VehicleCreate(
        name: _nameController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        vin: _vinController.text.trim().isEmpty
            ? null
            : _vinController.text.trim(),
        plate: _plateController.text.trim().isEmpty
            ? null
            : _plateController.text.trim(),
        policyNumber: _policyNumberController.text.trim().isEmpty
            ? null
            : _policyNumberController.text.trim(),
        productionYear: _productionYearController.text.trim().isEmpty
            ? null
            : int.tryParse(_productionYearController.text.trim()),
        dualTank: _isDualTank,
        tankCapacityL: _tankCapacityController.text.trim().isEmpty
            ? null
            : double.tryParse(_tankCapacityController.text.trim()),
        secondaryTankCapacity:
            _secondaryTankCapacityController.text.trim().isEmpty
            ? null
            : double.tryParse(_secondaryTankCapacityController.text.trim()),
        batteryCapacityKwh: _batteryCapacityController.text.trim().isEmpty
            ? null
            : double.tryParse(_batteryCapacityController.text.trim()),
        initialOdometerKm: _initialOdometerController.text.trim().isEmpty
            ? null
            : double.tryParse(_initialOdometerController.text.trim()),
        purchasePrice: _purchasePriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_purchasePriceController.text.trim()),
        purchaseDate: _purchaseDate,
        lastInspectionDate: _lastInspectionDate,
      );

      final createdVehicle = await _vehicleService.createVehicle(vehicle);

      // Add fuel configuration if any fuels selected
      if (_selectedFuels.isNotEmpty && mounted) {
        try {
          await _vehicleService.addVehicleFuels(
            createdVehicle.id,
            _selectedFuels,
          );
        } catch (fuelError) {
          // If fuel configuration fails, delete the vehicle to maintain consistency
          try {
            await _vehicleService.deleteVehicle(createdVehicle.id);
          } catch (deleteError) {
            // Log delete error but throw the original fuel error
            debugPrint('Failed to rollback vehicle creation: $deleteError');
          }
          // Re-throw the original error
          rethrow;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add vehicle: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isPurchaseDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
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
      setState(() {
        if (isPurchaseDate) {
          _purchaseDate = picked;
        } else {
          _lastInspectionDate = picked;
        }
      });
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
          'Add Vehicle',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      Text(
                        'Basic Information',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          hintText: 'e.g., My Car',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          if (value.length > 120) {
                            return 'Name must be less than 120 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          hintText: 'e.g., Volvo S40',
                        ),
                        validator: (value) {
                          if (value != null && value.length > 120) {
                            return 'Model must be less than 120 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Optional notes about the vehicle',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Vehicle Details Section
                      Text(
                        'Vehicle Details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _vinController,
                        decoration: const InputDecoration(
                          labelText: 'VIN',
                          hintText: '17-character identification number',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              value.length > 32) {
                            return 'VIN must be less than 32 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _plateController,
                        decoration: const InputDecoration(
                          labelText: 'License Plate',
                          hintText: 'e.g., ABC1234',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value != null && value.length > 32) {
                            return 'Plate must be less than 32 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _policyNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Insurance Policy Number',
                          hintText: 'Optional',
                        ),
                        validator: (value) {
                          if (value != null && value.length > 64) {
                            return 'Policy number must be less than 64 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _productionYearController,
                        decoration: const InputDecoration(
                          labelText: 'Production Year',
                          hintText: 'e.g., 2015',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final year = int.tryParse(value);
                            if (year == null) {
                              return 'Enter a valid year';
                            }
                            if (year < 1900 || year > DateTime.now().year + 1) {
                              return 'Enter a realistic year';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Fuel Configuration Section
                      Text(
                        'Fuel Configuration',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      // Dual Tank Switch
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dual Tank System',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          Switch(
                            value: _isDualTank,
                            onChanged: (value) {
                              setState(() {
                                _isDualTank = value;
                                // If switching to single tank and multiple fuels selected, keep only primary
                                if (!value && _selectedFuels.length > 1) {
                                  if (_primaryFuel != null) {
                                    _selectedFuels.removeWhere(
                                      (f) => f.fuel != _primaryFuel,
                                    );
                                  } else {
                                    // Keep first fuel as primary
                                    final firstFuel = _selectedFuels.first.fuel;
                                    _selectedFuels.clear();
                                    _selectedFuels.add(
                                      VehicleFuelConfig(
                                        fuel: firstFuel,
                                        isPrimary: true,
                                      ),
                                    );
                                    _primaryFuel = firstFuel;
                                  }
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isDualTank
                            ? 'Select up to 2 fuel types for dual tank system'
                            : 'Select a single fuel type',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_availableFuels.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        ..._availableFuels.map((fuelType) {
                          final isSelected = _selectedFuels.any(
                            (f) => f.fuel == fuelType.value,
                          );
                          final isPrimary = _primaryFuel == fuelType.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Material(
                              color: isSelected
                                  ? AppColors.accentPrimary.withOpacity(0.1)
                                  : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedFuels.removeWhere(
                                        (f) => f.fuel == fuelType.value,
                                      );
                                      if (_primaryFuel == fuelType.value) {
                                        _primaryFuel = null;
                                      }
                                    } else {
                                      // If not dual tank and a fuel is already selected, replace it
                                      if (!_isDualTank &&
                                          _selectedFuels.isNotEmpty) {
                                        _selectedFuels.clear();
                                        _primaryFuel = null;
                                      }
                                      // If dual tank, limit to 2 fuels
                                      if (_isDualTank &&
                                          _selectedFuels.length >= 2) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Maximum 2 fuels for dual tank system',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                        return;
                                      }
                                      _selectedFuels.add(
                                        VehicleFuelConfig(
                                          fuel: fuelType.value,
                                          isPrimary: _selectedFuels
                                              .isEmpty, // First fuel is primary
                                        ),
                                      );
                                      if (_selectedFuels.length == 1) {
                                        _primaryFuel = fuelType.value;
                                      }
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentPrimary
                                          : AppColors.textSecondary.withOpacity(
                                              0.2,
                                            ),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? AppColors.accentPrimary
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          fuelType.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                        ),
                                      ),
                                      if (isSelected)
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isPrimary) {
                                                _primaryFuel = null;
                                                final index = _selectedFuels
                                                    .indexWhere(
                                                      (f) =>
                                                          f.fuel ==
                                                          fuelType.value,
                                                    );
                                                if (index != -1) {
                                                  _selectedFuels[index] =
                                                      VehicleFuelConfig(
                                                        fuel: fuelType.value,
                                                        isPrimary: false,
                                                      );
                                                }
                                              } else {
                                                _primaryFuel = fuelType.value;
                                                // Update all fuels to set only this one as primary
                                                for (
                                                  int i = 0;
                                                  i < _selectedFuels.length;
                                                  i++
                                                ) {
                                                  _selectedFuels[i] =
                                                      VehicleFuelConfig(
                                                        fuel: _selectedFuels[i]
                                                            .fuel,
                                                        isPrimary:
                                                            _selectedFuels[i]
                                                                .fuel ==
                                                            fuelType.value,
                                                      );
                                                }
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isPrimary
                                                  ? AppColors.accentPrimary
                                                  : AppColors.bgMain,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'PRIMARY',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: isPrimary
                                                        ? AppColors.textPrimary
                                                        : AppColors
                                                              .textSecondary,
                                                  ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 24),

                      // Technical Specifications Section
                      Text(
                        'Technical Specifications',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      // Tank Capacity - show only if non-EV fuel selected
                      if (_selectedFuels.any((f) => f.fuel != 'EV'))
                        Column(
                          children: [
                            TextFormField(
                              controller: _tankCapacityController,
                              decoration: InputDecoration(
                                labelText:
                                    (_isDualTank &&
                                        _selectedFuels.length == 2 &&
                                        !_selectedFuels.any(
                                          (f) => f.fuel == 'EV',
                                        )
                                    ? 'Primary Tank Capacity (L)'
                                    : 'Tank Capacity (L)') + ' *',
                                hintText: 'e.g., 50.0',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Tank capacity is required';
                                }
                                final capacity = double.tryParse(value);
                                if (capacity == null || capacity <= 0) {
                                  return 'Enter a valid capacity';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),

                      // Secondary Tank Capacity - show only if dual tank with two non-EV fuels
                      if (_isDualTank &&
                          _selectedFuels.length == 2 &&
                          !_selectedFuels.any((f) => f.fuel == 'EV'))
                        Column(
                          children: [
                            TextFormField(
                              controller: _secondaryTankCapacityController,
                              decoration: const InputDecoration(
                                labelText: 'Secondary Tank Capacity (L) *',
                                hintText: 'e.g., 40.0',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Secondary tank capacity is required';
                                }
                                final capacity = double.tryParse(value);
                                if (capacity == null || capacity <= 0) {
                                  return 'Enter a valid capacity';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),

                      // Battery Capacity - show if EV fuel selected
                      if (_selectedFuels.any((f) => f.fuel == 'EV'))
                        Column(
                          children: [
                            TextFormField(
                              controller: _batteryCapacityController,
                              decoration: const InputDecoration(
                                labelText: 'Battery Capacity (kWh) *',
                                hintText: 'For electric vehicles',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Battery capacity is required for EVs';
                                }
                                final capacity = double.tryParse(value);
                                if (capacity == null || capacity <= 0) {
                                  return 'Enter a valid capacity';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),

                      // Current Odometer - always visible
                      TextFormField(
                        controller: _initialOdometerController,
                        decoration: const InputDecoration(
                          labelText: 'Current Odometer (km) *',
                          hintText: 'e.g., 50000',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Initial odometer reading is required';
                          }
                          final odometer = double.tryParse(value);
                          if (odometer == null || odometer < 0) {
                            return 'Enter a valid odometer reading';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Purchase Information Section
                      Text(
                        'Purchase Information',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _purchasePriceController,
                        decoration: const InputDecoration(
                          labelText: 'Purchase Price',
                          hintText: 'e.g., 15000',
                          suffixText: ' PLN',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final price = double.tryParse(value);
                            if (price == null || price < 0) {
                              return 'Enter a valid price';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Purchase Date
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Purchase Date',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _purchaseDate == null
                                ? 'Select date'
                                : '${_purchaseDate!.day.toString().padLeft(2, '0')}/${_purchaseDate!.month.toString().padLeft(2, '0')}/${_purchaseDate!.year}',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: _purchaseDate == null
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Last Inspection Date
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Last Inspection Date',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _lastInspectionDate == null
                                ? 'Select date'
                                : '${_lastInspectionDate!.day.toString().padLeft(2, '0')}/${_lastInspectionDate!.month.toString().padLeft(2, '0')}/${_lastInspectionDate!.year}',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: _lastInspectionDate == null
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Button
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bgMain.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : const Text(
                            'ADD VEHICLE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
