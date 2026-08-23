import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/font_size_controller.dart';
import '../../core/theme/reminder_time_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../screens/login_screen.dart';
import '../energy_mood/providers/energy_mood_provider.dart';
import 'change_password_page.dart';
import 'privacy_policy_page.dart';
import 'profile_page.dart';
import 'terms_of_service_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _groupActivityBadgesEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadGroupActivitySetting();
  }

  Future<void> _loadGroupActivitySetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _groupActivityBadgesEnabled =
            prefs.getBool('group_activity_badges_enabled') ?? true;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    // Active Riverpod State Observers
    final currentLocale = ref.watch(localeControllerProvider);
    final currentThemeMode = ref.watch(themeControllerProvider);
    final currentFontSize = ref.watch(fontSizeControllerProvider);
    final currentReminderTime = ref.watch(reminderTimeControllerProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('settings_title'),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: brandPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Ambient aurora blooms in background
          _buildAmbientGlowBlooms(isDark),

          // Scrollable Settings Sections
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              children: [
                // -------------------------------------------------------------
                // 1. ACCOUNT SECTION
                // -------------------------------------------------------------
                _buildSectionHeader(
                  context.tr('account_section'),
                  primaryTextColor,
                  const Color(0xFF3B82F6),
                ),
                _buildGroupedCard(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  children: [
                    _buildSettingsRow(
                      icon: Icons.person_outline_rounded,
                      iconBg: const Color(0xFF3B82F6),
                      title: context.tr('profile'),
                      subtitle: context.tr('profile_desc'),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfilePage()),
                        );
                      },
                    ),
                    _buildDivider(borderColor),
                    _buildSettingsRow(
                      icon: Icons.lock_outline_rounded,
                      iconBg: const Color(0xFF8B5CF6),
                      title: context.tr('change_password'),
                      subtitle: context.tr('change_password_desc'),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 2. PREFERENCES SECTION
                // -------------------------------------------------------------
                _buildSectionHeader(
                  context.tr('preferences_section'),
                  primaryTextColor,
                  const Color(0xFF0EA5E9),
                ),
                _buildGroupedCard(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  children: [
                    // Language Selector
                    _buildSettingsRow(
                      icon: Icons.language_rounded,
                      iconBg: const Color(0xFF06B6D4),
                      title: context.tr('language'),
                      trailingText: currentLocale.languageCode == 'ar'
                          ? 'العربية'
                          : 'English',
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () => _showLanguageSelectionSheet(context, ref),
                    ),
                    _buildDivider(borderColor),

                    // Theme Mode Selector
                    _buildSettingsRow(
                      icon: Icons.palette_outlined,
                      iconBg: const Color(0xFFEC4899),
                      title: context.tr('theme'),
                      trailingText: _getThemeModeLabel(context, currentThemeMode),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () => _showThemeSelectionSheet(context, ref),
                    ),
                    _buildDivider(borderColor),

                    // Notifications Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('notifications'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('notifications_desc'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _notificationsEnabled,
                            activeThumbColor: brandPrimary,
                            onChanged: (val) {
                              setState(() {
                                _notificationsEnabled = val;
                              });
                              // TODO: Connect with real push-notification permission service (Firebase Cloud Messaging)
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(borderColor),

                    // Group Activity Badges Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.groups_outlined,
                              color: Color(0xFF38BDF8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('group_activity_setting'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('group_activity_setting_desc'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _groupActivityBadgesEnabled,
                            activeThumbColor: brandPrimary,
                            onChanged: (val) async {
                              setState(() {
                                _groupActivityBadgesEnabled = val;
                              });
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('group_activity_badges_enabled', val);
                              } catch (_) {}
                              // TODO: True cross-device push notifications for group activity while the app is closed would require Firebase Cloud Messaging + a Cloud Function trigger on new feed entries, which needs the Firebase Blaze (paid) plan. Out of scope for now; real-time Firestore listeners cover the live feel while the app is open.
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 3. ADVANCED & PREFERENCES SECTION
                // -------------------------------------------------------------
                _buildSectionHeader(
                  context.tr('advanced_section'),
                  primaryTextColor,
                  const Color(0xFF6366F1),
                ),
                _buildGroupedCard(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  children: [
                    // Default Reminder Time Selector (Fully Functional)
                    _buildSettingsRow(
                      icon: Icons.alarm_on_rounded,
                      iconBg: const Color(0xFFF59E0B),
                      title: context.tr('reminder_time'),
                      subtitle: context.tr('reminder_time_desc'),
                      trailingText: currentReminderTime.format(context),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () => _pickReminderTime(context, currentReminderTime),
                    ),
                    _buildDivider(borderColor),

                    // Daily Check-in Reminder Toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: Color(0xFF4F46E5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('daily_checkin_reminder_setting'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('daily_checkin_reminder_setting_desc'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: ref.watch(dailyCheckinReminderProvider),
                            activeThumbColor: brandPrimary,
                            onChanged: (val) {
                              ref.read(dailyCheckinReminderProvider.notifier).setEnabled(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(borderColor),

                    // Daily Water Target Stepper Row
                    _buildSettingsRow(
                      icon: Icons.water_drop_rounded,
                      iconBg: const Color(0xFF06B6D4),
                      title: context.tr('water_target_setting'),
                      subtitle: context.tr('water_target_setting_desc'),
                      trailingText: '${ref.watch(dailyWaterTargetProvider)} ${context.tr('glasses_unit')}',
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () => _showWaterTargetDialog(context, ref),
                    ),
                    _buildDivider(borderColor),

                    // Font Size Scale Selector (Fully Functional App-Wide)
                    _buildSettingsRow(
                      icon: Icons.format_size_rounded,
                      iconBg: const Color(0xFF0EA5E9),
                      title: context.tr('font_size'),
                      trailingText: context.tr(currentFontSize.titleKey),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () => _showFontSizeSelectionSheet(context, ref),
                    ),
                    _buildDivider(borderColor),

                    // Connected Accounts
                    _buildSettingsRow(
                      icon: Icons.link_rounded,
                      iconBg: const Color(0xFF8B5CF6),
                      title: context.tr('connected_accounts'),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () {
                        // TODO: Implement Google & Apple linked login accounts
                        _showComingSoonSnackbar(context, context.tr('connected_accounts'));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 4. ABOUT SECTION
                // -------------------------------------------------------------
                _buildSectionHeader(
                  context.tr('about_section'),
                  primaryTextColor,
                  const Color(0xFF64748B),
                ),
                _buildGroupedCard(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  children: [
                    _buildSettingsRow(
                      icon: Icons.info_outline_rounded,
                      iconBg: const Color(0xFF64748B),
                      title: context.tr('app_version'),
                      trailingText: '1.0.0 (Build 1)',
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      showChevron: false,
                    ),
                    _buildDivider(borderColor),

                    // Terms of Service Navigation (Dedicated Screen)
                    _buildSettingsRow(
                      icon: Icons.description_outlined,
                      iconBg: const Color(0xFF3B82F6),
                      title: context.tr('terms_of_service'),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServicePage(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(borderColor),

                    // Privacy Policy Navigation (Dedicated Screen)
                    _buildSettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      iconBg: const Color(0xFF10B981),
                      title: context.tr('privacy_policy'),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(borderColor),

                    // Rate the App (Store Launch)
                    _buildSettingsRow(
                      icon: Icons.star_outline_rounded,
                      iconBg: const Color(0xFFF59E0B),
                      title: context.tr('rate_app'),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      onTap: _handleRateApp,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 5. ACCOUNT ACTIONS (Log Out & Delete Account)
                // -------------------------------------------------------------
                _buildSectionHeader(
                  context.tr('account_actions'),
                  primaryTextColor,
                  AppColors.errorRed,
                ),
                _buildGroupedCard(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  children: [
                    _buildSettingsRow(
                      icon: Icons.logout_rounded,
                      iconBg: AppColors.errorRed,
                      title: context.tr('log_out'),
                      primaryColor: AppColors.errorRed,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      showChevron: true,
                      onTap: _handleLogout,
                    ),
                    _buildDivider(borderColor),
                    _buildSettingsRow(
                      icon: Icons.delete_forever_rounded,
                      iconBg: AppColors.errorRed,
                      title: context.tr('delete_account'),
                      primaryColor: AppColors.errorRed,
                      secondaryColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      showChevron: true,
                      onTap: _handleDeleteAccount,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAL SHEETS & ACTIONS
  // ===========================================================================

  /// Opens the native TimePicker to select and persist default daily reminder time
  Future<void> _pickReminderTime(BuildContext context, TimeOfDay initialTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.dial,
    );

    if (picked != null && picked != initialTime) {
      await ref
          .read(reminderTimeControllerProvider.notifier)
          .setReminderTime(picked);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('reminder_time_updated')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Opens the Font Size selector modal bottom sheet
  void _showFontSizeSelectionSheet(BuildContext context, WidgetRef ref) {
    final currentFontSize = ref.read(fontSizeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandPrimary = AppColors.brandPrimary(context);
    final sheetBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    context.tr('font_size'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...AppFontSize.values.map((option) {
                  final isSelected = option == currentFontSize;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.format_size_rounded,
                        color: const Color(0xFF0EA5E9),
                        size: option == AppFontSize.small
                            ? 18
                            : (option == AppFontSize.large ? 26 : 22),
                      ),
                    ),
                    title: Text(
                      context.tr(option.titleKey),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: brandPrimary)
                        : null,
                    onTap: () {
                      ref
                          .read(fontSizeControllerProvider.notifier)
                          .setFontSize(option);
                      Navigator.of(sheetContext).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Attempts to launch the store page for user ratings
  Future<void> _handleRateApp() async {
    final Uri storeUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.focusly.app',
    );

    try {
      if (await canLaunchUrl(storeUri)) {
        await launchUrl(storeUri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('rate_app_error'))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('rate_app_error'))),
      );
    }
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    final cyanGlow = isDark
        ? AppColors.cyanElectric.withValues(alpha: 0.14)
        : const Color(0xFF38BDF8).withValues(alpha: 0.18);
    final greenGlow = isDark
        ? AppColors.accentGreenNeon.withValues(alpha: 0.12)
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

  String _getThemeModeLabel(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return context.tr('theme_light');
      case ThemeMode.dark:
        return context.tr('theme_dark');
      case ThemeMode.system:
        return context.tr('theme_system');
    }
  }

  void _showThemeSelectionSheet(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandPrimary = AppColors.brandPrimary(context);
    final sheetBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    context.tr('theme'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.light_mode_rounded, color: Color(0xFFF59E0B)),
                  ),
                  title: Text(
                    context.tr('theme_light'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: currentMode == ThemeMode.light
                      ? Icon(Icons.check_circle_rounded, color: brandPrimary)
                      : null,
                  onTap: () {
                    ref
                        .read(themeControllerProvider.notifier)
                        .setThemeMode(ThemeMode.light);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dark_mode_rounded, color: Color(0xFF6366F1)),
                  ),
                  title: Text(
                    context.tr('theme_dark'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: currentMode == ThemeMode.dark
                      ? Icon(Icons.check_circle_rounded, color: brandPrimary)
                      : null,
                  onTap: () {
                    ref
                        .read(themeControllerProvider.notifier)
                        .setThemeMode(ThemeMode.dark);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.brightness_auto_rounded, color: Color(0xFF0EA5E9)),
                  ),
                  title: Text(
                    context.tr('theme_system'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: currentMode == ThemeMode.system
                      ? Icon(Icons.check_circle_rounded, color: brandPrimary)
                      : null,
                  onTap: () {
                    ref
                        .read(themeControllerProvider.notifier)
                        .setThemeMode(ThemeMode.system);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSelectionSheet(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandPrimary = AppColors.brandPrimary(context);
    final sheetBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    context.tr('language'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.language_rounded, color: Color(0xFF3B82F6)),
                  ),
                  title: Text(
                    context.tr('lang_en'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: currentLocale.languageCode == 'en'
                      ? Icon(Icons.check_circle_rounded, color: brandPrimary)
                      : null,
                  onTap: () {
                    ref
                        .read(localeControllerProvider.notifier)
                        .setLocale('en');
                    Navigator.of(sheetContext).pop();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.translate_rounded, color: Color(0xFF10B981)),
                  ),
                  title: Text(
                    context.tr('lang_ar'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: currentLocale.languageCode == 'ar'
                      ? Icon(Icons.check_circle_rounded, color: brandPrimary)
                      : null,
                  onTap: () {
                    ref
                        .read(localeControllerProvider.notifier)
                        .setLocale('ar');
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.border(context), width: 1.2),
          ),
          title: Text(
            context.tr('log_out_confirm_title'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(context.tr('log_out_confirm_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                context.tr('cancel'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
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
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.border(context), width: 1.2),
          ),
          title: Text(
            context.tr('delete_account_confirm_title'),
            style: const TextStyle(
              color: AppColors.errorRed,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(context.tr('delete_account_confirm_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                context.tr('cancel'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.tr('delete_account'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      // TODO: Delete user documents from Firestore and call FirebaseAuth user.delete()
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('coming_soon')),
        ),
      );
    }
  }

  void _showComingSoonSnackbar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - ${context.tr('coming_soon')}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===========================================================================
  // REUSABLE UI BUILDERS
  // ===========================================================================

  Widget _buildSectionHeader(String title, Color textColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 10.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor.withValues(alpha: 0.85),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCard({
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    String? trailingText,
    required Color primaryColor,
    required Color secondaryColor,
    required Color brandPrimary,
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconBg, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: brandPrimary,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: secondaryColor.withValues(alpha: 0.7),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color borderColor) {
    return Divider(
      height: 1,
      thickness: 1,
      color: borderColor,
      indent: 16,
      endIndent: 16,
    );
  }

  void _showWaterTargetDialog(BuildContext context, WidgetRef ref) {
    int current = ref.read(dailyWaterTargetProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                context.tr('water_target_setting'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: current > 1
                        ? () {
                            setDialogState(() => current--);
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                    color: const Color(0xFF06B6D4),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$current',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('glasses_unit'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: current < 30
                        ? () {
                            setDialogState(() => current++);
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                    color: const Color(0xFF06B6D4),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ref.read(dailyWaterTargetProvider.notifier).setTarget(current);
                    Navigator.of(ctx).pop();
                  },
                  child: Text(context.tr('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
