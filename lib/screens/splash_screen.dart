import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../utils/constants.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    final storage = context.read<StorageService>();
    final onboarded = storage.getBool('onboarded') ?? false;
    final loggedIn = storage.getBool('isLoggedIn') ?? false;

    Widget nextScreen;
    if (!onboarded) {
      nextScreen = const OnboardingScreen();
    } else if (!loggedIn) {
      nextScreen = const LoginScreen();
    } else {
      nextScreen = const DashboardScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background aurora glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryPurple.withValues(alpha: 0.15),
              ),
            ).animate().fade(duration: 1500.ms),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan.withValues(alpha: 0.15),
              ),
            ).animate().fade(duration: 1500.ms),
          ),

          // Central content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing central Orb
                Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [AppColors.cyan, AppColors.primaryPurple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPurple.withValues(
                              alpha: 0.5,
                            ),
                            blurRadius: 32.0,
                            spreadRadius: 8.0,
                          ),
                          BoxShadow(
                            color: AppColors.cyan.withValues(alpha: 0.3),
                            blurRadius: 16.0,
                            spreadRadius: 4.0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 40,
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                      duration: 1200.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .shake(duration: 1000.ms, hz: 2),

                const SizedBox(height: 32),

                // Title
                const Text(
                      'FINPILOT AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    )
                    .animate()
                    .fade(duration: 800.ms, delay: 200.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0.0,
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                      'Your Intelligent Finance Companion',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    )
                    .animate()
                    .fade(duration: 800.ms, delay: 500.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0.0,
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
