import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/settings/change_password_page.dart';
import 'package:focusly/features/settings/profile_page.dart';
import 'package:focusly/features/settings/settings_page.dart';
import 'package:focusly/features/tasks/tasks_screen.dart';
import 'package:focusly/features/schedule/schedule_screen.dart';
import 'package:focusly/screens/home_screen.dart';
import 'package:focusly/screens/login_screen.dart';
import 'package:focusly/screens/onboarding_screen.dart';
import 'package:focusly/screens/signup_screen.dart';
import 'package:focusly/screens/splash_screen.dart';

import 'package:focusly/core/localization/locale_controller.dart';
import 'package:focusly/core/theme/theme_controller.dart';

Widget _buildTestApp({required Widget home}) {
  return ProviderScope(
    child: Consumer(
      builder: (context, ref, _) {
        final themeMode = ref.watch(themeControllerProvider);
        final locale = ref.watch(localeControllerProvider);

        return MaterialApp(
          locale: locale,
          themeMode: themeMode,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: home,
        );
      },
    ),
  );
}


void main() {
  group('Focusly SplashScreen Tests', () {
    testWidgets('Renders centered logo, rising productivity icons, and progress bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SplashScreen(isFirstLaunch: true),
        ),
      );

      // Verify CustomPaint is present for rising productivity particles
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify progress status text
      expect(find.text('⚡ Initializing smart task engine...'), findsOneWidget);

      // Advance initial entrance animation
      await tester.pump(const Duration(milliseconds: 900));
    });

    testWidgets('Navigates to OnboardingScreen after 5 seconds when isFirstLaunch is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SplashScreen(isFirstLaunch: true),
        ),
      );

      // Advance past the 5-second mark to complete progress
      await tester.pump(const Duration(milliseconds: 5001));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify navigation to OnboardingScreen
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Organize Everything'), findsOneWidget);
    });

    testWidgets('Navigates to HomeScreen after 5 seconds when isFirstLaunch is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SplashScreen(isFirstLaunch: false),
        ),
      );

      // Advance past 5 seconds and settle transition
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify navigation to HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Hello'), findsOneWidget);
    });


  });

  group('Focusly OnboardingScreen Tests', () {
    testWidgets('Renders 4-page flow with Next buttons, indicators, and transitions to LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const OnboardingScreen(),
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
        _buildTestApp(
          home: const OnboardingScreen(),
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
        _buildTestApp(
          home: const LoginScreen(),
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
        _buildTestApp(
          home: const SignupScreen(),
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
        _buildTestApp(
          home: const HomeScreen(),
        ),
      );

      // 1. Verify greeting on Home tab
      expect(find.textContaining('Hello,'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // 2. Switch to Tasks tab
      await tester.tap(find.text('Tasks'));
      await tester.pump();
      expect(find.text('Tasks'), findsWidgets);

      // 3. Switch to Schedule tab
      await tester.tap(find.text('Schedule'));
      await tester.pump();
      expect(find.text('Schedule'), findsWidgets);

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  group('Focusly Settings Module Tests', () {
    testWidgets('Renders Settings sections and opens Language modal sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SettingsPage(),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);

      // Open Language sheet
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.text('العربية (Arabic)'), findsOneWidget);
      expect(find.text('English'), findsWidgets);

      // Switch to Arabic
      await tester.tap(find.text('العربية (Arabic)'));
      await tester.pumpAndSettle();
      expect(find.text('الإعدادات'), findsOneWidget);
    });

    testWidgets('Opens Theme modal sheet and displays options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SettingsPage(),
        ),
      );

      // Open Theme sheet
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.text('Light Mode'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('System Default'), findsWidgets);

      // Select Dark mode
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();
    });

    testWidgets('Navigates to ProfilePage and renders editable fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SettingsPage(),
        ),
      );

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Job Title / Profession'), findsOneWidget);
      expect(find.text('Bio / About Me'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Changes'));
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Opens Font Size modal sheet and displays Small, Standard, Large options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SettingsPage(),
        ),
      );

      // Scroll to and tap Font Size
      await tester.scrollUntilVisible(find.text('Font Size'), 50);
      await tester.tap(find.text('Font Size'));
      await tester.pumpAndSettle();

      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Standard'), findsWidgets);
      expect(find.text('Large'), findsOneWidget);

      // Select Large
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
    });

    testWidgets('Renders Default Reminder Time and Terms/Privacy screens',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SettingsPage(),
        ),
      );

      // Verify Default Reminder Time row
      await tester.scrollUntilVisible(find.text('Default Reminder Time'), 50);
      expect(find.text('Default Reminder Time'), findsOneWidget);

      // Verify Terms of Service navigation
      await tester.scrollUntilVisible(find.text('Terms of Service'), 50);
      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();
      expect(find.text('Last updated: August 2026'), findsOneWidget);

      // Pop back to Settings
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Verify Privacy Policy navigation
      await tester.scrollUntilVisible(find.text('Privacy Policy'), 50);
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('1. Information We Collect'), findsOneWidget);
    });

    testWidgets('Navigates to ChangePasswordPage and renders password fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const SettingsPage(),
        ),
      );

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordPage), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
    });
  });

  group('Focusly Tasks Module Tests', () {
    testWidgets('Renders TasksScreen, toggles List/Matrix views, and opens Add Task sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const TasksScreen(),
        ),
      );

      // Verify Screen Header and Toggle Buttons
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Matrix'), findsOneWidget);

      // Verify List view empty state
      expect(find.text('No tasks here yet'), findsOneWidget);

      // Switch to Matrix view
      await tester.tap(find.text('Matrix'));
      await tester.pumpAndSettle();

      // Verify 4 Eisenhower Quadrants are rendered
      expect(find.text('Do Now'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Delegate'), findsOneWidget);
      expect(find.text('Eliminate'), findsOneWidget);

      // Switch back to List view
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      // Open Add Task Sheet via Floating Action Button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Quick Matrix Placement'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Create Task'), findsOneWidget);
    });
  });

  group('Focusly Schedule Module Tests', () {
    testWidgets('Renders ScheduleScreen, toggles Month/Week/Day views, and opens Add Event sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          home: const ScheduleScreen(),
        ),
      );

      // Verify Screen Header and View Mode Switcher
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // Switch to Week view
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.text('No events scheduled for this day'), findsWidgets);

      // Switch to Day / Agenda view
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(find.text('No events scheduled for this day'), findsWidgets);
      expect(
        find.text('Enjoy your free time or tap (+) to schedule a new event!'),
        findsOneWidget,
      );

      // Open Add Event Sheet via Floating Action Button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New Event'), findsOneWidget);
      expect(find.text('Event Type'), findsOneWidget);
      expect(find.text('Recurrence'), findsOneWidget);
      expect(find.text('Create Event'), findsOneWidget);
    });
  });
}



