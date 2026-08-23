import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';

// ==============================================================================
// FOCUSLY COLOR PALETTE (Matched with Splash, Onboarding, Login & Signup)
// ==============================================================================
const Color kBgDark = Color(0xFF060B24);
const Color kBgMidnight = Color(0xFF0B1647);
const Color kNavyDeep = Color(0xFF08123A);
const Color kCyanElectric = Color(0xFF00E5FF);
const Color kBlueSky = Color(0xFF29A9FF);
const Color kBlueRoyal = Color(0xFF1E58F6);
const Color kGreenNeon = Color(0xFF4ADE80);
const Color kGreenVibrant = Color(0xFF22C55E);
const Color kAmberGold = Color(0xFFFFB020);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextSlate = Color(0xFF94A3B8);
const Color kErrorRed = Color(0xFFE5484D);

/// The main Home shell containing the AppBar, Drawer, BottomNavigationBar,
/// and tab view switching styled with the midnight-neon aesthetic.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Current user reference from Firebase Authentication (safely wrapped for tests)
    String displayName = 'there';
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
      backgroundColor: kBgDark,

      // -----------------------------------------------------------------------
      // 1. APP BAR (Glassmorphic & Transparent)
      // -----------------------------------------------------------------------
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const SizedBox.shrink(),
        leading: Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1B4C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: kCyanElectric,
                      size: 22,
                    ),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
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
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1B4C).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: kCyanElectric,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
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
      // 2. NAVIGATION DRAWER (Midnight Glassmorphic Style)
      // -----------------------------------------------------------------------
      drawer: Drawer(
        backgroundColor: const Color(0xFF08123A),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Drawer Header with User Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kNavyDeep, kBgMidnight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Circle
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F1B4C),
                        border: Border.all(
                          color: kCyanElectric,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kCyanElectric.withValues(alpha: 0.3),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName.substring(0, 1).toUpperCase()
                              : 'F',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: kCyanElectric,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // User Display Name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: kTextWhite,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // User Email
                    Text(
                      userEmail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: kTextSlate,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Navigation Menu Items
              _buildDrawerItem(
                icon: Icons.home_rounded,
                title: 'Home',
                isSelected: _currentTabIndex == 0,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentTabIndex = 0;
                  });
                },
              ),
              _buildDrawerItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                isSelected: false,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  height: 1,
                ),
              ),

              const Spacer(),

              // Log Out Item
              _buildDrawerItem(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                isSelected: false,
                isDestructive: true,
                onTap: _confirmLogout,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // 3. BODY (IndexedStack + Ambient Aurora Glows)
      // -----------------------------------------------------------------------
      body: Stack(
        children: [
          // Ambient Aurora Background Blooms
          _buildAmbientGlowBlooms(),

          // IndexedStack Content
          IndexedStack(
            index: _currentTabIndex,
            children: [
              _HomeTabContent(userName: displayName),
              const _TasksTabPlaceholder(),
              const _HabitsTabPlaceholder(),
              const _ProfileTabPlaceholder(),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // 4. BOTTOM NAVIGATION BAR (Midnight Glow Style)
      // -----------------------------------------------------------------------
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1238),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
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
          selectedItemColor: kCyanElectric,
          unselectedItemColor: kTextSlate,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline_rounded),
              activeIcon: Icon(Icons.check_circle_rounded),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_fire_department_outlined),
              activeIcon: Icon(Icons.local_fire_department_rounded),
              label: 'Habits',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  /// Ambient background aurora light-blooms
  Widget _buildAmbientGlowBlooms() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kCyanElectric.withValues(alpha: 0.16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -60,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kGreenNeon.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Drawer Menu Item Builder
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color itemColor = isDestructive
        ? kErrorRed
        : (isSelected ? kCyanElectric : kTextSlate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: isSelected
            ? kCyanElectric.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: itemColor, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isDestructive ? kErrorRed : (isSelected ? kTextWhite : kTextSlate),
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }

  /// Shows confirmation dialog styled with dark midnight theme before logging out
  Future<void> _confirmLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1B4C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: kTextWhite,
              fontSize: 20,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out of Focusly?',
            style: TextStyle(
              color: kTextSlate,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: kTextSlate,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kErrorRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      // 1. Sign out of Firebase
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      if (!mounted) return;

      // 2. Navigate back to LoginScreen and clear entire navigation stack
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
// TAB 0: MINIMAL HOME GREETING CONTENT (Midnight-Neon Themed)
// ==============================================================================
class _HomeTabContent extends StatelessWidget {
  final String userName;

  const _HomeTabContent({required this.userName});

  /// Formats current date into e.g. "Sunday, August 23"
  String _getFormattedDate() {
    final now = DateTime.now();
    const weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekday = weekdayNames[now.weekday - 1];
    final month = monthNames[now.month - 1];
    return '$weekday, $month ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    // TODO: This Home content is an intentionally minimal placeholder.
    // Redesign with task summary cards, productivity stats, and active habits
    // once the core feature modules are implemented.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting Header
            Text(
              'Hello, $userName 👋',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: kTextWhite,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 8),

            // Date Badge Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B4C).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: kCyanElectric,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getFormattedDate(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextSlate,
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
// PLACEHOLDER TAB 1: TASKS
// ==============================================================================
class _TasksTabPlaceholder extends StatelessWidget {
  const _TasksTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with full Tasks list, filter tabs, and creation flows
    return const Center(
      child: Text(
        'Tasks',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: kTextWhite,
        ),
      ),
    );
  }
}

// ==============================================================================
// PLACEHOLDER TAB 2: HABITS
// ==============================================================================
class _HabitsTabPlaceholder extends StatelessWidget {
  const _HabitsTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with Habit tracking heatmaps, streak rings, and daily check-ins
    return const Center(
      child: Text(
        'Habits',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: kTextWhite,
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
    // TODO: Replace with user profile statistics, badges, and account options
    return const Center(
      child: Text(
        'Profile',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: kTextWhite,
        ),
      ),
    );
  }
}

// ==============================================================================
// SETTINGS SCREEN PLACEHOLDER (Midnight-Neon Themed)
// ==============================================================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Build full app settings, notifications, theme, and data management
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: kTextWhite,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kCyanElectric),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(
        child: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            color: kTextSlate,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
