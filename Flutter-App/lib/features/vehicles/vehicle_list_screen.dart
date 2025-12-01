import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/auth/auth_storage.dart';
import 'widgets/vehicle_card.dart';
import 'add_vehicle_screen.dart';
import 'edit_vehicle_screen.dart';
import 'vehicle_role_settings_screen.dart';
import '../profile/profile_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final VehicleService _vehicleService = VehicleService();
  final AuthStorage _authStorage = AuthStorage();
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _displayName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadVehicles();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await _authStorage.getUserInfo();
    if (userInfo != null && mounted) {
      setState(() {
        _displayName = userInfo.displayName ?? userInfo.email.split('@').first;
      });
    }
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vehicles = await _vehicleService.getVehicles();
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load vehicles: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Vehicle',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${vehicle.name}"? This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _vehicleService.deleteVehicle(vehicle.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vehicle.name} deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadVehicles(); // Reload the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete vehicle: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
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
        title: Text('AutoCare', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              // Reload user info if display name was changed
              if (result == true) {
                _loadUserInfo();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadVehicles,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _buildContent(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
          );
          // Reload vehicles if a new one was added
          if (result == true) {
            _loadVehicles();
          }
        },
        backgroundColor: AppColors.accentPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    if (_vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No vehicles yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first vehicle to get started',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Group vehicles by role
    final ownedVehicles = _vehicles
        .where((v) => v.userRole == 'OWNER')
        .toList();
    final editorVehicles = _vehicles
        .where((v) => v.userRole == 'EDITOR')
        .toList();
    final viewerVehicles = _vehicles
        .where((v) => v.userRole == 'VIEWER')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $_displayName',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Select your vehicle',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              // Owned vehicles section
              if (ownedVehicles.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'Owned',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...ownedVehicles.map(
                  (vehicle) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: VehicleCard(
                      vehicle: vehicle,
                      onTap: () {
                        // TODO: Navigate to vehicle detail screen
                      },
                      onManageRoles: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                VehicleRoleSettingsScreen(vehicle: vehicle),
                          ),
                        );
                      },
                      onEdit: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                EditVehicleScreen(vehicle: vehicle),
                          ),
                        );
                        if (result == true) {
                          _loadVehicles();
                        }
                      },
                      onDelete: () => _deleteVehicle(vehicle),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Editor vehicles section
              if (editorVehicles.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'Editor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...editorVehicles.map(
                  (vehicle) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: VehicleCard(
                      vehicle: vehicle,
                      onTap: () {
                        // TODO: Navigate to vehicle detail screen
                      },
                      onEdit: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                EditVehicleScreen(vehicle: vehicle),
                          ),
                        );
                        if (result == true) {
                          _loadVehicles();
                        }
                      },
                      // No delete button for editors
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Viewer vehicles section
              if (viewerVehicles.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'Viewer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...viewerVehicles.map(
                  (vehicle) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: VehicleCard(
                      vehicle: vehicle,
                      onTap: () {
                        // TODO: Navigate to vehicle detail screen
                      },
                      // No edit or delete buttons for viewers
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
