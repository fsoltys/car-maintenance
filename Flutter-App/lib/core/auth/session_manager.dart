import 'auth_storage.dart';
import '../api/auth_service.dart';

class SessionManager {
  final AuthStorage _storage = AuthStorage();
  final AuthService _authService = AuthService();

  Future<void> login(String email, String password) async {
    final response = await _authService.login(email, password);
    
    await _storage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
  }

  Future<void> register(String email, String password, String displayName) async {
    final userProfile = await _authService.register(email, password, displayName);
    await _storage.saveUserInfo(
      userId: userProfile.id,
      email: userProfile.email,
      displayName: userProfile.displayName,
    );
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  Future<bool> isLoggedIn() async {
    return await _storage.isLoggedIn();
  }

  Future<String?> getAccessToken() async {
    return await _storage.getAccessToken();
  }

  Future<String?> getRefreshToken() async {
    return await _storage.getRefreshToken();
  }

  Future<UserInfo?> getUserInfo() async {
    return await _storage.getUserInfo();
  }

  Future<void> refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final newTokens = await _authService.refreshToken(refreshToken);
    
    await _storage.saveTokens(
      accessToken: newTokens.accessToken,
      refreshToken: newTokens.refreshToken,
    );
  }
}
