import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_storage.dart';

class ApiClient {
  // Use 10.0.2.2 for Android emulator, localhost for iOS simulator
  static const String baseUrl = 'http://10.0.2.2:8000';
  final AuthStorage _authStorage = AuthStorage();

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

    final response = await http.post(
      uri,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

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

    final response = await http.post(
      uri,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

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

    final response = await http.get(uri, headers: finalHeaders);

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

    final response = await http.delete(uri, headers: finalHeaders);

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

    final response = await http.patch(
      uri,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

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

    final response = await http.put(
      uri,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

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
