import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Local color palette matching Focusly theme
  static const Color kPrimaryBlue = Color(0xFF2E6FF2);
  static const Color kNavy = Color(0xFF0F1C4D);
  static const Color kBackground = Color(0xFFF8FAFC);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kBorderGray = Color(0xFFE2E8F0);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kAccentGreen = Color(0xFF3DDC63);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Focusly',
          style: TextStyle(
            color: kNavy,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: kNavy),
            onPressed: () {},
          ),
        ],
        shape: const Border(
          bottom: BorderSide(color: kBorderGray, width: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Today's Focus Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderGray),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kAccentGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          color: kAccentGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Today's Focus Session",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ready to start your deep work sprint?',
                    style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Start 25m Pomodoro'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
