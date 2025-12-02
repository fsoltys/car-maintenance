import 'api_client.dart';

class IssueService {
  final ApiClient _apiClient;

  IssueService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get issues for a vehicle
  Future<List<Issue>> getVehicleIssues(
    String vehicleId, {
    String? status,
    String? priority,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;

    final uri = Uri.parse(
      '/vehicles/$vehicleId/issues',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await _apiClient.get(uri.toString());
    if (response is List) {
      return response
          .map((json) => Issue.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Create a new issue
  Future<Issue> createIssue(
    String vehicleId, {
    required String title,
    String? description,
    required IssuePriority priority,
    required IssueStatus status,
    List<String>? errorCodes,
  }) async {
    final response = await _apiClient.post(
      '/vehicles/$vehicleId/issues',
      body: {
        'title': title,
        if (description != null) 'description': description,
        'priority': priority.name,
        'status': status.name,
        if (errorCodes != null && errorCodes.isNotEmpty)
          'error_codes': errorCodes,
      },
    );
    return Issue.fromJson(response as Map<String, dynamic>);
  }

  /// Update an issue
  Future<Issue> updateIssue(
    String issueId, {
    String? title,
    String? description,
    IssuePriority? priority,
    IssueStatus? status,
    List<String>? errorCodes,
  }) async {
    final response = await _apiClient.patch(
      '/issues/$issueId',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority.name,
        if (status != null) 'status': status.name,
        if (errorCodes != null) 'error_codes': errorCodes,
      },
    );
    return Issue.fromJson(response as Map<String, dynamic>);
  }

  /// Delete an issue
  Future<void> deleteIssue(String issueId) async {
    await _apiClient.delete('/issues/$issueId');
  }
}

// Models

enum IssuePriority {
  LOW,
  MEDIUM,
  HIGH,
  CRITICAL;

  String get displayName {
    switch (this) {
      case IssuePriority.LOW:
        return 'Low';
      case IssuePriority.MEDIUM:
        return 'Medium';
      case IssuePriority.HIGH:
        return 'High';
      case IssuePriority.CRITICAL:
        return 'Critical';
    }
  }
}

enum IssueStatus {
  OPEN,
  IN_PROGRESS,
  DONE,
  CANCELLED;

  String get displayName {
    switch (this) {
      case IssueStatus.OPEN:
        return 'Open';
      case IssueStatus.IN_PROGRESS:
        return 'In Progress';
      case IssueStatus.DONE:
        return 'Done';
      case IssueStatus.CANCELLED:
        return 'Cancelled';
    }
  }
}

class Issue {
  final String id;
  final String vehicleId;
  final String createdBy;
  final String title;
  final String? description;
  final IssuePriority priority;
  final IssueStatus status;
  final String? errorCodes;
  final DateTime? createdAt;
  final DateTime? closedAt;

  Issue({
    required this.id,
    required this.vehicleId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.errorCodes,
    this.createdAt,
    this.closedAt,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: IssuePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => IssuePriority.MEDIUM,
      ),
      status: IssueStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => IssueStatus.OPEN,
      ),
      errorCodes: json['error_codes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'priority': priority.name,
      'status': status.name,
      'error_codes': errorCodes,
      'created_at': createdAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}
