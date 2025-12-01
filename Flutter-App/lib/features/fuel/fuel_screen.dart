import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/fueling_service.dart';
import 'add_fueling_screen.dart';
import 'edit_fueling_screen.dart';

class FuelScreen extends StatefulWidget {
  final Vehicle vehicle;

  const FuelScreen({super.key, required this.vehicle});

  @override
  State<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends State<FuelScreen> {
  final FuelingService _fuelingService = FuelingService();
  List<Fueling> _fuelings = [];
  bool _isLoading = true;
  String? _error;
  bool _showingFullHistory = false;

  @override
  void initState() {
    super.initState();
    _loadFuelings();
  }

  Future<void> _loadFuelings({bool fullHistory = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _showingFullHistory = fullHistory;
    });

    try {
      final List<Fueling> fuelings;

      if (fullHistory) {
        // Load all fuelings (no date filter)
        fuelings = await _fuelingService.getFuelings(widget.vehicle.id);
      } else {
        // Get fuelings from the last 3 months
        final now = DateTime.now();
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        fuelings = await _fuelingService.getFuelingsInRange(
          widget.vehicle.id,
          fromDateTime: threeMonthsAgo,
        );
      }

      // Sort by date descending (newest first)
      fuelings.sort((a, b) => b.filledAt.compareTo(a.filledAt));

      setState(() {
        _fuelings = fuelings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Calculate consumption between two fuelings (L/100km)
  /// Returns a map with 'value' and 'isEstimated' flag
  /// Returns null if cannot be calculated
  Map<String, dynamic>? _calculateConsumption(int currentIndex) {
    if (currentIndex >= _fuelings.length - 1) {
      return null; // No previous fueling
    }

    final current = _fuelings[currentIndex];

    // Method 1: Full tank method (accurate)
    if (current.fullTank) {
      // Find the previous full tank fueling with SAME fuel type
      for (int i = currentIndex + 1; i < _fuelings.length; i++) {
        final previous = _fuelings[i];
        if (previous.fullTank && previous.fuel.name == current.fuel.name) {
          final distanceKm = current.odometerKm - previous.odometerKm;
          if (distanceKm <= 0) return null;

          final consumption = (current.volume / distanceKm) * 100;
          return {'value': consumption, 'isEstimated': false};
        }
      }
    }

    // Method 2: Estimated method using fuel levels
    // Requires: tank capacity and fuel level data
    final tankCapacity = widget.vehicle.tankCapacityL;
    if (tankCapacity == null || tankCapacity <= 0) {
      return null; // Need tank capacity for estimation
    }

    if (current.fuelLevelBefore == null || current.fuelLevelAfter == null) {
      return null; // Need fuel level data
    }

    // Find previous fueling with fuel level data and SAME fuel type
    for (int i = currentIndex + 1; i < _fuelings.length; i++) {
      final previous = _fuelings[i];

      if (previous.fuelLevelAfter != null &&
          previous.fuel.name == current.fuel.name) {
        final distanceKm = current.odometerKm - previous.odometerKm;
        if (distanceKm <= 0) return null;

        // Calculate fuel consumed
        // Starting fuel = previous.fuelLevelAfter% of tank
        // Ending fuel = current.fuelLevelBefore% of tank
        // Consumed = starting - ending + current.volume
        final startingFuel = (previous.fuelLevelAfter! / 100) * tankCapacity;
        final endingFuel = (current.fuelLevelBefore! / 100) * tankCapacity;
        final fuelConsumed = startingFuel - endingFuel + current.volume;

        if (fuelConsumed <= 0) return null;

        final consumption = (fuelConsumed / distanceKm) * 100;
        return {'value': consumption, 'isEstimated': true};
      }
    }

    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDrivingCycle(DrivingCycle? cycle) {
    if (cycle == null) return 'N/A';
    switch (cycle) {
      case DrivingCycle.CITY:
        return 'City';
      case DrivingCycle.HIGHWAY:
        return 'Highway';
      case DrivingCycle.MIX:
        return 'Mix';
    }
  }

  IconData _getDrivingCycleIcon(DrivingCycle? cycle) {
    if (cycle == null) return Icons.help_outline;
    switch (cycle) {
      case DrivingCycle.CITY:
        return Icons.location_city;
      case DrivingCycle.HIGHWAY:
        return Icons.route;
      case DrivingCycle.MIX:
        return Icons.merge;
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
        title: Column(
          children: [
            const Text('Fuel'),
            Text(
              widget.vehicle.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddFuelingScreen(vehicle: widget.vehicle),
            ),
          );

          if (result == true) {
            _loadFuelings();
          }
        },
        backgroundColor: AppColors.accentPrimary,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFuelings,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _fuelings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_gas_station_outlined,
                    size: 64,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showingFullHistory
                        ? 'No fuelings yet'
                        : 'No fuelings in last 3 months',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showingFullHistory
                        ? 'Tap + to add your first fueling'
                        : 'Tap + to add a fueling or view full history',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (!_showingFullHistory) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => _loadFuelings(fullHistory: true),
                      icon: const Icon(Icons.history),
                      label: const Text('View Full History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentSecondary,
                        side: BorderSide(color: AppColors.accentSecondary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadFuelings(fullHistory: _showingFullHistory),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _fuelings.length + 1, // +1 for history button
                itemBuilder: (context, index) {
                  // Show history button at the end
                  if (index == _fuelings.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _showingFullHistory
                            ? OutlinedButton.icon(
                                onPressed: () =>
                                    _loadFuelings(fullHistory: false),
                                icon: const Icon(Icons.calendar_month),
                                label: const Text('Show Last 3 Months'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accentSecondary,
                                  side: BorderSide(
                                    color: AppColors.accentSecondary,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () =>
                                    _loadFuelings(fullHistory: true),
                                icon: const Icon(Icons.history),
                                label: const Text('View Full History'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accentSecondary,
                                  side: BorderSide(
                                    color: AppColors.accentSecondary,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                      ),
                    );
                  }

                  final fueling = _fuelings[index];
                  final consumption = _calculateConsumption(index);

                  // First item has full details
                  if (index == 0) {
                    return _buildDetailedFuelingCard(fueling, consumption);
                  } else {
                    // Others have compact view
                    return _buildCompactFuelingCard(fueling, consumption);
                  }
                },
              ),
            ),
    );
  }

  Widget _buildDetailedFuelingCard(
    Fueling fueling,
    Map<String, dynamic>? consumption,
  ) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                EditFuelingScreen(vehicle: widget.vehicle, fueling: fueling),
          ),
        );

        if (result == true) {
          _loadFuelings(fullHistory: _showingFullHistory);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            // Header row with date and fuel type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(fueling.filledAt),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    fueling.fuel.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price per unit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fueling.pricePerUnit.toStringAsFixed(2)} PLN/L',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total price',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fueling.totalPrice.toStringAsFixed(2)} PLN',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Volume and odometer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  icon: Icons.local_gas_station,
                  label: 'Volume',
                  value: '${fueling.volume.toStringAsFixed(2)} L',
                ),
                SizedBox(width: 10),
                _buildInfoChip(
                  icon: Icons.speed,
                  label: 'Odometer',
                  value: '${fueling.odometerKm.toStringAsFixed(1)} km',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Driving cycle and full tank
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  icon: _getDrivingCycleIcon(fueling.drivingCycle),
                  label: 'Driving cycle',
                  value: _formatDrivingCycle(fueling.drivingCycle),
                ),
                SizedBox(width: 10),

                if (fueling.fullTank)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Full tank',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Consumption
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: consumption != null
                    ? AppColors.accentSecondary.withOpacity(0.1)
                    : AppColors.textMuted.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    consumption != null
                        ? (consumption['isEstimated']
                              ? Icons.show_chart
                              : Icons.analytics_outlined)
                        : Icons.analytics_outlined,
                    color: consumption != null
                        ? AppColors.accentSecondary
                        : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    consumption != null
                        ? '${consumption['isEstimated'] ? '~' : ''}${(consumption['value'] as double).toStringAsFixed(2)} L/100km'
                        : '-.-- L/100km',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: consumption != null
                          ? AppColors.accentSecondary
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (consumption != null && consumption['isEstimated'])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Tooltip(
                        message: 'Estimated based on fuel level',
                        child: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.accentSecondary.withOpacity(0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Note
            if (fueling.note != null && fueling.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fueling.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFuelingCard(
    Fueling fueling,
    Map<String, dynamic>? consumption,
  ) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                EditFuelingScreen(vehicle: widget.vehicle, fueling: fueling),
          ),
        );

        if (result == true) {
          _loadFuelings(fullHistory: _showingFullHistory);
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
        child: Column(
          children: [
            Row(
              children: [
                // Date
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(fueling.filledAt),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fueling.fuel.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Total price
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${fueling.totalPrice.toStringAsFixed(2)} PLN',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fueling.volume.toStringAsFixed(1)} L',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Consumption
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (consumption != null && consumption['isEstimated'])
                            Text(
                              '~',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentSecondary,
                                  ),
                            ),
                          Text(
                            consumption != null
                                ? (consumption['value'] as double)
                                      .toStringAsFixed(2)
                                : '-.--',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: consumption != null
                                      ? AppColors.accentSecondary
                                      : AppColors.textMuted,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'L/100km',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
