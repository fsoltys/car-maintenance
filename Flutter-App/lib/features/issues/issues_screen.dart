import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/issue_service.dart';
import 'add_issue_screen.dart';

class IssuesScreen extends StatefulWidget {
  final Vehicle vehicle;

  const IssuesScreen({super.key, required this.vehicle});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  final IssueService _issueService = IssueService();
  List<Issue> _issues = [];
  bool _isLoading = true;
  String? _error;
  IssueStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final issues = await _issueService.getVehicleIssues(
        widget.vehicle.id,
        status: _filterStatus?.name,
      );
      setState(() {
        _issues = issues;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load issues: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteIssue(String issueId) async {
    try {
      await _issueService.deleteIssue(issueId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue deleted successfully')),
      );
      _loadIssues();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete issue: $e')));
    }
  }

  void _showDeleteConfirmation(Issue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Delete Issue'),
        content: Text('Are you sure you want to delete "${issue.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteIssue(issue.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filter by Status',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All'),
              leading: Radio<IssueStatus?>(
                value: null,
                groupValue: _filterStatus,
                onChanged: (value) {
                  setState(() => _filterStatus = value);
                  Navigator.of(context).pop();
                  _loadIssues();
                },
              ),
            ),
            ...IssueStatus.values.map((status) {
              return ListTile(
                title: Text(status.displayName),
                leading: Radio<IssueStatus?>(
                  value: status,
                  groupValue: _filterStatus,
                  onChanged: (value) {
                    setState(() => _filterStatus = value);
                    Navigator.of(context).pop();
                    _loadIssues();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
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
            Text('Issues', style: Theme.of(context).textTheme.titleLarge),
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
            icon: Icon(
              Icons.filter_list,
              color: _filterStatus != null
                  ? AppColors.accentPrimary
                  : AppColors.textPrimary,
            ),
            onPressed: _showFilterOptions,
            tooltip: 'Filter',
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
                    onPressed: _loadIssues,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _issues.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _filterStatus != null
                        ? 'No ${_filterStatus!.displayName.toLowerCase()} issues'
                        : 'No issues yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track problems and TODOs for your vehicle',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadIssues,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _issues.length,
                itemBuilder: (context, index) {
                  final issue = _issues[index];
                  return _buildIssueCard(issue);
                },
              ),
            ),
      floatingActionButton: widget.vehicle.userRole != 'VIEWER'
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) =>
                            AddIssueScreen(vehicle: widget.vehicle),
                      ),
                    )
                    .then((_) => _loadIssues());
              },
              backgroundColor: AppColors.accentPrimary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildIssueCard(Issue issue) {
    Color priorityColor;
    IconData priorityIcon;

    switch (issue.priority) {
      case IssuePriority.LOW:
        priorityColor = AppColors.info;
        priorityIcon = Icons.flag_outlined;
        break;
      case IssuePriority.MEDIUM:
        priorityColor = AppColors.warning;
        priorityIcon = Icons.flag;
        break;
      case IssuePriority.HIGH:
        priorityColor = AppColors.error;
        priorityIcon = Icons.flag;
        break;
      case IssuePriority.CRITICAL:
        priorityColor = AppColors.error;
        priorityIcon = Icons.warning;
        break;
    }

    Color statusColor;
    switch (issue.status) {
      case IssueStatus.OPEN:
        statusColor = AppColors.error;
        break;
      case IssueStatus.IN_PROGRESS:
        statusColor = AppColors.warning;
        break;
      case IssueStatus.DONE:
        statusColor = AppColors.success;
        break;
      case IssueStatus.CANCELLED:
        statusColor = AppColors.textMuted;
        break;
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
        onTap: widget.vehicle.userRole != 'VIEWER'
            ? () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) => AddIssueScreen(
                          vehicle: widget.vehicle,
                          issue: issue,
                        ),
                      ),
                    )
                    .then((_) => _loadIssues());
              }
            : null,
        onLongPress: widget.vehicle.userRole != 'VIEWER'
            ? () => _showDeleteConfirmation(issue)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(priorityIcon, color: priorityColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issue.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      issue.status.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (issue.description != null &&
                  issue.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  issue.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    issue.createdAt != null
                        ? DateFormat('dd MMM yyyy').format(issue.createdAt!)
                        : 'Unknown',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      issue.priority.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
