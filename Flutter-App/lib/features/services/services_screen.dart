import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/service_service.dart';
import '../../core/api/meta_service.dart';
import 'add_service_screen.dart';

class ServicesScreen extends StatefulWidget {
  final Vehicle vehicle;

  const ServicesScreen({super.key, required this.vehicle});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final ServiceService _serviceService = ServiceService();
  final MetaService _metaService = MetaService();
  List<Service> _services = [];
  Map<String, ServiceTypeEnum> _serviceTypesMap = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load service types from cache
      final serviceTypes = await _metaService.getServiceTypes();
      _serviceTypesMap = {for (var type in serviceTypes) type.value: type};

      // Load services
      final services = await _serviceService.getVehicleServices(
        widget.vehicle.id,
      );
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load services: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadServices() async {
    try {
      final services = await _serviceService.getVehicleServices(
        widget.vehicle.id,
      );
      setState(() {
        _services = services;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load services: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteService(String serviceId) async {
    try {
      await _serviceService.deleteService(serviceId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service deleted successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadServices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete service: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showDeleteConfirmation(String serviceId) {
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
              _deleteService(serviceId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getServiceTypeLabel(String typeValue) {
    return _serviceTypesMap[typeValue]?.label ?? typeValue;
  }

  IconData _getServiceTypeIcon(String typeValue) {
    // Map service type values to icons
    final iconMap = {
      'INSPECTION': Icons.assignment,
      'OIL_CHANGE': Icons.oil_barrel,
      'FILTERS': Icons.filter_alt,
      'BRAKES': Icons.settings_backup_restore,
      'TIRES': Icons.tire_repair,
      'BATTERY': Icons.battery_charging_full,
      'ENGINE': Icons.settings,
      'TRANSMISSION': Icons.settings_applications,
      'SUSPENSION': Icons.settings_input_component,
      'OTHER': Icons.build,
    };
    return iconMap[typeValue] ?? Icons.build;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Service History',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadServices,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _services.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.build_circle,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No service records yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first service record',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadServices,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  return Card(
                    color: AppColors.bgSurface,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddServiceScreen(
                              vehicle: widget.vehicle,
                              service: service,
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadServices();
                        }
                      },
                      onLongPress: () => _showDeleteConfirmation(service.id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getServiceTypeIcon(service.serviceType),
                                  color: AppColors.accentPrimary,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getServiceTypeLabel(
                                          service.serviceType,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(service.serviceDate),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (service.totalCost != null)
                                  Text(
                                    '\$${service.totalCost!.toStringAsFixed(2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.accentSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                              ],
                            ),
                            if (service.odometerKm != null ||
                                service.reference != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (service.odometerKm != null) ...[
                                    Icon(
                                      Icons.speed,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${service.odometerKm!.toStringAsFixed(0)} km',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                  if (service.odometerKm != null &&
                                      service.reference != null)
                                    const SizedBox(width: 16),
                                  if (service.reference != null) ...[
                                    Icon(
                                      Icons.receipt,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      service.reference!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            if (service.note != null &&
                                service.note!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                service.note!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentPrimary,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddServiceScreen(vehicle: widget.vehicle),
            ),
          );
          if (result == true) {
            _loadServices();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
