import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<LoginResponse> login(String email, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'username': email,
        'password': password,
        'grant_type': 'password',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return LoginResponse.fromJson(json);
    } else {
      final error = jsonDecode(response.body);
      throw AuthException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'Login failed',
      );
    }
  }

  Future<UserProfile> register(
    String email,
    String password,
    String displayName,
  ) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } else {
      final error = jsonDecode(response.body);
      throw AuthException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'Registration failed',
      );
    }
  }

  Future<LoginResponse> refreshToken(String refreshToken) async {
    final uri = Uri.parse('$baseUrl/auth/refresh');
    
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'refresh_token': refreshToken,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return LoginResponse.fromJson(json);
    } else {
      final error = jsonDecode(response.body);
      throw AuthException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'Token refresh failed',
      );
    }
  }
}

class AuthException implements Exception {
  final int statusCode;
  final String message;

  AuthException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => message;
}

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final String refreshToken;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.refreshToken,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? displayName;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
    );
  }
}
