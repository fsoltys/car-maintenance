import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/auth/session_manager.dart';
import '../welcome/welcome_screen.dart';
import '../vehicles/vehicle_list_screen.dart';

/// Splash screen that checks authentication status and navigates accordingly
///
/// Future enhancement: Add logic to check for primary vehicle setting
/// and navigate to vehicle dashboard if primary vehicle is set
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SessionManager _sessionManager = SessionManager();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      final isLoggedIn = await _sessionManager.isLoggedIn();

      if (!mounted) return;

      if (isLoggedIn) {
        // User is logged in
        // TODO: Check for primary vehicle setting here
        // If primary vehicle is set, navigate to vehicle dashboard
        // For now, navigate to vehicle list
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const VehicleListScreen()),
        );
      } else {
        // User is not logged in, show welcome screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    } catch (e) {
      // On error, navigate to welcome screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon can go here
            Text(
              'AutoCare',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.accentSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.accentSecondary),
          ],
        ),
      ),
    );
  }
}
