import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();
  
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyUserEmail = 'user_email';
  static const _keyUserDisplayName = 'user_display_name';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> deleteTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
    ]);
  }

  Future<void> saveUserInfo({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    await Future.wait([
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyUserEmail, value: email),
      if (displayName != null)
        _storage.write(key: _keyUserDisplayName, value: displayName),
    ]);
  }

  Future<UserInfo?> getUserInfo() async {
    final userId = await _storage.read(key: _keyUserId);
    final email = await _storage.read(key: _keyUserEmail);
    final displayName = await _storage.read(key: _keyUserDisplayName);

    if (userId == null || email == null) {
      return null;
    }

    return UserInfo(
      userId: userId,
      email: email,
      displayName: displayName,
    );
  }

  Future<void> deleteUserInfo() async {
    await Future.wait([
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyUserEmail),
      _storage.delete(key: _keyUserDisplayName),
    ]);
  }

  Future<void> clearAll() async {
    await Future.wait([
      deleteTokens(),
      deleteUserInfo(),
    ]);
  }

  Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    return accessToken != null;
  }
}

class UserInfo {
  final String userId;
  final String email;
  final String? displayName;

  UserInfo({
    required this.userId,
    required this.email,
    this.displayName,
  });
}
