import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to vehicle settings
            },
          ),
        ],
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
                      _buildCarouselCard(
                        title: 'Usage Overview',
                        icon: Icons.speed,
                        color: AppColors.accentSecondary,
                      ),
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
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to detailed overview
                  },
                  child: Text(
                    'Show all',
                    style: TextStyle(
                      color: AppColors.accentSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
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
                        // TODO: Navigate to fuel module
                      },
                    ),
                    _buildModuleButton(
                      icon: Icons.build,
                      label: 'Service',
                      onTap: () {
                        // TODO: Navigate to service module
                      },
                    ),
                    _buildModuleButton(
                      icon: Icons.error_outline,
                      label: 'Issues',
                      onTap: () {
                        // TODO: Navigate to issues module
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildModuleButton(
                      icon: Icons.description_outlined,
                      label: 'Documents',
                      onTap: () {
                        // TODO: Navigate to documents module
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
                        // TODO: Navigate to reminders module
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
