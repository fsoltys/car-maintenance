import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/odometer_service.dart';
import '../fuel/fuel_screen.dart';
import 'add_manual_entry_screen.dart';
import 'odometer_chart_screen.dart';

class OdometerEntriesScreen extends StatefulWidget {
  final Vehicle vehicle;

  const OdometerEntriesScreen({super.key, required this.vehicle});

  @override
  State<OdometerEntriesScreen> createState() => _OdometerEntriesScreenState();
}

class _OdometerEntriesScreenState extends State<OdometerEntriesScreen> {
  final OdometerService _odometerService = OdometerService();
  List<OdometerHistoryItem> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _odometerService.getOdometerGraph(
        widget.vehicle.id,
      );
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load odometer entries: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteManualEntry(String entryId) async {
    try {
      await _odometerService.deleteOdometerEntry(entryId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted successfully')),
      );
      _loadEntries();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete entry: $e')));
    }
  }

  void _showDeleteConfirmation(String entryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this manual odometer entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteManualEntry(entryId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToEntry(OdometerHistoryItem entry) {
    final source = entry.source.toLowerCase();

    if (source == 'fueling') {
      // Navigate to fuel screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FuelScreen(vehicle: widget.vehicle),
        ),
      );
    } else if (source == 'service') {
      // TODO: Navigate to service screen when implemented
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service module coming soon')),
      );
    } else if (source == 'manual') {
      // Navigate to edit manual entry
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => AddManualEntryScreen(
                vehicle: widget.vehicle,
                entryId: entry.sourceId,
              ),
            ),
          )
          .then((_) => _loadEntries());
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
            Text(
              'Odometer History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              widget.vehicle.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      OdometerChartScreen(vehicle: widget.vehicle),
                ),
              );
            },
            tooltip: 'View Chart',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadEntries,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.speed_outlined,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No odometer entries yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a manual entry or record a fueling/service',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return _buildEntryCard(entry);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) =>
                      AddManualEntryScreen(vehicle: widget.vehicle),
                ),
              )
              .then((_) => _loadEntries());
        },
        backgroundColor: AppColors.accentPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEntryCard(OdometerHistoryItem entry) {
    final source = entry.source.toLowerCase();
    IconData icon;
    Color color;
    String label;

    switch (source) {
      case 'fueling':
        icon = Icons.local_gas_station;
        color = AppColors.accentSecondary;
        label = 'Fueling';
        break;
      case 'service':
        icon = Icons.build;
        color = const Color(0xFF4CAF50);
        label = 'Service';
        break;
      case 'manual':
        icon = Icons.edit_note;
        color = AppColors.accentPrimary;
        label = 'Manual Entry';
        break;
      default:
        icon = Icons.speed;
        color = AppColors.textSecondary;
        label = source;
    }

    return Card(
      color: AppColors.bgSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToEntry(entry),
        onLongPress: source == 'manual' && entry.sourceId != null
            ? () => _showDeleteConfirmation(entry.sourceId!)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                        ),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(entry.timestamp),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.odometerKm.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
