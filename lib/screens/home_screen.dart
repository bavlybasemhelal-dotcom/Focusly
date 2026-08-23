import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_colors.dart';
import '../features/settings/settings_page.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/pomodoro/pomodoro_screen.dart';
import '../features/progress/progress_screen.dart';
import 'login_screen.dart';

/// The main Home shell containing the AppBar, Drawer, BottomNavigationBar,
/// and tab view switching with rich Light and Dark mode aesthetics.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final drawerBg = isDark ? const Color(0xFF08123A) : Colors.white;
    final bottomBarBg = isDark ? const Color(0xFF0A1238) : Colors.white.withValues(alpha: 0.95);
    final borderColor = AppColors.border(context);

    // Current user reference from Firebase Authentication (safely wrapped for tests)
    String displayName = context.tr('there');
    String userEmail = 'user@focusly.com';

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.displayName != null &&
          currentUser!.displayName!.trim().isNotEmpty) {
        displayName = currentUser.displayName!;
      }
      if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
        userEmail = currentUser.email!;
      }
    } catch (_) {
      // Safe fallback if Firebase is not initialized in widget test environment
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,

      // -----------------------------------------------------------------------
      // 1. APP BAR (Glassmorphic in Dark / Frosted Glow in Light)
      // -----------------------------------------------------------------------
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const SizedBox.shrink(),
        leading: Builder(
          builder: (builderContext) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(start: 16.0),
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F1B4C).withValues(alpha: 0.6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFDBEAFE),
                      width: 1.2,
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF2E6FF2).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.menu_rounded,
                      color: brandPrimary,
                      size: 22,
                    ),
                    onPressed: () {
                      Scaffold.of(builderContext).openDrawer();
                    },
                    tooltip: 'Open navigation menu',
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16.0),
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F1B4C).withValues(alpha: 0.6)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFDBEAFE),
                    width: 1.2,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                            BoxShadow(
                              color: const Color(0xFF2E6FF2).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.settings_outlined,
                    color: brandPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  tooltip: 'Settings',
                ),
              ),
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // 2. NAVIGATION DRAWER (Midnight Neon / Radiant Brand Blue Header)
      // -----------------------------------------------------------------------
      drawer: Drawer(
        backgroundColor: drawerBg,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Drawer Header with User Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 64, 22, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF08123A), const Color(0xFF0B1647)]
                        : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Circle
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF0F1B4C)
                            : Colors.white,
                        border: Border.all(
                          color: isDark ? AppColors.cyanElectric : const Color(0xFF93C5FD),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? AppColors.cyanElectric.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName.substring(0, 1).toUpperCase()
                              : 'F',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.cyanElectric : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User Display Name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // User Email
                    Text(
                      userEmail,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFFDBEAFE),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Navigation Menu Items
              _buildDrawerItem(
                context: context,
                icon: Icons.home_rounded,
                title: context.tr('home'),
                isSelected: _currentTabIndex == 0,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentTabIndex = 0;
                  });
                },
              ),
              _buildDrawerItem(
                context: context,
                icon: Icons.check_circle_outline_rounded,
                title: context.tr('tasks'),
                isSelected: _currentTabIndex == 1,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentTabIndex = 1;
                  });
                },
              ),
              _buildDrawerItem(
                context: context,
                icon: Icons.calendar_month_outlined,
                title: context.tr('schedule'),
                isSelected: _currentTabIndex == 2,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentTabIndex = 2;
                  });
                },
              ),
              _buildDrawerItem(
                context: context,
                icon: Icons.local_fire_department_outlined,
                title: context.tr('habits'),
                isSelected: _currentTabIndex == 3,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentTabIndex = 3;
                  });
                },
              ),
              _buildDrawerItem(
                context: context,
                icon: Icons.timer_outlined,
                title: context.tr('pomodoro'),
                isSelected: _currentTabIndex == 4,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentTabIndex = 4;
                  });
                },
              ),
              _buildDrawerItem(
                context: context,
                icon: Icons.insights_rounded,
                title: context.tr('progress'),
                isSelected: _currentTabIndex == 5,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentTabIndex = 5;
                  });
                },
              ),
              _buildDrawerItem(
                context: context,
                icon: Icons.settings_outlined,
                title: context.tr('settings'),
                isSelected: false,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Divider(color: borderColor, height: 1),
              ),

              const Spacer(),

              // Log Out Item
              _buildDrawerItem(
                context: context,
                icon: Icons.logout_rounded,
                title: context.tr('log_out'),
                isSelected: false,
                isDestructive: true,
                onTap: _confirmLogout,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // 3. BODY (Atmospheric Light/Dark Aurora Glows + IndexedStack)
      // -----------------------------------------------------------------------
      body: Stack(
        children: [
          // Ambient Aurora Background Blooms
          _buildAmbientGlowBlooms(isDark),

          // IndexedStack Content
          IndexedStack(
            index: _currentTabIndex,
            children: [
              _HomeTabContent(userName: displayName),
              const TasksScreen(),
              const ScheduleScreen(),
              const HabitsScreen(),
              const PomodoroScreen(),
              const ProgressScreen(),
              const _ProfileTabPlaceholder(),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // 4. BOTTOM NAVIGATION BAR (Vibrant Frosted Pill Navigation)
      // -----------------------------------------------------------------------
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bottomBarBg,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F5),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFF2E6FF2).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: brandPrimary,
          unselectedItemColor: secondaryTextColor,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: context.tr('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.check_circle_outline_rounded),
              activeIcon: const Icon(Icons.check_circle_rounded),
              label: context.tr('tasks'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month_rounded),
              label: context.tr('schedule'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.local_fire_department_outlined),
              activeIcon: const Icon(Icons.local_fire_department_rounded),
              label: context.tr('habits'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.timer_outlined),
              activeIcon: const Icon(Icons.timer_rounded),
              label: context.tr('pomodoro'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.insights_outlined),
              activeIcon: const Icon(Icons.insights_rounded),
              label: context.tr('progress'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: context.tr('profile'),
            ),
          ],
        ),
      ),
    );
  }

  /// Ambient background aurora light-blooms
  Widget _buildAmbientGlowBlooms(bool isDark) {
    final cyanGlow = isDark
        ? AppColors.cyanElectric.withValues(alpha: 0.16)
        : const Color(0xFF38BDF8).withValues(alpha: 0.18);
    final greenGlow = isDark
        ? AppColors.accentGreenNeon.withValues(alpha: 0.14)
        : const Color(0xFF34D399).withValues(alpha: 0.16);

    return Stack(
      children: [
        Positioned(
          top: -90,
          right: -90,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [cyanGlow, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -70,
          left: -70,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [greenGlow, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Drawer Menu Item Builder
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);

    final Color itemColor = isDestructive
        ? AppColors.errorRed
        : (isSelected ? brandPrimary : secondaryTextColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? brandPrimary.withValues(alpha: 0.14)
                : const Color(0xFFEFF6FF))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isSelected && !isDark
            ? Border.all(color: const Color(0xFFBFDBFE), width: 1)
            : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: itemColor, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isDestructive
                ? AppColors.errorRed
                : (isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1D4ED8))
                    : secondaryTextColor),
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: onTap,
      ),
    );
  }

  /// Shows confirmation dialog before logging out
  Future<void> _confirmLogout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0xFFE2E8F5),
              width: 1.2,
            ),
          ),
          title: Text(
            context.tr('log_out_confirm_title'),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: primaryTextColor,
              fontSize: 20,
            ),
          ),
          content: Text(
            context.tr('log_out_confirm_message'),
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                context.tr('cancel'),
                style: TextStyle(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.tr('log_out'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }
}

// ==============================================================================
// TAB 0: VIBRANT HOME GREETING & WORKSPACE HERO
// ==============================================================================
class _HomeTabContent extends StatelessWidget {
  final String userName;

  const _HomeTabContent({required this.userName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final localizedDate = AppLocalizations.of(context).formatLocalizedDate(DateTime.now());

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting Header
            Text(
              '${context.tr('hello_greeting')}, $userName 👋',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),

            // Date Badge Pill with Radiant Border & Soft Gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isDark
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFF0F6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isDark ? const Color(0xFF0F1B4C).withValues(alpha: 0.6) : null,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFBFDBFE),
                  width: 1.2,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF2E6FF2).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localizedDate,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Radiant Focus Workspace Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF0F1B4C), Color(0xFF0B1647)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? AppColors.cyanElectric.withValues(alpha: 0.25)
                      : const Color(0xFF93C5FD),
                  width: 1.4,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF2E6FF2).withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF1E58F6)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? AppColors.cyanElectric.withValues(alpha: 0.4)
                              : const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('focus_workspace_ready'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
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

// ==============================================================================
// PLACEHOLDER TAB 3: PROFILE
// ==============================================================================
class _ProfileTabPlaceholder extends StatelessWidget {
  const _ProfileTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.tr('profile'),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }
}
