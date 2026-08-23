import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/energy_mood_provider.dart';
import 'checkin_sheet.dart';

/// Home screen banner & summary widget for the Energy & Mood check-in feature.
///
/// - If not checked in today: Shows a dismissible prompt card ("How are you feeling today?").
/// - If checked in: Shows a rich summary card with energy, mood emoji, note, and water/sleep stats.
/// - Respects the `dailyCheckinReminderProvider` setting.
class HomeEnergyMoodWidget extends ConsumerStatefulWidget {
  const HomeEnergyMoodWidget({super.key});

  @override
  ConsumerState<HomeEnergyMoodWidget> createState() => _HomeEnergyMoodWidgetState();
}

class _HomeEnergyMoodWidgetState extends ConsumerState<HomeEnergyMoodWidget> {
  bool _dismissedForSession = false;

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
  Widget build(BuildContext context) {
    final reminderEnabled = ref.watch(dailyCheckinReminderProvider);
    if (!reminderEnabled || _dismissedForSession) {
      return const SizedBox.shrink();
    }

    final todayCheckinAsync = ref.watch(todayCheckinStreamProvider);
    final checkin = todayCheckinAsync.value;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    // If today's check-in has not been performed yet
    if (checkin == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E1B4B), const Color(0xFF0F1B4C)]
                : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFC7D2FE),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => CheckinSheet.show(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Animated Pulsing Mood Emoji Box
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('✨', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Prompt Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('how_are_you_feeling_today'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('tap_to_checkin_prompt'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Check In Action Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('checkin_btn'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),

                  // Dismiss Button
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 16, color: secondaryTextColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    onPressed: () {
                      setState(() {
                        _dismissedForSession = true;
                      });
                    },
                    tooltip: context.tr('dismiss'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // If today's check-in has been completed: Display Compact Summary Card
    final energyIndex = (checkin.energy - 1).clamp(0, 4);
    final energyInfo = _energyMeta[energyIndex];
    final energyIcon = energyInfo['icon'] as IconData;
    final energyColor = energyInfo['color'] as Color;
    final waterTarget = ref.watch(dailyWaterTargetProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E6FF2).withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            CheckinSheet.show(context);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title, Mood Emoji, Energy Badge & Edit Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Mood Emoji Avatar
                        Text(
                          checkin.mood,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 10),

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
                                '${context.tr('energy_label')}: ${context.tr(checkin.energyLabelKey)}',
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

                    // Edit button hint
                    Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: secondaryTextColor),
                        const SizedBox(width: 3),
                        Text(
                          context.tr('edit'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Note (if any, in quoted / italic style)
                if (checkin.note != null && checkin.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '“',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2E6FF2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            checkin.note!,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: secondaryTextColor,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Bottom Row: Water & Sleep quick summary pills
                Row(
                  children: [
                    // Water Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.water_drop_rounded, size: 14, color: Color(0xFF06B6D4)),
                          const SizedBox(width: 5),
                          Text(
                            '${checkin.water}/$waterTarget ${context.tr('glasses_unit')}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF06B6D4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sleep Pill (if logged)
                    if (checkin.sleep > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bedtime_rounded, size: 14, color: Color(0xFF6366F1)),
                            const SizedBox(width: 5),
                            Text(
                              '${checkin.sleep.toStringAsFixed(1)} ${context.tr('hours_unit')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
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
}
