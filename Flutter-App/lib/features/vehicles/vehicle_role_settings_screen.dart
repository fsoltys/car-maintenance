import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';

class VehicleRoleSettingsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleRoleSettingsScreen({super.key, required this.vehicle});

  @override
  State<VehicleRoleSettingsScreen> createState() =>
      _VehicleRoleSettingsScreenState();
}

class _VehicleRoleSettingsScreenState extends State<VehicleRoleSettingsScreen> {
  final VehicleService _vehicleService = VehicleService();
  final List<_ShareEntry> _shareEntries = [];
  bool _isLoading = true;
  List<VehicleShare> _existingShares = [];

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  Future<void> _loadShares() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final shares = await _vehicleService.getVehicleShares(widget.vehicle.id);
      // Sort shares to ensure owner appears first
      shares.sort((a, b) {
        // Owner always comes first
        if (a.isOwner) return -1;
        if (b.isOwner) return 1;
        // Then sort alphabetically by email
        return a.email.compareTo(b.email);
      });

      setState(() {
        _existingShares = shares;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load shares: $e'),
            backgroundColor: AppColors.accentPrimary,
          ),
        );
      }
    }
  }

  void _addNewShareEntry() {
    setState(() {
      _shareEntries.add(_ShareEntry());
    });
  }

  void _removeShareEntry(int index) {
    setState(() {
      _shareEntries.removeAt(index);
    });
  }

  Future<void> _saveShareEntry(_ShareEntry entry) async {
    if (entry.emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email'),
          backgroundColor: AppColors.accentPrimary,
        ),
      );
      return;
    }

    if (entry.selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role'),
          backgroundColor: AppColors.accentPrimary,
        ),
      );
      return;
    }

    setState(() {
      entry.isSaving = true;
    });

    try {
      await _vehicleService.addOrUpdateVehicleShare(
        widget.vehicle.id,
        entry.emailController.text.trim(),
        entry.selectedRole!,
      );

      if (mounted) {
        // Reload shares first
        await _loadShares();

        setState(() {
          entry.isSaving = false;
          _shareEntries.remove(entry);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Share added successfully'),
            backgroundColor: AppColors.accentSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          entry.isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add share: $e'),
            backgroundColor: AppColors.accentPrimary,
          ),
        );
      }
    }
  }

  Future<void> _updateExistingShare(VehicleShare share, String newRole) async {
    try {
      await _vehicleService.updateVehicleShare(
        widget.vehicle.id,
        share.userId,
        newRole,
      );

      if (mounted) {
        // Reload shares
        await _loadShares();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Role updated successfully'),
            backgroundColor: AppColors.accentSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: $e'),
            backgroundColor: AppColors.accentPrimary,
          ),
        );
      }
    }
  }

  Future<void> _deleteShare(VehicleShare share) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Access'),
        content: Text(
          'Are you sure you want to remove access for ${share.email}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _vehicleService.deleteVehicleShare(widget.vehicle.id, share.userId);

      if (mounted) {
        // Reload shares
        await _loadShares();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access removed successfully'),
            backgroundColor: AppColors.accentSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove access: $e'),
            backgroundColor: AppColors.accentPrimary,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (var entry in _shareEntries) {
      entry.emailController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        title: const Text('Manage Access'),
        backgroundColor: AppColors.bgMain,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentSecondary,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Vehicle info header
                Text(
                  widget.vehicle.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage who has access to this vehicle',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Existing shares
                if (_existingShares.isNotEmpty) ...[
                  Text(
                    'Current Access',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_existingShares.length, (index) {
                    final share = _existingShares[index];
                    return Card(
                      key: ValueKey(share.userId),
                      elevation: 0,
                      color: AppColors.bgSurface,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    share.email,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  if (share.displayName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      share.displayName!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (share.isOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSecondary.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'OWNER',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentSecondary,
                                  ),
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButton<String>(
                                    value: share.role,
                                    underline: Container(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'EDITOR',
                                        child: Text('EDITOR'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'VIEWER',
                                        child: Text('VIEWER'),
                                      ),
                                    ],
                                    onChanged: (newRole) {
                                      if (newRole != null) {
                                        _updateExistingShare(share, newRole);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.accentPrimary,
                                      size: 20,
                                    ),
                                    onPressed: () => _deleteShare(share),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // New share entries
                if (_shareEntries.isNotEmpty) ...[
                  Text(
                    'Add New Access',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._shareEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final shareEntry = entry.value;

                    return Card(
                      elevation: 0,
                      color: AppColors.bgSurface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: shareEntry.emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'user@example.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              enabled: !shareEntry.isSaving,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: shareEntry.selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Role',
                                prefixIcon: Icon(Icons.admin_panel_settings),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'EDITOR',
                                  child: Text('EDITOR'),
                                ),
                                DropdownMenuItem(
                                  value: 'VIEWER',
                                  child: Text('VIEWER'),
                                ),
                              ],
                              onChanged: shareEntry.isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        shareEntry.selectedRole = value;
                                      });
                                    },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: shareEntry.isSaving
                                        ? null
                                        : () => _saveShareEntry(shareEntry),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.accentSecondary,
                                      foregroundColor: AppColors.textPrimary,
                                    ),
                                    child: shareEntry.isSaving
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.textPrimary,
                                            ),
                                          )
                                        : const Text('Save'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.accentPrimary,
                                  ),
                                  onPressed: shareEntry.isSaving
                                      ? null
                                      : () => _removeShareEntry(index),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // Add button
                ElevatedButton.icon(
                  onPressed: _addNewShareEntry,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSecondary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ShareEntry {
  final TextEditingController emailController = TextEditingController();
  String? selectedRole;
  bool isSaving = false;
}
