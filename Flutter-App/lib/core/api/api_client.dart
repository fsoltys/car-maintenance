import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_storage.dart';
import '../auth/auth_events.dart';
import 'auth_service.dart';

class ApiClient {
  // Use 10.0.2.2 for Android emulator, localhost for iOS simulator
  static const String baseUrl = 'http://10.0.2.2:8000';
  final AuthStorage _authStorage = AuthStorage();
  final AuthService _authService = AuthService();
  final AuthEvents _authEvents = AuthEvents();

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final baseHeaders = {'Content-Type': 'application/json', ...?headers};

    if (includeAuth) {
      final token = await _authStorage.getAccessToken();
      if (token != null) {
        baseHeaders['Authorization'] = 'Bearer $token';
      }
    }

    return baseHeaders;
  }

  /// Handle token refresh on 401 errors
  /// Returns true if refresh was successful, false if user needs to re-login
  Future<bool> _handleUnauthorized() async {
    try {
      final refreshToken = await _authStorage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      final newTokens = await _authService.refreshToken(refreshToken);

      await _authStorage.saveTokens(
        accessToken: newTokens.accessToken,
        refreshToken: newTokens.refreshToken,
      );
      return true;
    } catch (e) {
      // Refresh failed, clear all auth data and emit session expired event
      await _authStorage.clearAll();
      _authEvents.emitSessionExpired();
      return false;
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final finalHeaders = await _buildHeaders(
      headers: headers,
      includeAuth: includeAuth,
    );

    var response = await http.post(
      uri,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

    // Handle token refresh on 401
    if (response.statusCode == 401 && includeAuth) {
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        // Retry with new token
        final retryHeaders = await _buildHeaders(
          headers: headers,
          includeAuth: includeAuth,
        );
        response = await http.post(
          uri,
          headers: retryHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.body.isEmpty) {
        return {};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'An error occurred',
      );
    }
  }

  Future<dynamic> postList(
    String endpoint, {
    List<Map<String, dynamic>>? body,
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final finalHeaders = await _buildHeaders(
      headers: headers,
      includeAuth: includeAuth,
    );

    var response = await http.post(
      uri,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

    // Handle token refresh on 401
    if (response.statusCode == 401 && includeAuth) {
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        final retryHeaders = await _buildHeaders(
          headers: headers,
          includeAuth: includeAuth,
        );
        response = await http.post(
          uri,
          headers: retryHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'An error occurred',
      );
    }
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final finalHeaders = await _buildHeaders(
      headers: headers,
      includeAuth: includeAuth,
    );

    var response = await http.get(uri, headers: finalHeaders);

    // Handle token refresh on 401
    if (response.statusCode == 401 && includeAuth) {
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        final retryHeaders = await _buildHeaders(
          headers: headers,
          includeAuth: includeAuth,
        );
        response = await http.get(uri, headers: retryHeaders);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'An error occurred',
      );
    }
  }

  Future<void> delete(
    String endpoint, {
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final finalHeaders = await _buildHeaders(
      headers: headers,
      includeAuth: includeAuth,
    );

    var response = await http.delete(uri, headers: finalHeaders);

    // Handle token refresh on 401
    if (response.statusCode == 401 && includeAuth) {
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        final retryHeaders = await _buildHeaders(
          headers: headers,
          includeAuth: includeAuth,
        );
        response = await http.delete(uri, headers: retryHeaders);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'An error occurred',
      );
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final finalHeaders = await _buildHeaders(
      headers: headers,
      includeAuth: includeAuth,
    );

    var response = await http.patch(
      uri,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

    // Handle token refresh on 401
    if (response.statusCode == 401 && includeAuth) {
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        final retryHeaders = await _buildHeaders(
          headers: headers,
          includeAuth: includeAuth,
        );
        response = await http.patch(
          uri,
          headers: retryHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.body.isEmpty) {
        return {};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'An error occurred',
      );
    }
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final finalHeaders = await _buildHeaders(
      headers: headers,
      includeAuth: includeAuth,
    );

    var response = await http.put(
      uri,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

    // Handle token refresh on 401
    if (response.statusCode == 401 && includeAuth) {
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        final retryHeaders = await _buildHeaders(
          headers: headers,
          includeAuth: includeAuth,
        );
        response = await http.put(
          uri,
          headers: retryHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'An error occurred',
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
