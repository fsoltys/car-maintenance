import 'dart:async';

/// Global authentication event stream
/// Used to broadcast authentication-related events across the app
class AuthEvents {
  static final AuthEvents _instance = AuthEvents._internal();
  factory AuthEvents() => _instance;
  AuthEvents._internal();

  final _sessionExpiredController = StreamController<void>.broadcast();

  /// Stream that emits when the user's session has expired
  /// Listen to this stream to handle navigation to login screen
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  /// Emit session expired event
  /// This will trigger all listeners to handle session expiration
  void emitSessionExpired() {
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  /// Clean up resources
  void dispose() {
    _sessionExpiredController.close();
  }
}
