import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../features/goals/life_map_page.dart';
import '../features/gtd/widgets/quick_capture_sheet.dart';
import '../features/para/areas_page.dart';
import '../features/time_audit/time_audit_page.dart';
import '../features/para/archive_page.dart';
import '../features/para/para_guide_page.dart';
import '../features/para/projects_page.dart';
import '../features/para/resources_page.dart';
import '../features/rituals/daily_rituals_page.dart';
import '../features/rituals/providers/rituals_provider.dart';
import '../features/rituals/widgets/morning_intention_banner.dart';
import '../features/rituals/widgets/morning_intention_modal.dart';
import '../features/rituals/widgets/shutdown_wizard_modal.dart';
import '../features/weekly_review/providers/weekly_review_provider.dart';
import '../features/weekly_review/widgets/weekly_review_wizard.dart';
import '../features/focus_mode/focus_mode_page.dart';
import '../features/time_blocker/time_blocker_page.dart';
import '../features/decision_journal/decision_journal_page.dart';
import '../features/project_retrospective/retrospective_page.dart';
import '../features/reading_tracker/books_shelves_page.dart';
import '../features/skills/skills_board_page.dart';
import '../features/learning_paths/learning_paths_page.dart';
import '../features/knowledge_base/knowledge_base_page.dart';
import '../features/course_tracker/course_tracker_page.dart';
import '../features/spaced_repetition/flashcards_list_page.dart';
import '../features/relationship_health/relationship_health_page.dart';
import '../features/social_battery/social_battery_page.dart';
import '../features/workout_tracker/workout_tracker_page.dart';
import '../features/nutrition_log/nutrition_log_page.dart';
import '../features/body_metrics/body_metrics_page.dart';
import '../features/mental_health/mental_health_page.dart';
import '../features/budget_tracker/budget_tracker_page.dart';
import '../features/life_analytics/life_analytics_page.dart';
import '../features/life_score/life_score_detail_page.dart';
import '../features/pdf_reports/report_range_page.dart';
import '../features/life_areas/life_areas_page.dart';
import '../features/bucket_list/bucket_list_page.dart';
import '../features/legacy_journal/legacy_journal_page.dart';
import '../features/annual_review/annual_review_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/settings/profile_page.dart';
import '../features/focus_mode/focus_mode_page.dart';
import '../features/home/widgets/continue_reading_widget.dart';
import '../features/home/widgets/groups_preview_widget.dart';
import '../features/home/widgets/home_life_score_widget.dart';
import '../features/home/widgets/home_weekly_review_due_banner.dart';
import '../features/home/widgets/level_xp_compact_widget.dart';
import '../features/home/widgets/quick_actions_row.dart';
import '../features/home/widgets/todays_focus_card.dart';
import '../features/home/widgets/todays_habits_row.dart';
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
  bool _promptChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMorningIntentionPrompt());
  }

  Future<void> _checkMorningIntentionPrompt() async {
    if (_promptChecked || !mounted) return;
    _promptChecked = true;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final promptSetting = ref.read(morningIntentionPromptSettingProvider);
    if (!promptSetting) return;

    // Asynchronously verify persisted calendar date (YYYY-MM-DD) from disk/Firestore
    // to avoid the initial in-memory race condition where false was returned before I/O finished.
    final alreadyShown = await ref
        .read(morningIntentionDismissedProvider.notifier)
        .hasBeenShownToday();
    if (alreadyShown || !mounted) return;

    // Direct check if an intention is already recorded for today in Firestore
    final todayStr = ref.read(todayDateStringProvider);
    final ritual = await ref.read(ritualsServiceProvider).getTodayRitual(uid, todayStr);
    if (ritual != null && ritual.hasIntention) {
      await ref.read(morningIntentionDismissedProvider.notifier).markShownToday();
      return;
    }

    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;

      final recheck = await ref
          .read(morningIntentionDismissedProvider.notifier)
          .hasBeenShownToday();
      if (recheck || !mounted) return;

      // Persist that the prompt has been shown today IMMEDIATELY before displaying the modal
      await ref.read(morningIntentionDismissedProvider.notifier).markShownToday();
      if (mounted) {
        MorningIntentionModal.show(context);
      }
    });
  }

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
          // Notifications Bell Action with Unread Count Badge
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8.0),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
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
                        Icons.notifications_outlined,
                        color: brandPrimary,
                        size: 21,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const NotificationsPage(),
                          ),
                        );
                      },
                      tooltip: context.tr('notifications_title'),
                    ),
                  ),
                  if (ref.watch(unreadNotificationCountProvider) > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF070E28) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '${ref.watch(unreadNotificationCountProvider)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
                        icon: Icons.view_timeline_rounded,
                        title: context.tr('time_blocker_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TimeBlockerPage()),
                          );
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
                        icon: Icons.center_focus_strong_rounded,
                        title: context.tr('focus_mode_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FocusModePage()),
                          );
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
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.fact_check_outlined,
                        title: context.tr('weekly_review_title'),
                        isSelected: false,
                        badgeText: ref.watch(isWeeklyReviewDueProvider)
                            ? context.tr('review_due_badge')
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          WeeklyReviewWizard.show(context);
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
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.find_in_page_rounded,
                        title: context.tr('retrospectives_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const RetrospectivePage(),
                            ),
                          );
                        },
                      ),

                      // -------------------------------------------------------
                      // LIFE MAP (GOALS) SECTION
                      // -------------------------------------------------------
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('goals_section_header'),
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
                        icon: Icons.flag_rounded,
                        title: context.tr('life_map_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LifeMapPage(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.access_time_rounded,
                        title: context.tr('time_audit_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const TimeAuditPage(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.balance_rounded,
                        title: context.tr('decision_journal_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const DecisionJournalPage(),
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
                        icon: Icons.wb_twilight_rounded,
                        title: context.tr('daily_rituals_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const DailyRitualsPage(),
                            ),
                          );
                        },
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

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.favorite_rounded,
                        title: context.tr('relationship_health_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const RelationshipHealthPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.battery_charging_full_rounded,
                        title: context.tr('social_battery_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SocialBatteryPage(),
                            ),
                          );
                        },
                      ),

                      // =========================================================
                      // SECTION: LEARNING & GROWTH
                      // TODO: Skills Board, Learning Paths, Knowledge Base, Course Tracker, and Spaced Repetition (coming next) should join this same section.
                      // =========================================================
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('learning_section_header'),
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
                        icon: Icons.auto_stories_rounded,
                        title: context.tr('reading_tracker_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BooksShelvesPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.track_changes_rounded,
                        title: context.tr('skills_board_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SkillsBoardPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.alt_route_rounded,
                        title: context.tr('learning_paths_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LearningPathsPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.collections_bookmark_rounded,
                        title: context.tr('knowledge_base_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const KnowledgeBasePage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.school_rounded,
                        title: context.tr('course_tracker_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CourseTrackerPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.style_rounded,
                        title: context.tr('flashcards_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const FlashcardsListPage(),
                            ),
                          );
                        },
                      ),

                      // =========================================================
                      // SECTION: HEALTH & FITNESS
                      // TODO: Nutrition Log, Body Metrics, and Mental Health (coming next) should join this same section.
                      // =========================================================
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('health_section_header'),
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
                        icon: Icons.fitness_center_rounded,
                        title: context.tr('workout_tracker_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const WorkoutTrackerPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.restaurant_rounded,
                        title: context.tr('nutrition_log_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NutritionLogPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.monitor_weight_outlined,
                        title: context.tr('body_metrics_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BodyMetricsPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.psychology_outlined,
                        title: context.tr('mental_health_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const MentalHealthPage(),
                            ),
                          );
                        },
                      ),

                      // =========================================================
                      // SECTION: FINANCE
                      // =========================================================
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('finance_section_header').toUpperCase(),
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
                        icon: Icons.account_balance_wallet_outlined,
                        title: context.tr('budget_tracker_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BudgetTrackerPage(),
                            ),
                          );
                        },
                      ),

                      // =========================================================
                      // SECTION: ANALYTICS
                      // =========================================================
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              context.tr('analytics_section_header').toUpperCase(),
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
                        icon: Icons.insights_rounded,
                        title: context.tr('life_analytics_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LifeAnalyticsPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.speed_rounded,
                        title: context.tr('life_score_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LifeScoreDetailPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.picture_as_pdf_outlined,
                        title: context.tr('pdf_reports_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ReportRangePage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.donut_large_rounded,
                        title: context.tr('wheel_of_life_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LifeAreasPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.stars_rounded,
                        title: context.tr('bucket_list_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BucketListPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.history_edu_rounded,
                        title: context.tr('legacy_journal_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LegacyJournalPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.event_note_rounded,
                        title: context.tr('annual_review_title'),
                        isSelected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AnnualReviewPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context: context,
                        icon: Icons.notifications_outlined,
                        title: context.tr('notifications_title'),
                        isSelected: false,
                        badgeCount: ref.watch(unreadNotificationCountProvider),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NotificationsPage(),
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
              _HomeTabContent(
                userName: displayName,
                onNavigateTab: (index) {
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
              ),
              const TasksScreen(),
              const ScheduleScreen(),
              const HabitsScreen(),
              const PomodoroScreen(),
              const GroupsHomePage(),
              const ProgressScreen(),
              // Tab 7: Profile (Shares the exact same ProfilePage widget used in Settings -> Profile)
              const ProfilePage(showAppBar: false, showBackButton: false),
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
    String? badgeText,
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
        trailing: badgeText != null && badgeText.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              )
            : ((badgeCount != null && badgeCount > 0)
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
                : null),
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
// TAB 0: FLAGSHIP HOME SCREEN CURATED FEED
//
// DESIGN PRINCIPLE:
// The Home Screen is Focusly's flagship command center. Rather than dumping every
// feature, it surfaces the single most actionable, high-engagement widget from each
// key feature in strict, documented priority order:
//
// FEED PRIORITY ORDER (1 -> 12):
// 1. Greeting Header (Hello + Date pill) [Always shown]
// 2. Level/XP Compact Widget (Level emoji, rank, slim progress bar) [Always shown]
// 3. Daily Rituals Row (Morning Intention, Energy & Mood check-in, End My Day) [Time-sensitive daily prompts]
// 4. Weekly Life Score Compact Widget (Gauge/numeric score) [Conditionally shown when data exists]
// 5. Today's Focus Card (Top 3 tasks for today + quick-check) [Conditionally shown when today tasks exist]
// 6. Quick Actions Row (Start Pomodoro, Quick Capture, Add Task) [Always shown launchpad]
// 7. Today's Habits Row (Horizontal streak pills + 1-tap check) [Conditionally shown when habits exist]
// 8. Continue Reading Widget (Active book + progress bar) [Conditionally shown when reading a book]
// 9. People to Reach Out To Widget (Overdue contacts) [Conditionally shown when contacts overdue]
// 10. Your Groups Preview (Joined groups list + unread indicator) [Conditionally shown when joined groups > 0]
// 11. Review Due Banner (Weekly reflection trigger) [Conditionally shown when 7-day review due]
// 12. Workspace Ready Footer (Deep Focus Mode launcher) [Closing action card]
// ==============================================================================
class _HomeTabContent extends StatelessWidget {
  final String userName;
  final ValueChanged<int> onNavigateTab;

  const _HomeTabContent({
    required this.userName,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final localizedDate = AppLocalizations.of(context).formatLocalizedDate(DateTime.now());

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        children: [
          // -------------------------------------------------------------------
          // 1. GREETING HEADER & LOCALIZED DATE PILL
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('hello_greeting')}, $userName 👋',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),

                // Date Badge Pill with Radiant Border & Soft Gradient
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                        size: 14,
                        color: brandPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        localizedDate,
                        style: TextStyle(
                          fontSize: 12,
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
          const SizedBox(height: 14),

          // -------------------------------------------------------------------
          // 2. LEVEL & XP COMPACT WIDGET (Small horizontal card)
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: LevelXpCompactWidget(
              onTap: () => onNavigateTab(6), // Navigate to Progress Tab
            ),
          ),
          const SizedBox(height: 14),

          // -------------------------------------------------------------------
          // 3. DAILY RITUALS (Morning Intention, Energy & Mood, End My Day)
          // -------------------------------------------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: MorningIntentionBanner(),
          ),
          const HomeEnergyMoodWidget(),
          const SizedBox(height: 4),

          // End My Day (Evening Shutdown Ritual Card)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: InkWell(
              onTap: () => ShutdownWizardModal.show(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF3B0764), Color(0xFF1E1B4B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFF3E8FF), Color(0xFFEDE9FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFA855F7).withValues(alpha: 0.3)
                        : const Color(0xFFC084FC),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('🌙', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('end_my_day_title'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF581C87),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('end_my_day_subtitle'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : const Color(0xFF6B21A8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF7E22CE),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // 4. WEEKLY LIFE SCORE COMPACT WIDGET (Conditionally shown if >0 score)
          // -------------------------------------------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: HomeLifeScoreWidget(),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // 5. TODAY'S FOCUS CARD (Top 3 tasks + quick complete, hidden if 0 tasks)
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TodaysFocusCard(
              onViewAll: () => onNavigateTab(1), // Navigate to Tasks Tab
            ),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // 6. QUICK ACTIONS ROW (Start Pomodoro, Quick Capture, Add Task)
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: QuickActionsRow(
              onStartPomodoro: () => onNavigateTab(4), // Navigate to Pomodoro Tab
            ),
          ),
          const SizedBox(height: 16),

          // -------------------------------------------------------------------
          // 7. TODAY'S HABITS HORIZONTAL SCROLL ROW (Hidden if 0 habits)
          // -------------------------------------------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: TodaysHabitsRow(),
          ),
          const SizedBox(height: 14),

          // -------------------------------------------------------------------
          // 8. CONTINUE READING WIDGET (Hidden if no active reading book)
          // -------------------------------------------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: ContinueReadingWidget(),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // 9. PEOPLE TO REACH OUT TO (Contacts Personal CRM, hidden if 0 overdue)
          // -------------------------------------------------------------------
          const HomeContactsWidget(),
          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // 10. YOUR GROUPS PREVIEW (Hidden if 0 joined groups)
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: GroupsPreviewWidget(
              onViewAllGroups: () => onNavigateTab(5), // Navigate to Groups Tab
            ),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // 11. WEEKLY REVIEW DUE BANNER (Hidden if review not due)
          // -------------------------------------------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: HomeWeeklyReviewDueBanner(),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // 12. WORKSPACE READY FOOTER CARD (Directly launches Focus Mode)
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FocusModePage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18.0),
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
                        width: 44,
                        height: 44,
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
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('focus_workspace_ready'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: isDark ? AppColors.cyanElectric : const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
