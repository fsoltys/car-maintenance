import 'package:flutter/material.dart';
import 'package:car_maintenance_app/app_theme.dart';
import 'package:car_maintenance_app/features/welcome/welcome_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Maintenance',
      theme: AppTheme.darkTheme,
      home: const WelcomeScreen(),
    );
  }
}