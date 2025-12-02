import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/fueling_service.dart';
import '../../core/api/odometer_service.dart';
import '../fuel/fuel_screen.dart';
import '../odometer/odometer_entries_screen.dart';
import '../issues/issues_screen.dart';
import '../services/services_screen.dart';
import '../reminders/reminders_screen.dart';

class VehicleDashboardScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDashboardScreen({super.key, required this.vehicle});

  @override
  State<VehicleDashboardScreen> createState() => _VehicleDashboardScreenState();
}

class _VehicleDashboardScreenState extends State<VehicleDashboardScreen> {
  int _currentCarouselIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            Text(
              widget.vehicle.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.vehicle.model != null)
              Text(
                widget.vehicle.model!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Main carousel section
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Carousel
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentCarouselIndex = index;
                      });
                    },
                    children: [
                      _buildUsageOverviewCard(),
                      _buildCarouselCard(
                        title: 'Cost Summary',
                        icon: Icons.attach_money,
                        color: AppColors.accentPrimary,
                      ),
                      _buildCarouselCard(
                        title: 'Service Reminders',
                        icon: Icons.build_outlined,
                        color: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Carousel indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentCarouselIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentCarouselIndex == index
                            ? AppColors.accentSecondary
                            : AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // "Show all" button
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Bottom navigation buttons
          Container(
            color: AppColors.bgSurface,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildModuleButton(
                      icon: Icons.local_gas_station,
                      label: 'Fuel',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                FuelScreen(vehicle: widget.vehicle),
                          ),
                        );
                      },
                    ),
                    _buildModuleButton(
                      icon: Icons.build,
                      label: 'Service',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ServicesScreen(vehicle: widget.vehicle),
                          ),
                        );
                      },
                    ),
                    _buildModuleButton(
                      icon: Icons.error_outline,
                      label: 'Issues',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                IssuesScreen(vehicle: widget.vehicle),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildModuleButton(
                      icon: Icons.speed_outlined,
                      label: 'Odometer History',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                OdometerEntriesScreen(vehicle: widget.vehicle),
                          ),
                        );
                      },
                    ),
                    _buildModuleButton(
                      icon: Icons.attach_money,
                      label: 'Expenses',
                      onTap: () {
                        // TODO: Navigate to expenses module
                      },
                    ),
                    _buildModuleButton(
                      icon: Icons.notifications_outlined,
                      label: 'Reminders',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                RemindersScreen(vehicle: widget.vehicle),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageOverviewCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUsageOverviewData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data ?? {};
        final kmDriven = data['kmDriven'] ?? 0.0;
        final fuelingsCount = data['fuelingsCount'] ?? 0;
        final totalFuel = data['totalFuel'] ?? 0.0;
        final avgConsumption = data['avgConsumption'];
        final fuelsByType = data['fuelsByType'] as Map<String, double>? ?? {};
        final consumptionByType =
            data['consumptionByType'] as Map<String, double>? ?? {};

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.textSecondary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accentSecondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_filled_outlined,
                  size: 48,
                  color: AppColors.accentSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Usage Overview',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Last 3 months statistics',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              // Kilometers driven
              _buildStatRow(
                Icons.route,
                'Kilometers Driven',
                '${kmDriven.toStringAsFixed(0)} km',
              ),
              const SizedBox(height: 12),
              // Fuelings count
              _buildStatRow(
                Icons.local_gas_station,
                'Fuelings',
                '$fuelingsCount',
              ),
              const SizedBox(height: 12),
              // Total fuel
              _buildStatRow(
                Icons.water_drop_outlined,
                'Total Fuel',
                '${totalFuel.toStringAsFixed(1)} L',
              ),
              // Show fuel breakdown if multiple fuel types
              if (fuelsByType.length > 1) ...[
                const SizedBox(height: 8),
                ...fuelsByType.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(1)} L',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              // Average consumption
              if (fuelsByType.length > 1 && consumptionByType.isNotEmpty) ...[
                // Multi-fuel: show consumption per fuel type
                ...consumptionByType.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildStatRow(
                      Icons.analytics_outlined,
                      '${entry.key} Avg',
                      '${entry.value.toStringAsFixed(2)} L/100km',
                    ),
                  );
                }),
              ] else ...[
                // Single fuel: show overall consumption or placeholder
                _buildStatRow(
                  Icons.analytics_outlined,
                  'Avg Consumption',
                  avgConsumption != null
                      ? '${avgConsumption.toStringAsFixed(2)} L/100km'
                      : '-.--',
                  valueColor: avgConsumption != null
                      ? AppColors.accentSecondary
                      : AppColors.textMuted,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accentSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.accentSecondary,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _loadUsageOverviewData() async {
    try {
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

      // Load odometer data for km driven calculation
      final odometerService = OdometerService();
      final odometerData = await odometerService.getOdometerGraph(
        widget.vehicle.id,
        fromDate: threeMonthsAgo,
      );

      double kmDriven = 0.0;
      if (odometerData.isNotEmpty) {
        odometerData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final firstOdometer = odometerData.first.odometerKm;
        final lastOdometer = odometerData.last.odometerKm;
        kmDriven = lastOdometer - firstOdometer;
      }

      // Load fuelings data
      final fuelingService = FuelingService();
      final fuelings = await fuelingService.getFuelingsInRange(
        widget.vehicle.id,
        fromDateTime: threeMonthsAgo,
      );

      int fuelingsCount = fuelings.length;
      double totalFuel = 0.0;
      Map<String, double> fuelsByType = {};
      Map<String, double> consumptionByType = {};

      for (var fueling in fuelings) {
        totalFuel += fueling.volume;
        final fuelName = fueling.fuel;
        fuelsByType[fuelName] = (fuelsByType[fuelName] ?? 0.0) + fueling.volume;
      }

      // Calculate average consumption per fuel type (L/100km)
      if (kmDriven > 0 && fuelsByType.length > 1) {
        // Multi-fuel vehicle - calculate consumption per fuel type
        for (var entry in fuelsByType.entries) {
          final fuelType = entry.key;
          final fuelAmount = entry.value;
          if (fuelAmount > 0) {
            // For multi-fuel, we can't accurately determine km driven per fuel
            // So we calculate proportional consumption based on fuel usage
            final consumption = (fuelAmount / kmDriven) * 100;
            consumptionByType[fuelType] = consumption;
          }
        }
      }

      // Calculate overall average consumption (L/100km)
      double? avgConsumption;
      if (kmDriven > 0 && totalFuel > 0) {
        avgConsumption = (totalFuel / kmDriven) * 100;
      }

      return {
        'kmDriven': kmDriven,
        'fuelingsCount': fuelingsCount,
        'totalFuel': totalFuel,
        'avgConsumption': avgConsumption,
        'fuelsByType': fuelsByType,
        'consumptionByType': consumptionByType,
      };
    } catch (e, stackTrace) {
      print('Error loading usage overview: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }

  Widget _buildCarouselCard({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          // Placeholder content
          Text(
            'Track your usage, costs and\nupcoming service reminders',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          // Placeholder stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPlaceholderStat('--', 'Item 1'),
              _buildPlaceholderStat('--', 'Item 2'),
              _buildPlaceholderStat('--', 'Item 3'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderStat(String value, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildModuleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: const Color(0xFF4A3A5A),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.accentPrimary, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
