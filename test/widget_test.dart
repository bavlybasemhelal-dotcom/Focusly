import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/screens/home_screen.dart';
import 'package:focusly/screens/onboarding_screen.dart';
import 'package:focusly/screens/splash_screen.dart';

void main() {
  group('Focusly SplashScreen Tests', () {
    testWidgets('Renders centered logo, rising productivity icons, and progress bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(isFirstLaunch: true),
        ),
      );

      // Verify rising productivity icons are present in the tree
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      expect(find.byIcon(Icons.checklist_rounded), findsWidgets);
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
      expect(find.byIcon(Icons.task_alt_rounded), findsWidgets);

      // Verify progress status text
      expect(find.text('⚡ Initializing smart task engine...'), findsOneWidget);

      // Advance initial entrance animation
      await tester.pump(const Duration(milliseconds: 900));
    });

    testWidgets('Navigates to OnboardingScreen after 5 seconds when isFirstLaunch is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(isFirstLaunch: true),
        ),
      );

      // Advance time by 2.5 seconds (midway through splash)
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      // Advance past the 5-second mark to complete progress
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();

      // Verify navigation to OnboardingScreen
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Welcome to Focusly'), findsOneWidget);
    });

    testWidgets('Navigates to HomeScreen after 5 seconds when isFirstLaunch is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(isFirstLaunch: false),
        ),
      );

      // Advance past 5 seconds
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pumpAndSettle();

      // Verify navigation to HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text("Today's Focus Session"), findsOneWidget);
    });
  });
}
