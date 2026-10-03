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

/// The 7-day horizontal Week View showing day tabs and corresponding time-anchored events.
class WeekView extends ConsumerWidget {
  final List<EventModel> events;

  const WeekView({super.key, required this.events});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final borderColor = AppColors.border(context);

    final selectedDate = ref.watch(selectedDateProvider);
    final eventTypesAsync = ref.watch(eventTypesStreamProvider);
    final eventTypes = eventTypesAsync.value ?? EventType.defaultEventTypes;

    // Calculate current week start (Sunday or Monday)
    final startOfWeek = selectedDate.subtract(
      Duration(days: selectedDate.weekday % 7),
    );
    final weekDays = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );

    // Group occurrences for the week
    final weekOccurrencesMap = RecurrenceHelper.groupOccurrencesByDay(
      events,
      weekDays.first,
      weekDays.last,
    );

    // Selected day occurrences
    final selectedDayOccurrences =
        weekOccurrencesMap[RecurrenceHelper.normalizeDate(selectedDate)] ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        // ---------------------------------------------------------------------
        // 1. 7-DAY HORIZONTAL WEEK STRIP
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
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
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((day) {
              final isSelected = DateUtils.isSameDay(day, selectedDate);
              final isToday = DateUtils.isSameDay(day, DateTime.now());
              final count =
                  (weekOccurrencesMap[RecurrenceHelper.normalizeDate(day)] ??
                          [])
                      .length;

              return GestureDetector(
                onTap: () {
                  ref.read(selectedDateProvider.notifier).selectDate(day);
                  ref.read(focusedMonthProvider.notifier).setMonth(day);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? brandPrimary
                        : (isToday
                              ? (isDark
                                    ? const Color(0xFF08123A)
                                    : const Color(0xFFEFF6FF))
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(14),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: brandPrimary.withValues(alpha: 0.5),
                            width: 1.2,
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat.E().format(day),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : secondaryTextColor.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: count > 0
                              ? (isSelected ? Colors.white : brandPrimary)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // 2. SELECTED DAY TIMELINE AGENDA
        // ---------------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat.yMMMMEEEEd().format(selectedDate),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
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

        if (selectedDayOccurrences.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Center(
              child: Text(
                context.tr('no_events_today'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ),
          ),
        ] else ...[
          ...selectedDayOccurrences.map((occ) {
            final type = eventTypes.firstWhere(
              (t) => t.id == occ.typeId,
              orElse: () => EventType.defaultEventTypes.first,
            );
            return _buildWeekEventCard(
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

  Widget _buildWeekEventCard({
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: type.color),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Row(
                        children: [
                          Text(
                            occ.time.format(context),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: type.color,
                            ),
                          ),
                          const SizedBox(width: 10),
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
                    ],
                  ),
                ),
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
