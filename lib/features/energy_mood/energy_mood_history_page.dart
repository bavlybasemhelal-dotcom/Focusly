import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/checkin_model.dart';
import 'providers/energy_mood_provider.dart';
import 'widgets/checkin_sheet.dart';

// TODO: Life Analytics feature will read from this same checkins collection to correlate energy and mood with task completion and Pomodoro productivity metrics.

/// Energy & Mood History Screen.
///
/// Features weekly energy trend visualization, daily metrics overview,
/// and a chronological history list with tap-to-edit capabilities.
class EnergyMoodHistoryPage extends ConsumerWidget {
  const EnergyMoodHistoryPage({super.key});

  static const List<Map<String, dynamic>> _energyMeta = [
    {
      'icon': Icons.battery_1_bar_rounded,
      'color': Color(0xFFEF4444),
    },
    {
      'icon': Icons.battery_2_bar_rounded,
      'color': Color(0xFFF97316),
    },
    {
      'icon': Icons.battery_4_bar_rounded,
      'color': Color(0xFFFBBF24),
    },
    {
      'icon': Icons.battery_5_bar_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'icon': Icons.battery_full_rounded,
      'color': Color(0xFF06B6D4),
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final historyAsync = ref.watch(checkinsHistoryStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('energy_mood_history_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF2E6FF2)),
            tooltip: context.tr('new_checkin_btn'),
            onPressed: () => CheckinSheet.show(context),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return _buildEmptyState(context, isDark, primaryTextColor, secondaryTextColor);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // 1. Weekly Energy Level Trends Chart Card
              _buildEnergyTrendCard(context, list, isDark, primaryTextColor, secondaryTextColor),
              const SizedBox(height: 24),

              // 2. Section Header: Past Check-Ins
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('past_checkins_header'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  Text(
                    '${list.length} ${context.tr('entries_count')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Chronological Checkin List Items
              ...list.map((checkin) {
                return _buildCheckinCard(
                  context: context,
                  checkin: checkin,
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                );
              }),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Text(
            context.tr('history_load_error'),
            style: TextStyle(color: secondaryTextColor),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CheckinSheet.show(context),
        backgroundColor: const Color(0xFF2E6FF2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.bolt_rounded, size: 20),
        label: Text(
          context.tr('checkin_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  /// Builds a visual bar chart of the last 7 checkins
  Widget _buildEnergyTrendCard(
    BuildContext context,
    List<CheckinModel> checkins,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    // Get up to 7 most recent entries in chronological order for the chart
    final chartEntries = checkins.take(7).toList().reversed.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E6FF2).withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E6FF2).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.insights_rounded, color: Color(0xFF2E6FF2), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('energy_trend_title'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Text(
                context.tr('last_7_days_label'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart Columns
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: chartEntries.map((entry) {
                final energyIndex = (entry.energy - 1).clamp(0, 4);
                final color = _energyMeta[energyIndex]['color'] as Color;
                final dt = DateTime.tryParse(entry.date) ?? DateTime.now();
                final dayLabel = DateFormat('E').format(dt);
                final barHeight = (entry.energy / 5.0) * 80;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      entry.mood,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 22,
                      height: barHeight.clamp(14.0, 80.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.6)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${entry.energy}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a check-in item card
  Widget _buildCheckinCard({
    required BuildContext context,
    required CheckinModel checkin,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    final energyIndex = (checkin.energy - 1).clamp(0, 4);
    final energyInfo = _energyMeta[energyIndex];
    final energyIcon = energyInfo['icon'] as IconData;
    final energyColor = energyInfo['color'] as Color;

    final parsedDate = DateTime.tryParse(checkin.date) ?? DateTime.now();
    final isToday = DateUtils.isSameDay(parsedDate, DateTime.now());
    final isYesterday = DateUtils.isSameDay(
      parsedDate,
      DateTime.now().subtract(const Duration(days: 1)),
    );

    final dateTitle = isToday
        ? context.tr('today')
        : (isYesterday
            ? context.tr('yesterday')
            : DateFormat.yMMMMd().format(parsedDate));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => CheckinSheet.show(context, dateStr: checkin.date),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Date, Mood Emoji, Energy Badge & Edit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          checkin.mood,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                            if (!isToday && !isYesterday)
                              Text(
                                checkin.date,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Energy Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: energyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: energyColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(energyIcon, color: energyColor, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            context.tr(checkin.energyLabelKey),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: energyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Note Preview
                if (checkin.note != null && checkin.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '“${checkin.note}”',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: secondaryTextColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Bottom Meta: Water and Sleep Chips
                Row(
                  children: [
                    if (checkin.water > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.water_drop_rounded, size: 13, color: Color(0xFF06B6D4)),
                            const SizedBox(width: 4),
                            Text(
                              '${checkin.water} ${context.tr('glasses_unit')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF06B6D4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (checkin.sleep > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bedtime_rounded, size: 13, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Text(
                              '${checkin.sleep.toStringAsFixed(1)} ${context.tr('hours_unit')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⚡', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('no_checkins_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('no_checkins_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => CheckinSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('checkin_today_btn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
