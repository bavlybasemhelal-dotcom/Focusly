import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/event_model.dart';
import 'providers/schedule_provider.dart';
import 'views/agenda_view.dart';
import 'views/month_view.dart';
import 'views/week_view.dart';
import 'widgets/add_edit_event_sheet.dart';

/// The main Schedule Screen hosting the Month/Year navigator header,
/// segmented view mode selector (Month, Week, Day), and calendar views.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final viewMode = ref.watch(scheduleViewModeProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final eventsList = eventsAsync.value ?? <EventModel>[];

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final monthYearStr = DateFormat.yMMMM(isArabic ? 'ar' : 'en').format(focusedMonth);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient aurora bloom in background
          _buildAmbientGlowBlooms(isDark),

          SafeArea(
            child: Column(
              children: [
                // -------------------------------------------------------------
                // 1. TOP HEADER & MONTH NAVIGATOR
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Screen Title & Month Navigator
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, size: 26),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              ref.read(focusedMonthProvider.notifier).previousMonth();
                            },
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: focusedMonth,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                initialDatePickerMode: DatePickerMode.year,
                              );
                              if (picked != null) {
                                ref
                                    .read(focusedMonthProvider.notifier)
                                    .setMonth(picked);
                                ref
                                    .read(selectedDateProvider.notifier)
                                    .selectDate(picked);
                              }
                            },
                            child: Text(
                              monthYearStr,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: primaryTextColor,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 26),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              ref.read(focusedMonthProvider.notifier).nextMonth();
                            },
                          ),
                        ],
                      ),

                      // "Today" Button
                      TextButton.icon(
                        onPressed: () {
                          ref.read(selectedDateProvider.notifier).jumpToToday();
                          ref.read(focusedMonthProvider.notifier).resetToCurrent();
                        },
                        icon: const Icon(Icons.today_rounded, size: 16),
                        label: Text(context.tr('today')),
                        style: TextButton.styleFrom(
                          foregroundColor: brandPrimary,
                          backgroundColor: brandPrimary.withValues(
                            alpha: isDark ? 0.18 : 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 2. VIEW MODE SELECTOR (Month / Week / Day)
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1B4C) : const Color(0xFFE2E8F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Month View Tab
                        Expanded(
                          child: _buildViewModeTab(
                            label: context.tr('view_month'),
                            icon: Icons.calendar_view_month_rounded,
                            isSelected: viewMode == ScheduleViewMode.month,
                            isDark: isDark,
                            brandPrimary: brandPrimary,
                            onTap: () {
                              ref.read(scheduleViewModeProvider.notifier).setMode(
                                    ScheduleViewMode.month,
                                  );
                            },
                          ),
                        ),
                        // Week View Tab
                        Expanded(
                          child: _buildViewModeTab(
                            label: context.tr('view_week'),
                            icon: Icons.calendar_view_week_rounded,
                            isSelected: viewMode == ScheduleViewMode.week,
                            isDark: isDark,
                            brandPrimary: brandPrimary,
                            onTap: () {
                              ref.read(scheduleViewModeProvider.notifier).setMode(
                                    ScheduleViewMode.week,
                                  );
                            },
                          ),
                        ),
                        // Day / Agenda View Tab
                        Expanded(
                          child: _buildViewModeTab(
                            label: context.tr('view_day'),
                            icon: Icons.view_agenda_rounded,
                            isSelected: viewMode == ScheduleViewMode.day,
                            isDark: isDark,
                            brandPrimary: brandPrimary,
                            onTap: () {
                              ref.read(scheduleViewModeProvider.notifier).setMode(
                                    ScheduleViewMode.day,
                                  );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // -------------------------------------------------------------
                // 3. CALENDAR CONTENT (Month / Week / Day)
                // -------------------------------------------------------------
                Expanded(
                  child: switch (viewMode) {
                    ScheduleViewMode.month => MonthView(events: eventsList),
                    ScheduleViewMode.week => WeekView(events: eventsList),
                    ScheduleViewMode.day => AgendaView(events: eventsList),
                  },
                ),
              ],
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // 4. FLOATING ACTION BUTTON (+) TO CREATE EVENT
      // -----------------------------------------------------------------------
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient(context),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.cyanElectric.withValues(alpha: 0.4)
                  : const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'schedule_fab',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddEditEventSheet(initialDate: selectedDate),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? const Color(0xFF060B24) : Colors.white,
          tooltip: context.tr('add_event'),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildViewModeTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color brandPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF08123A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? brandPrimary : (isDark ? Colors.white60 : Colors.black45),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? brandPrimary : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
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
}
