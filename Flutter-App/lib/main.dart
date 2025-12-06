import 'package:flutter/material.dart';
import 'package:car_maintenance_app/app_theme.dart';
import 'package:car_maintenance_app/features/splash/splash_screen.dart';
import 'package:car_maintenance_app/core/auth/auth_events.dart';
import 'package:car_maintenance_app/features/auth/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AuthEvents _authEvents = AuthEvents();

  @override
  void initState() {
    super.initState();
    _listenToAuthEvents();
  }

  void _listenToAuthEvents() {
    _authEvents.onSessionExpired.listen((_) {
      // Navigate to login screen when session expires
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      // Show a message to the user
      _navigatorKey.currentContext?.let((context) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            backgroundColor: AppColors.accentPrimary,
            duration: Duration(seconds: 3),
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Car Maintenance',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

extension ContextExtension on BuildContext? {
  void let(void Function(BuildContext context) action) {
    if (this != null) {
      action(this!);
    }
  }
}
