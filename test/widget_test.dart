import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:focusly/core/data/firestore_provider.dart';
import 'package:focusly/features/productivity/productivity_page.dart';
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
import 'package:focusly/features/habits/habits_screen.dart';
import 'package:focusly/features/pomodoro/pomodoro_screen.dart';
import 'package:focusly/features/groups/models/group_model.dart';
import 'package:focusly/features/groups/providers/groups_provider.dart';
import 'package:focusly/features/groups/groups_home_page.dart';
import 'package:focusly/features/groups/group_detail_page.dart';
import 'package:focusly/features/progress/progress_screen.dart';
import 'package:focusly/screens/home_screen.dart';
import 'package:focusly/screens/login_screen.dart';
import 'package:focusly/screens/onboarding_screen.dart';
import 'package:focusly/screens/signup_screen.dart';
import 'package:focusly/screens/splash_screen.dart';

import 'package:focusly/core/localization/locale_controller.dart';
import 'package:focusly/core/theme/theme_controller.dart';

Widget _buildTestApp({
  required Widget home,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.isEmpty ? const [] : overrides.cast(),
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
    testWidgets(
      'Renders centered logo, rising productivity icons, and progress bar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildTestApp(home: const SplashScreen(isFirstLaunch: true)),
        );

        // Verify CustomPaint is present for rising productivity particles
        expect(find.byType(CustomPaint), findsWidgets);

        // Verify progress status text
        expect(
          find.text('⚡ Initializing smart task engine...'),
          findsOneWidget,
        );

        // Advance initial entrance animation
        await tester.pump(const Duration(milliseconds: 900));
      },
    );

    testWidgets(
      'Navigates to OnboardingScreen after 5 seconds when isFirstLaunch is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildTestApp(home: const SplashScreen(isFirstLaunch: true)),
        );

        // Advance past the 5-second mark to complete progress
        await tester.pump(const Duration(milliseconds: 5001));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 700));

        // Verify navigation to OnboardingScreen
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.text('Organize Everything'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigates to LoginScreen when the restored session is signed out',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildTestApp(home: const SplashScreen(isFirstLaunch: false)),
        );

        // Advance past 5 seconds and settle transition
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pump(const Duration(milliseconds: 2600));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // The home route must not bypass authentication.
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Welcome Back'), findsOneWidget);
      },
    );
  });

  group('Focusly OnboardingScreen Tests', () {
    testWidgets(
      'Renders 4-page flow with Next buttons, indicators, and transitions to LoginScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const OnboardingScreen()));

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
      },
    );

    testWidgets('Skip button jumps straight to LoginScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(home: const OnboardingScreen()));

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Focusly LoginScreen Tests', () {
    testWidgets(
      'Renders form fields, validates empty inputs, and navigates to SignupScreen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildTestApp(home: const LoginScreen()));

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
      },
    );
  });

  group('Focusly SignupScreen Tests', () {
    testWidgets(
      'Renders all fields, terms checkbox enables submit, and navigates to LoginScreen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildTestApp(home: const SignupScreen()));

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
      },
    );
  });

  group('Focusly HomeScreen Tests', () {
    testWidgets(
      'Ctrl+D opens My Day immediately without first focusing a control',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            home: const HomeScreen(),
            overrides: [
              firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.byType(ProductivityPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Renders greeting, date, switches bottom tabs, opens drawer and settings',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const HomeScreen()));

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

        // 4. Switch to Habits tab
        await tester.tap(find.text('Habits'));
        await tester.pump();
        expect(find.text('Habits'), findsWidgets);

        // 5. Switch to Pomodoro tab
        await tester.tap(find.text('Pomodoro'));
        await tester.pump();
        expect(find.text('Pomodoro'), findsWidgets);

        // 6. Switch to Groups tab
        await tester.tap(find.text('Groups'));
        await tester.pump();
        expect(find.text('Groups'), findsWidgets);

        // 7. Switch to Progress tab
        await tester.tap(find.text('Progress'));
        await tester.pump();
        expect(find.text('Progress'), findsWidgets);

        // 8. Switch to Profile tab
        await tester.tap(find.text('Profile'));
        await tester.pump();
        expect(find.text('Profile'), findsWidgets);

        // 9. Open Navigation Drawer
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsOneWidget);
        expect(find.text('Log Out'), findsOneWidget);

        // Close drawer by tapping Home in the drawer
        await tester.tap(
          find.descendant(of: find.byType(Drawer), matching: find.text('Home')),
        );
        await tester.pumpAndSettle();

        // 7. Navigate to Settings
        await tester.tap(find.byTooltip('Settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(SettingsPage), findsOneWidget);
      },
    );
  });

  group('Focusly Settings Module Tests', () {
    testWidgets('Renders Settings sections and opens Language modal sheet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(home: const SettingsPage()));

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

    testWidgets('Opens Theme modal sheet and displays options', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(home: const SettingsPage()));

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

    testWidgets('Navigates to ProfilePage and renders editable fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(home: const SettingsPage()));

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

    testWidgets(
      'Opens Font Size modal sheet and displays Small, Standard, Large options',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const SettingsPage()));

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
      },
    );

    testWidgets('Renders Default Reminder Time and Terms/Privacy screens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(home: const SettingsPage()));

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

    testWidgets('Navigates to ChangePasswordPage and renders password fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(home: const SettingsPage()));

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
    testWidgets(
      'Renders TasksScreen, toggles List/Matrix views, and opens Add Task sheet',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const TasksScreen()));

        // Verify Screen Header and Toggle Buttons
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.text('List'), findsOneWidget);
        expect(find.text('Matrix'), findsOneWidget);

        // Verify List view empty state
        await tester.pumpAndSettle();
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
      },
    );
  });

  group('Focusly Schedule Module Tests', () {
    testWidgets(
      'Renders ScheduleScreen, toggles Month/Week/Day views, and opens Add Event sheet',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const ScheduleScreen()));

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
      },
    );
  });

  group('Focusly Habits Module Tests', () {
    testWidgets(
      'Renders HabitsScreen, stat summary cards, and opens Add Habit sheet',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const HabitsScreen()));
        await tester.pump();

        // Verify Header Title & Subtitle
        expect(find.text('Habits'), findsOneWidget);
        expect(
          find.text('Build streaks & anchor daily routines'),
          findsOneWidget,
        );

        // Verify Stat Summary Cards
        expect(find.text('Total Habits'), findsOneWidget);
        expect(find.text('Longest Streak'), findsOneWidget);
        expect(find.text('Total Days'), findsOneWidget);

        // Verify Empty State
        expect(find.text('No habits created yet'), findsOneWidget);
        expect(
          find.text(
            'Start small and build unstoppable momentum with daily habit streaks!',
          ),
          findsOneWidget,
        );

        // Open Add Habit Sheet via Floating Action Button
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('New Habit'), findsOneWidget);
        expect(find.text('Habit Stacking Cue (Optional)'), findsOneWidget);
        expect(find.text('Daily Reminder Time (Optional)'), findsOneWidget);
        expect(find.text('Create Habit'), findsOneWidget);
      },
    );
  });

  group('Focusly Pomodoro Module Tests', () {
    testWidgets(
      'Renders PomodoroScreen, circular ring, controls, and opens settings sheet',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const PomodoroScreen()));
        await tester.pump();

        // Verify Header Title & Subtitle
        expect(find.text('Pomodoro'), findsOneWidget);
        expect(find.text('Focus cycles & deep work'), findsOneWidget);

        // Verify Circular Ring MM:SS and Phase Badge
        expect(find.text('25:00'), findsOneWidget);
        expect(find.text('Focus Time'), findsOneWidget);

        // Verify Link Task chip
        expect(find.text('Link a task (Optional)'), findsOneWidget);

        // Verify Today's Stats & Weekly Chart
        expect(find.textContaining('sessions today'), findsOneWidget);
        expect(find.textContaining('minutes focused today'), findsOneWidget);
        expect(find.text('Weekly Focus Activity'), findsOneWidget);

        // Verify Action Controls (Play, Reset, Skip)
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
        expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

        // Open Settings Sheet
        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Pomodoro Settings'), findsOneWidget);
        expect(find.text('Focus Duration'), findsOneWidget);
        expect(find.text('Short Break Duration'), findsOneWidget);
        expect(find.text('Long Break Duration'), findsOneWidget);
        expect(find.text('Sessions Until Long Break'), findsOneWidget);
        expect(find.text('Auto-start Next Phase'), findsOneWidget);
        expect(find.text('Save Settings'), findsOneWidget);
      },
    );
  });

  group('Focusly Progress & Achievements Module Tests', () {
    testWidgets(
      'Renders ProgressScreen, Level header card, Overview stats, and switches to Achievements tab',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const ProgressScreen()));
        await tester.pump();

        // Verify Header Title & Subtitle
        expect(find.text('Progress & Achievements'), findsOneWidget);
        expect(find.text('Level up your daily momentum'), findsOneWidget);

        // Verify Level Header Card (Level 1, Beginner, 0 total XP)
        expect(find.text('Level 1'), findsOneWidget);
        expect(find.text('Beginner'), findsOneWidget);
        expect(find.text('0 total XP'), findsOneWidget);

        // Verify Overview Sub-tab Components
        expect(find.text('Tasks Completed'), findsOneWidget);
        expect(find.text('Longest Streak'), findsOneWidget);
        expect(find.text('Pomodoro Sessions'), findsOneWidget);
        expect(find.text('Total Focus Time'), findsOneWidget);
        expect(find.text('Weekly Productivity Score'), findsOneWidget);

        // Switch to Achievements Sub-tab
        await tester.tap(find.text('Achievements'));
        await tester.pumpAndSettle();

        // Verify Achievement Category Headers
        expect(find.text('Tasks'), findsWidgets);
        expect(find.text('Habits'), findsWidgets);
        expect(find.text('Pomodoro'), findsWidgets);
        expect(find.text('Events'), findsWidgets);
        expect(find.text('XP & Levels'), findsWidgets);
        expect(find.text('Organization'), findsWidgets);
        expect(find.text('Special'), findsWidgets);

        // Verify Achievement Badges Rendered
        expect(find.text('First Step'), findsOneWidget);
        expect(find.text('High Five'), findsOneWidget);
        expect(find.text('New Habit'), findsOneWidget);
        expect(find.text('First Focus'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping View XP History opens XpHistoryPage with level guide and breakdown',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const ProgressScreen()));
        await tester.pump();

        // Tap View XP History button
        expect(find.text('View XP History'), findsOneWidget);
        await tester.tap(find.text('View XP History'));
        await tester.pumpAndSettle();

        // Verify XpHistoryPage rendered
        expect(find.text('XP History & Breakdown'), findsOneWidget);
        expect(find.text('How to Earn XP'), findsOneWidget);
        expect(
          find.text('Standard XP rewards across Focusly features:'),
          findsOneWidget,
        );
        expect(find.text('Complete a Task'), findsOneWidget);
        expect(find.text('Check off a Daily Habit'), findsOneWidget);
        expect(find.text('Full Pomodoro Session (25 min)'), findsOneWidget);
        expect(find.text('Recent XP Activity'), findsOneWidget);
      },
    );
  });

  group('Focusly Groups & Challenges Module Tests', () {
    testWidgets(
      'Renders GroupsHomePage, action buttons, and opens Create & Join modals',
      (WidgetTester tester) async {
        await tester.pumpWidget(_buildTestApp(home: const GroupsHomePage()));
        await tester.pump();

        // Verify Screen Header
        expect(find.text('Groups & Challenges'), findsOneWidget);
        expect(
          find.text('Collaborate, compete, and level up together'),
          findsOneWidget,
        );

        // Verify Action Buttons
        expect(find.text('Create Group'), findsOneWidget);
        expect(find.text('Join Group'), findsOneWidget);

        // Open Create Group Sheet
        await tester.tap(find.text('Create Group'));
        await tester.pumpAndSettle();

        expect(find.text('Create New Group'), findsOneWidget);
        expect(find.text('Group Icon'), findsOneWidget);
        expect(find.text('Group Name'), findsOneWidget);
        expect(find.text('Description (Optional)'), findsOneWidget);

        // Close Create Group sheet
        Navigator.of(tester.element(find.text('Create New Group'))).pop();
        await tester.pumpAndSettle();

        // Open Join Group Sheet
        await tester.tap(find.text('Join Group'));
        await tester.pumpAndSettle();

        expect(find.text('Join a Group'), findsOneWidget);
        expect(find.text('Invite Code'), findsOneWidget);
        expect(find.text('Send Join Request'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders GroupDetailPage and switches across Feed, Leaderboard, Challenges, Members tabs',
      (WidgetTester tester) async {
        final mockGroup = GroupModel(
          id: 'test_group_123',
          name: 'Morning Squad',
          icon: '🚀',
          description: 'Focus and Win',
          inviteCode: 'GRP-TEST99',
          createdBy: 'user_1',
          createdAt: DateTime.now(),
          memberCount: 5,
        );

        await tester.pumpWidget(
          _buildTestApp(
            overrides: [
              groupDetailStreamProvider(
                'test_group_123',
              ).overrideWith((ref) => Stream.value(mockGroup)),
              groupFeedStreamProvider(
                'test_group_123',
              ).overrideWith((ref) => Stream.value([])),
              groupMembersStreamProvider(
                'test_group_123',
              ).overrideWith((ref) => Stream.value([])),
              groupChallengesStreamProvider(
                'test_group_123',
              ).overrideWith((ref) => Stream.value([])),
            ],
            home: const GroupDetailPage(groupId: 'test_group_123'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Group Title and 4 Tab Headers
        expect(find.text('Morning Squad'), findsOneWidget);
        expect(find.text('Feed'), findsOneWidget);
        expect(find.text('Leaderboard'), findsOneWidget);
        expect(find.text('Challenges'), findsOneWidget);
        expect(find.text('Members'), findsOneWidget);

        // Switch to Leaderboard
        await tester.tap(find.text('Leaderboard'));
        await tester.pump();
        expect(find.text('Leaderboard'), findsOneWidget);

        // Switch to Challenges
        await tester.tap(find.text('Challenges'));
        await tester.pump();
        expect(find.text('Challenges'), findsOneWidget);

        // Switch to Members
        await tester.tap(find.text('Members'));
        await tester.pump();
        expect(find.text('Members'), findsOneWidget);
      },
    );
  });
}
