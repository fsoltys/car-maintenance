
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgMain,
          image: DecorationImage(
              image: AssetImage("assets/images/welcome_background.png"),
              fit: BoxFit.cover,
              opacity: 0.16),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(flex: 2),
                Text(
                  'AutoCare',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const Spacer(flex: 3),
                Image.asset(
                  'assets/images/logo.png',
                  height: screenHeight * 0.25,
                ),
                const Spacer(flex: 4),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SignUpScreen()),
                    );
                  },
                  icon: const Icon(Icons.email),
                  label: const Text('SIGN UP WITH EMAIL'),
                  style: Theme.of(context).elevatedButtonTheme.style,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSecondary,
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('LOG IN'),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
