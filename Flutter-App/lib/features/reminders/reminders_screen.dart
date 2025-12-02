import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/reminder_service.dart';
import 'add_reminder_screen.dart';

class RemindersScreen extends StatefulWidget {
  final Vehicle vehicle;

  const RemindersScreen({super.key, required this.vehicle});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final ReminderService _reminderService = ReminderService();
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reminders = await _reminderService.getVehicleReminders(
        widget.vehicle.id,
      );
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteReminder(String reminderId) async {
    try {
      await _reminderService.deleteReminder(reminderId);
      _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder deleted'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting reminder: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(String reminderId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteReminder(reminderId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getReminderStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
        return 'success';
      case 'DUE':
        return 'warning';
      case 'OVERDUE':
        return 'error';
      default:
        return 'neutral';
    }
  }

  String _formatDueInfo(Reminder reminder) {
    String? timeInfo;
    String? distanceInfo;

    // Calculate time-based info
    if (reminder.nextDueDate != null) {
      final daysUntil = reminder.nextDueDate!.difference(DateTime.now()).inDays;
      if (daysUntil < 0) {
        timeInfo = '${daysUntil.abs()} days overdue';
      } else if (daysUntil == 0) {
        timeInfo = 'today';
      } else {
        timeInfo = '$daysUntil days';
      }
    }

    // Calculate distance-based info
    if (reminder.nextDueOdometerKm != null) {
      distanceInfo = '${reminder.nextDueOdometerKm!.toStringAsFixed(0)} km';
    }

    // Combine both when present
    if (timeInfo != null && distanceInfo != null) {
      if (timeInfo.contains('overdue')) {
        return 'Overdue: $timeInfo or $distanceInfo';
      } else if (timeInfo == 'today') {
        return 'Due today or at $distanceInfo';
      } else {
        return 'Due in $timeInfo or $distanceInfo';
      }
    } else if (timeInfo != null) {
      return timeInfo.contains('overdue') || timeInfo == 'today'
          ? timeInfo.substring(0, 1).toUpperCase() + timeInfo.substring(1)
          : 'Due in $timeInfo';
    } else if (distanceInfo != null) {
      return 'Due at $distanceInfo';
    }

    return 'No due date set';
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
            Text('Reminders', style: Theme.of(context).textTheme.titleLarge),
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
              builder: (context) => AddReminderScreen(vehicle: widget.vehicle),
            ),
          );
          if (result == true) {
            _loadReminders();
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
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadReminders,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _reminders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reminders yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up service reminders to stay on top of maintenance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReminders,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reminders.length,
                itemBuilder: (context, index) {
                  final reminder = _reminders[index];
                  return _buildReminderCard(reminder);
                },
              ),
            ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final statusColor = _getReminderStatusColor(reminder.status);
    Color cardBorderColor;

    switch (statusColor) {
      case 'success':
        cardBorderColor = AppColors.success.withOpacity(0.3);
        break;
      case 'warning':
        cardBorderColor = const Color(0xFFFFC107).withOpacity(0.3);
        break;
      case 'error':
        cardBorderColor = AppColors.error.withOpacity(0.3);
        break;
      default:
        cardBorderColor = AppColors.textSecondary.withOpacity(0.1);
    }

    return Card(
      color: AppColors.bgSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorderColor, width: 2),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddReminderScreen(
                vehicle: widget.vehicle,
                reminder: reminder,
              ),
            ),
          );
          if (result == true) {
            _loadReminders();
          }
        },
        onLongPress: () => _showDeleteConfirmation(reminder.id, reminder.name),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reminder.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (reminder.status != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusBadgeColor(statusColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reminder.status!.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getStatusTextColor(statusColor),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),

              if (reminder.description != null &&
                  reminder.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reminder.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Due info
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatDueInfo(reminder),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              // Service type and interval
              if (reminder.serviceType != null ||
                  reminder.dueEveryDays != null ||
                  reminder.dueEveryKm != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (reminder.serviceType != null)
                      _buildInfoChip(
                        Icons.build_outlined,
                        _formatServiceType(reminder.serviceType!),
                      ),
                    if (reminder.dueEveryDays != null)
                      _buildInfoChip(
                        Icons.calendar_today,
                        'Every ${reminder.dueEveryDays} days',
                      ),
                    if (reminder.dueEveryKm != null)
                      _buildInfoChip(
                        Icons.speed,
                        'Every ${reminder.dueEveryKm} km',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusBadgeColor(String statusColor) {
    switch (statusColor) {
      case 'success':
        return AppColors.success.withOpacity(0.2);
      case 'warning':
        return const Color(0xFFFFC107).withOpacity(0.2);
      case 'error':
        return AppColors.error.withOpacity(0.2);
      default:
        return AppColors.textSecondary.withOpacity(0.1);
    }
  }

  Color _getStatusTextColor(String statusColor) {
    switch (statusColor) {
      case 'success':
        return AppColors.success;
      case 'warning':
        return const Color(0xFFFFC107);
      case 'error':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatServiceType(String serviceType) {
    return serviceType
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}
