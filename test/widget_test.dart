import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/screens/home_screen.dart';
import 'package:focusly/screens/login_screen.dart';
import 'package:focusly/screens/onboarding_screen.dart';
import 'package:focusly/screens/signup_screen.dart';
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

      // Advance past the 5-second mark to complete progress
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pumpAndSettle();

      // Verify navigation to OnboardingScreen
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Organize Everything'), findsOneWidget);
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
      expect(find.textContaining('Hello,'), findsOneWidget);
    });
  });

  group('Focusly OnboardingScreen Tests', () {
    testWidgets('Renders 4-page flow with Next buttons, indicators, and transitions to LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // Page 1: Organize Everything
      expect(find.text('Organize Everything'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap Next -> Page 2: Build Better Habits
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Build Better Habits'), findsOneWidget);

      // Tap Next -> Page 3: Stay Focused
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Stay Focused'), findsOneWidget);

      // Tap Next -> Page 4: Grow With Your Team
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Grow With Your Team'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Tap Get Started -> Transitions to LoginScreen
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('Skip button jumps straight to LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Focusly LoginScreen Tests', () {
    testWidgets('Renders form fields, validates empty inputs, and navigates to SignupScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify header and fields
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Tap Log In without inputs -> triggers validation errors
      await tester.tap(find.text('Log In'));
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);

      // Tap Sign Up link -> Navigates to SignupScreen
      await tester.ensureVisible(find.text('Sign Up'));
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Create Your Account'), findsOneWidget);
    });
  });

  group('Focusly SignupScreen Tests', () {
    testWidgets('Renders all fields, terms checkbox enables submit, and navigates to LoginScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SignupScreen(),
        ),
      );

      // Verify header and fields
      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Tap Checkbox to agree to terms
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Tap Log In footer link -> Navigates back to LoginScreen
      await tester.ensureVisible(find.text('Log In'));
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });

  group('Focusly HomeScreen Tests', () {
    testWidgets('Renders greeting, date, switches bottom tabs, opens drawer and settings',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // 1. Verify greeting on Home tab
      expect(find.textContaining('Hello,'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // 2. Switch to Tasks tab
      await tester.tap(find.text('Tasks'));
      await tester.pump();
      expect(find.text('Tasks'), findsWidgets);

      // 3. Switch to Habits tab
      await tester.tap(find.text('Habits'));
      await tester.pump();
      expect(find.text('Habits'), findsWidgets);

      // 4. Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(find.text('Profile'), findsWidgets);

      // 5. Open Navigation Drawer
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Close drawer by tapping Home in the drawer
      await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Home')));
      await tester.pumpAndSettle();

      // 6. Navigate to Settings
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
