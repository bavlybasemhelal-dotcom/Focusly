import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/recurrence_helper.dart';
import '../models/event_model.dart';
import '../models/event_type_model.dart';
import '../providers/schedule_provider.dart';
import '../widgets/add_edit_event_sheet.dart';

/// The standard 7-column Month Calendar view with colored event indicator dots
/// and an inline agenda for the selected day.
class MonthView extends ConsumerWidget {
  final List<EventModel> events;

  const MonthView({
    super.key,
    required this.events,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final borderColor = AppColors.border(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final eventTypesAsync = ref.watch(eventTypesStreamProvider);
    final eventTypes = eventTypesAsync.value ?? EventType.defaultEventTypes;

    // Expand events for the entire visible month grid
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);

    // Calculate grid start padding (Sunday vs Saturday based on RTL/Arabic)
    final int startOffset = isArabic
        ? (firstDayOfMonth.weekday % 7 + 1) % 7 // Saturday = 0 in Arabic
        : (firstDayOfMonth.weekday % 7); // Sunday = 0

    final gridStartDate = firstDayOfMonth.subtract(Duration(days: startOffset));
    final gridEndDate = gridStartDate.add(const Duration(days: 41)); // 6 weeks = 42 days

    // Group occurrences for fast lookups
    final occurrencesMap = RecurrenceHelper.groupOccurrencesByDay(
      events,
      gridStartDate,
      gridEndDate,
    );

    // Selected day occurrences
    final selectedDayOccurrences =
        occurrencesMap[RecurrenceHelper.normalizeDate(selectedDate)] ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        // ---------------------------------------------------------------------
        // 1. MONTH CALENDAR GRID CARD
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
            borderRadius: BorderRadius.circular(22),
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
                  ],
          ),
          child: Column(
            children: [
              // Weekday Headers (7 columns)
              _buildWeekdayHeaders(context, isArabic, secondaryTextColor),
              const SizedBox(height: 10),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 10),

              // Month Days 6x7 Grid
              _buildMonthGrid(
                context: context,
                ref: ref,
                gridStartDate: gridStartDate,
                focusedMonth: focusedMonth,
                selectedDate: selectedDate,
                occurrencesMap: occurrencesMap,
                eventTypes: eventTypes,
                isDark: isDark,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                brandPrimary: brandPrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // 2. SELECTED DAY AGENDA HEADER
        // ---------------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: brandPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateUtils.isSameDay(selectedDate, DateTime.now())
                        ? '${context.tr('today')} • ${DateFormat.MMMd().format(selectedDate)}'
                        : DateFormat.yMMMMEEEEd().format(selectedDate),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Text(
                '${selectedDayOccurrences.length} ${context.tr('events_count')}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ---------------------------------------------------------------------
        // 3. SELECTED DAY EVENTS LIST OR EMPTY STATE
        // ---------------------------------------------------------------------
        if (selectedDayOccurrences.isEmpty) ...[
          _buildDayEmptyState(context, isDark, secondaryTextColor),
        ] else ...[
          ...selectedDayOccurrences.map((occ) {
            final type = eventTypes.firstWhere(
              (t) => t.id == occ.typeId,
              orElse: () => EventType.defaultEventTypes.first,
            );
            return _buildEventCard(
              context: context,
              ref: ref,
              occ: occ,
              type: type,
              isDark: isDark,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              borderColor: borderColor,
            );
          }),
        ],
      ],
    );
  }

  Widget _buildWeekdayHeaders(
    BuildContext context,
    bool isArabic,
    Color textColor,
  ) {
    final List<String> weekdays = isArabic
        ? ['سبت', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع']
        : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) {
        return SizedBox(
          width: 38,
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthGrid({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime gridStartDate,
    required DateTime focusedMonth,
    required DateTime selectedDate,
    required Map<DateTime, List<EventOccurrence>> occurrencesMap,
    required List<EventType> eventTypes,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
  }) {
    final List<Widget> dayCells = [];
    final today = RecurrenceHelper.normalizeDate(DateTime.now());
    final normalizedSelected = RecurrenceHelper.normalizeDate(selectedDate);

    for (int i = 0; i < 42; i++) {
      final cellDate = gridStartDate.add(Duration(days: i));
      final isCurrentMonth = cellDate.month == focusedMonth.month;
      final isToday = DateUtils.isSameDay(cellDate, today);
      final isSelected = DateUtils.isSameDay(cellDate, normalizedSelected);

      final dayOccurrences =
          occurrencesMap[RecurrenceHelper.normalizeDate(cellDate)] ?? [];

      // Collect distinct colored dots
      final distinctTypeIds = dayOccurrences.map((o) => o.typeId).toSet().toList();

      dayCells.add(
        GestureDetector(
          onTap: () {
            ref.read(selectedDateProvider.notifier).selectDate(cellDate);
            if (cellDate.month != focusedMonth.month) {
              ref.read(focusedMonthProvider.notifier).setMonth(cellDate);
            }
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? brandPrimary.withValues(alpha: isDark ? 0.25 : 0.15)
                  : (isToday
                      ? (isDark ? const Color(0xFF08123A) : const Color(0xFFEFF6FF))
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: brandPrimary, width: 1.8)
                  : (isToday
                      ? Border.all(
                          color: brandPrimary.withValues(alpha: 0.5),
                          width: 1.2,
                        )
                      : null),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Day Number
                Text(
                  '${cellDate.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: (isSelected || isToday)
                        ? FontWeight.w900
                        : (isCurrentMonth ? FontWeight.w700 : FontWeight.w400),
                    color: isSelected
                        ? brandPrimary
                        : (isCurrentMonth
                            ? primaryTextColor
                            : secondaryTextColor.withValues(alpha: 0.35)),
                  ),
                ),
                const SizedBox(height: 2),

                // Colored Event Dots (Max 3 dots + N)
                SizedBox(
                  height: 6,
                  child: distinctTypeIds.isEmpty
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...distinctTypeIds.take(3).map((typeId) {
                              final type = eventTypes.firstWhere(
                                (t) => t.id == typeId,
                                orElse: () => EventType.defaultEventTypes.first,
                              );
                              return Container(
                                width: 4.5,
                                height: 4.5,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: type.color,
                                ),
                              );
                            }),
                            if (distinctTypeIds.length > 3)
                              Container(
                                width: 4.5,
                                height: 4.5,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: dayCells,
    );
  }

  Widget _buildDayEmptyState(
    BuildContext context,
    bool isDark,
    Color secondaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context), width: 1.2),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 36,
              color: secondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('no_events_today'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard({
    required BuildContext context,
    required WidgetRef ref,
    required EventOccurrence occ,
    required EventType type,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    final typeName = type.isDefault ? context.tr(type.nameKey) : type.nameKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left Event Type Color Accent
              Container(
                width: 5,
                color: type.color,
              ),
              const SizedBox(width: 14),

              // Event Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Recurrence Icon
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              occ.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          if (occ.isRecurring) ...[
                            Icon(
                              Icons.repeat_rounded,
                              size: 14,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Time badge & Type tag
                      Row(
                        children: [
                          // Time Badge
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: type.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                occ.time.format(context),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: type.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),

                          // Type Tag Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: type.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              typeName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: type.color,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Optional Note
                      if (occ.note != null && occ.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          occ.note!,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions (Edit & Delete)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: secondaryTextColor,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddEditEventSheet(eventToEdit: occ.event),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.errorRed.withValues(alpha: 0.8),
                onPressed: () => _confirmDeleteEvent(context, ref, occ.event),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteEvent(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.tr('delete_event_confirm_title'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          content: Text(
            event.isRecurring
                ? context.tr('delete_recurring_event_confirm_message')
                : context.tr('delete_event_confirm_message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(context.tr('delete')),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await ref.read(scheduleControllerProvider).deleteEvent(event);
    }
  }
}
