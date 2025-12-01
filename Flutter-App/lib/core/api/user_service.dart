import 'api_client.dart';

class UserService {
  final ApiClient _apiClient;

  UserService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get current user profile
  Future<UserProfile> getMyProfile() async {
    final response = await _apiClient.get('/users/me');
    return UserProfile.fromJson(response as Map<String, dynamic>);
  }

  /// Update current user profile (display_name)
  Future<UserProfile> updateMyProfile({String? displayName}) async {
    final response = await _apiClient.patch(
      '/users/me',
      body: {if (displayName != null) 'display_name': displayName},
    );
    return UserProfile.fromJson(response as Map<String, dynamic>);
  }

  /// Change current user password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _apiClient.patch(
      '/users/me/password',
      body: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
