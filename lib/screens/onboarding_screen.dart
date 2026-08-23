import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  // Local color palette matching Focusly theme
  static const Color kPrimaryBlue = Color(0xFF2E6FF2);
  static const Color kNavy = Color(0xFF0F1C4D);
  static const Color kBackground = Color(0xFFF8FAFC);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kAccentGreen = Color(0xFF3DDC63);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Hero Icon / Graphic
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 48,
                  color: kPrimaryBlue,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to Focusly',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: kNavy,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Master your productivity with focused time blocking, habit tracking, and ambient workflows.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: kTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Get Started Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
