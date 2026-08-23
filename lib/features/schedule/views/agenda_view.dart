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

/// The Day/Agenda View displaying a full timeline of events for the selected day.
class AgendaView extends ConsumerWidget {
  final List<EventModel> events;

  const AgendaView({
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

    final selectedDate = ref.watch(selectedDateProvider);
    final eventTypesAsync = ref.watch(eventTypesStreamProvider);
    final eventTypes = eventTypesAsync.value ?? EventType.defaultEventTypes;

    final dayOccurrences =
        RecurrenceHelper.getOccurrencesForDay(events, selectedDate);

    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        // ---------------------------------------------------------------------
        // 1. DAY PICKER & NAVIGATOR HEADER
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                onPressed: () {
                  final prevDay = selectedDate.subtract(const Duration(days: 1));
                  ref.read(selectedDateProvider.notifier).selectDate(prevDay);
                  ref.read(focusedMonthProvider.notifier).setMonth(prevDay);
                },
              ),
              Column(
                children: [
                  Text(
                    DateFormat.yMMMMEEEEd().format(selectedDate),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.tr('today'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: brandPrimary,
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: () {
                  final nextDay = selectedDate.add(const Duration(days: 1));
                  ref.read(selectedDateProvider.notifier).selectDate(nextDay);
                  ref.read(focusedMonthProvider.notifier).setMonth(nextDay);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // 2. TIMELINE LIST OR EMPTY STATE
        // ---------------------------------------------------------------------
        if (dayOccurrences.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 42,
                    color: brandPrimary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('no_events_today'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('no_events_agenda_subtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ...dayOccurrences.map((occ) {
            final type = eventTypes.firstWhere(
              (t) => t.id == occ.typeId,
              orElse: () => EventType.defaultEventTypes.first,
            );
            final typeName =
                type.isDefault ? context.tr(type.nameKey) : type.nameKey;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
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
                      Container(width: 5, color: type.color),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      occ.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  if (occ.isRecurring) ...[
                                    Icon(
                                      Icons.repeat_rounded,
                                      size: 16,
                                      color: secondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: type.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        occ.time.format(context),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: type.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
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
                              if (occ.note != null && occ.note!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  occ.note!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryTextColor,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 19),
                        color: secondaryTextColor,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                AddEditEventSheet(eventToEdit: occ.event),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 19),
                        color: AppColors.errorRed.withValues(alpha: 0.8),
                        onPressed: () async {
                          await ref
                              .read(scheduleControllerProvider)
                              .deleteEvent(occ.event);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
