import 'auth_storage.dart';
import '../api/auth_service.dart';
import '../api/user_service.dart';
import '../api/api_client.dart';

class SessionManager {
  final AuthStorage _storage = AuthStorage();
  final AuthService _authService = AuthService();
  late final UserService _userService;
  late final ApiClient _apiClient;

  SessionManager() {
    _apiClient = ApiClient();
    _userService = UserService(apiClient: _apiClient);
  }

  Future<void> login(String email, String password) async {
    final response = await _authService.login(email, password);

    await _storage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );

    // Fetch and save user profile
    try {
      final userProfile = await _userService.getMyProfile();
      await _storage.saveUserInfo(
        userId: userProfile.id,
        email: userProfile.email,
        displayName: userProfile.displayName,
      );
    } catch (e) {
      // If we can't fetch profile, at least save the email
      await _storage.saveUserInfo(
        userId: '', // Will be updated when profile loads
        email: email,
        displayName: null,
      );
    }
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    final userProfile = await _authService.register(
      email,
      password,
      displayName,
    );
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
