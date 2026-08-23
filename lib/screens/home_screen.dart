import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_provider.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_colors.dart';
import '../features/settings/settings_page.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/pomodoro/pomodoro_screen.dart';
import '../features/groups/groups_home_page.dart';
import '../features/progress/progress_screen.dart';
import '../features/gtd/inbox_screen.dart';
import '../features/gtd/providers/gtd_provider.dart';
import '../features/gtd/reference_screen.dart';
import '../features/gtd/someday_screen.dart';
import '../features/gtd/waiting_screen.dart';
import '../features/contacts/contacts_page.dart';
import '../features/contacts/widgets/home_contacts_widget.dart';
import '../features/energy_mood/energy_mood_history_page.dart';
import '../features/energy_mood/widgets/home_energy_mood_widget.dart';
import '../features/gtd/widgets/quick_capture_sheet.dart';
import '../features/para/areas_page.dart';
import '../features/para/archive_page.dart';
import '../features/para/para_guide_page.dart';
import '../features/para/projects_page.dart';
import '../features/para/resources_page.dart';
import 'login_screen.dart';

/// The main Home shell containing the AppBar, Drawer, BottomNavigationBar,
/// and tab view switching with rich Light and Dark mode aesthetics.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

    final User? currentUser = ref.watch(currentUserProvider);
    if (currentUser?.displayName != null &&
        currentUser!.displayName!.trim().isNotEmpty) {
      displayName = currentUser.displayName!;
    }
    if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      userEmail = currentUser.email!;
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
          // Quick Capture Action Button
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8.0),
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E6FF2), Color(0xFF00D2FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E6FF2).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => QuickCaptureSheet.show(context),
                  tooltip: context.tr('quick_capture_title'),
                ),
              ),
            ),
          ),
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
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
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
                      width: 52,
                      height: 52,
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
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.cyanElectric : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // User Display Name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // User Email
                    Text(
                      userEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFFDBEAFE),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Navigation Menu Items
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
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
                        icon: Icons.groups_rounded,
                        title: context.tr('groups'),
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
                        icon: Icons.insights_rounded,
                        title: context.tr('progress'),
                        isSelected: _currentTabIndex == 6,
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentTabIndex = 6;
                          });
                        },
                      ),

                      // -------------------------------------------------------
                      // GTD PRODUCTIVITY SYSTEM SECTION
                      // -------------------------------------------------------
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('gtd_section_header'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F5),
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.inbox_rounded,
                        title: context.tr('inbox'),
                        isSelected: false,
                        badgeCount: ref.watch(unprocessedInboxCountProvider),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const InboxScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.hourglass_top_rounded,
                        title: context.tr('waiting_for'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const WaitingScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.nightlight_round,
                        title: context.tr('someday_maybe'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SomedayScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.bookmark_outline_rounded,
                        title: context.tr('reference'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ReferenceScreen(),
                            ),
                          );
                        },
                      ),

                      // -------------------------------------------------------
                      // PARA ORGANIZATIONAL SYSTEM SECTION
                      // -------------------------------------------------------
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('para_section_header'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F5),
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.folder_special_rounded,
                        title: context.tr('para_projects_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ProjectsPage(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.domain_rounded,
                        title: context.tr('para_areas_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AreasPage(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.source_rounded,
                        title: context.tr('para_resources_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ResourcesPage(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.inventory_2_rounded,
                        title: context.tr('para_archive_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ArchivePage(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.menu_book_rounded,
                        title: context.tr('para_guide_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ParaGuidePage(),
                            ),
                          );
                        },
                      ),

                      // -------------------------------------------------------
                      // WELLNESS SECTION
                      // -------------------------------------------------------
                      // TODO: Future wellness features (Daily Rituals, Mood Journal, Mindfulness) should join this same section.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('wellness_section_header'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F5),
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.bolt_rounded,
                        title: context.tr('energy_mood_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const EnergyMoodHistoryPage(),
                            ),
                          );
                        },
                      ),

                      // =========================================================
                      // SECTION: RELATIONSHIPS
                      // TODO: Relationship Health, Social Battery, and Gratitude Log features will join this same Relationships section when built.
                      // =========================================================
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('relationships_section_header'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F5),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.people_alt_rounded,
                        title: context.tr('contacts_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ContactsPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 6),
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
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: Divider(color: borderColor, height: 1),
              ),

              // Log Out Item
              _buildDrawerItem(
                context: context,
                icon: Icons.logout_rounded,
                title: context.tr('log_out'),
                isSelected: false,
                isDestructive: true,
                onTap: _confirmLogout,
              ),
              const SizedBox(height: 12),
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
              const GroupsHomePage(),
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
              icon: const Icon(Icons.groups_outlined),
              activeIcon: const Icon(Icons.groups_rounded),
              label: context.tr('groups'),
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
    int? badgeCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);

    final Color itemColor = isDestructive
        ? AppColors.errorRed
        : (isSelected ? brandPrimary : secondaryTextColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
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
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        minLeadingWidth: 26,
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
        trailing: (badgeCount != null && badgeCount > 0)
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E6FF2), Color(0xFF00D2FF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E6FF2).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              )
            : null,
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
      await logoutAndClearSession(ref);

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting Header & Date Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily Check-in & Energy Mood Banner/Summary Widget
            const HomeEnergyMoodWidget(),
            const SizedBox(height: 8),

            // People to Reach Out To (Personal CRM Overdue Widget)
            const HomeContactsWidget(),
            const SizedBox(height: 12),

            // Radiant Focus Workspace Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
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
