import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../schedule/helpers/recurrence_helper.dart';
import '../schedule/models/event_model.dart';
import '../schedule/providers/schedule_provider.dart';
import '../schedule/widgets/add_edit_event_sheet.dart';
import 'helpers/time_blocker_helper.dart';
import 'providers/time_blocker_provider.dart';

/// Full-day 24-Hour Visual Time Blocker screen.
///
/// Features:
/// 1. Prev/Next Day navigation bar + Jump-to-Today shortcut + Date picker dialog.
/// 2. 24-Hour vertical timeline grid (00:00 through 23:00).
/// 3. Styled Time Block cards with block type badges (🧠 Deep, 📥 Shallow, 💪 Health, 🎮 Leisure, ⚙️ Admin).
/// 4. Multi-hour span visualization across all hours covered by a block.
/// 5. Interactive empty slot tap-to-book placeholders.
/// 6. Edit & delete actions with confirmation dialogs.
/// 7. Add Block Floating Action Button.
class TimeBlockerPage extends ConsumerWidget {
  const TimeBlockerPage({super.key});

  void _openAddBlockSheet(
    BuildContext context,
    DateTime selectedDate, {
    TimeOfDay? initialTime,
    String initialBlockType = 'deep',
    int initialDurationMinutes = 60,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditEventSheet(
        initialDate: selectedDate,
        initialTime: initialTime,
        initialBlockType: initialBlockType,
        initialDurationMinutes: initialDurationMinutes,
      ),
    );
  }

  void _openEditBlockSheet(BuildContext context, EventModel event) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditEventSheet(eventToEdit: event),
    );
  }

  Future<void> _confirmDeleteBlock(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
  ) async {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dialogCtx.tr('delete_block_confirm_title'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          dialogCtx.tr(
            'delete_block_confirm_msg',
            args: {'title': event.title},
          ),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(dialogCtx.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(dialogCtx.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(scheduleControllerProvider).deleteEvent(event);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('event_deleted_toast')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final scaffoldBg = isDark
        ? const Color(0xFF060B26)
        : const Color(0xFFF8FAFC);

    final selectedDate = ref.watch(timeBlockerSelectedDateProvider);
    final blocks = ref.watch(timeBlocksForSelectedDateProvider);
    final isToday = RecurrenceHelper.normalizeDate(
      DateTime.now(),
    ).isAtSameMomentAs(selectedDate);

    final totalPlannedMinutes = TimeBlockerHelper.computeTotalPlannedMinutes(
      blocks,
    );
    final plannedDurationStr = TimeBlockerHelper.formatDuration(
      totalPlannedMinutes,
    );

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF08123A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('time_blocker_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (!isToday)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: ActionChip(
                label: Text(context.tr('today')),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: brandPrimary,
                ),
                backgroundColor: brandPrimary.withValues(alpha: 0.12),
                side: BorderSide(color: brandPrimary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onPressed: () {
                  ref
                      .read(timeBlockerSelectedDateProvider.notifier)
                      .jumpToToday();
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // -------------------------------------------------------------------
          // 1. DATE NAVIGATION HEADER & DAILY PLANNED STATS
          // -------------------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A1238) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F5),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Prev Day Button
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 28),
                      tooltip: context.tr('previous_day'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(timeBlockerSelectedDateProvider.notifier)
                            .previousDay();
                      },
                    ),

                    // Date Picker Center Button
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          ref
                              .read(timeBlockerSelectedDateProvider.notifier)
                              .selectDate(picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: brandPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat.yMMMMEEEEd().format(selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Next Day Button
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 28),
                      tooltip: context.tr('next_day'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(timeBlockerSelectedDateProvider.notifier)
                            .nextDay();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Daily Summary Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F1B4C)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.view_timeline_outlined,
                        size: 15,
                        color: brandPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr(
                          'planned_blocks_summary',
                          args: {
                            'count': '${blocks.length}',
                            'duration': plannedDurationStr,
                          },
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // 2. 24-HOUR TIMELINE LISTVIEW (00:00 -> 23:00)
          // -------------------------------------------------------------------
          // Each row represents a 1-hour calendar slot (e.g. 16:00 to 17:00).
          // If a block starts at an arbitrary minute (e.g. 4:16 PM / 16:16 for 1 hour, ending at 5:16 PM / 17:16),
          // getBlocksForHour will find it in both the 16:00 row (as the starting card) and the 17:00 row (as a continuation card).
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: 24,
              itemBuilder: (context, hour) {
                final blocksInHour = TimeBlockerHelper.getBlocksForHour(
                  blocks,
                  hour,
                );
                final hourLabel = '${hour.toString().padLeft(2, '0')}:00';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Fixed Hour Label Column (e.g. "16:00")
                      SizedBox(
                        width: 52,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            hourLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // 2. Hour Slot Content: Occupied Block Card(s) OR Empty Slot Button
                      Expanded(
                        child: blocksInHour.isNotEmpty
                            ? Column(
                                children: blocksInHour.map((block) {
                                  final isStartHour =
                                      TimeBlockerHelper.isBlockStartHour(
                                        block,
                                        hour,
                                      );
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: block != blocksInHour.last
                                          ? 6.0
                                          : 0.0,
                                    ),
                                    child: _buildOccupiedSlotCard(
                                      context,
                                      ref,
                                      block,
                                      hour,
                                      isStartHour,
                                      isDark,
                                      primaryTextColor,
                                      secondaryTextColor,
                                    ),
                                  );
                                }).toList(),
                              )
                            : _buildEmptySlotPlaceholder(
                                context,
                                selectedDate,
                                hour,
                                isDark,
                                secondaryTextColor,
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // 3. FLOATING ACTION BUTTON (+ Add Block)
      // -----------------------------------------------------------------------
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddBlockSheet(
          context,
          selectedDate,
          initialTime: const TimeOfDay(hour: 9, minute: 0),
          initialBlockType: 'deep',
        ),
        backgroundColor: const Color(0xFF2E6FF2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          context.tr('add_block_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  /// Occupied Time Block Card
  Widget _buildOccupiedSlotCard(
    BuildContext context,
    WidgetRef ref,
    EventModel block,
    int hour,
    bool isStartHour,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final blockType = block.timeBlockType;
    final blockColor = blockType.color;
    final rangeStr = TimeBlockerHelper.formatTimeRange(
      block.time,
      block.endTime,
    );
    final durationStr = TimeBlockerHelper.formatDuration(
      block.effectiveDurationMinutes,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: blockColor.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: blockColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: isStartHour
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Type Tag + Edit / Delete Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: blockColor.withValues(alpha: isDark ? 0.3 : 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            blockType.emoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr(blockType.labelKey),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: blockColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          color: secondaryTextColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _openEditBlockSheet(context, block),
                          tooltip: context.tr('edit'),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                          ),
                          color: const Color(0xFFEF4444),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              _confirmDeleteBlock(context, ref, block),
                          tooltip: context.tr('delete'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Block Title
                Text(
                  block.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),

                const SizedBox(height: 4),

                // Time Range & Duration
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$rangeStr • $durationStr',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 14,
                      color: blockColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${context.tr('block_continuing')}: ${block.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  rangeStr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
    );
  }

  /// Empty Slot Placeholder
  Widget _buildEmptySlotPlaceholder(
    BuildContext context,
    DateTime selectedDate,
    int hour,
    bool isDark,
    Color secondaryTextColor,
  ) {
    return InkWell(
      onTap: () => _openAddBlockSheet(
        context,
        selectedDate,
        initialTime: TimeOfDay(hour: hour, minute: 0),
        initialBlockType: 'deep',
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A1238) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F5),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 15,
              color: secondaryTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              context.tr('empty_slot_tap_to_book'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
