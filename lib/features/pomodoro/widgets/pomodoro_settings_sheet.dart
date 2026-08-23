import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/pomodoro_config_model.dart';
import '../providers/pomodoro_provider.dart';

/// Modal bottom sheet for customizing Pomodoro phase durations and cycle preferences.
class PomodoroSettingsSheet extends ConsumerStatefulWidget {
  const PomodoroSettingsSheet({super.key});

  @override
  ConsumerState<PomodoroSettingsSheet> createState() =>
      _PomodoroSettingsSheetState();
}

class _PomodoroSettingsSheetState extends ConsumerState<PomodoroSettingsSheet> {
  late int _workMinutes;
  late int _shortBreakMinutes;
  late int _longBreakMinutes;
  late int _longBreakInterval;
  late bool _autoStartNext;

  @override
  void initState() {
    super.initState();
    final config = ref.read(pomodoroTimerProvider).config;
    _workMinutes = config.workMinutes;
    _shortBreakMinutes = config.shortBreakMinutes;
    _longBreakMinutes = config.longBreakMinutes;
    _longBreakInterval = config.longBreakInterval;
    _autoStartNext = config.autoStartNext;
  }

  void _saveSettings() {
    final updated = PomodoroConfig(
      workMinutes: _workMinutes,
      shortBreakMinutes: _shortBreakMinutes,
      longBreakMinutes: _longBreakMinutes,
      longBreakInterval: _longBreakInterval,
      autoStartNext: _autoStartNext,
    );

    ref.read(pomodoroTimerProvider.notifier).updateConfig(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final sheetBg = isDark ? const Color(0xFF0A1238) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle Pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('pomodoro_settings'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 1. Work Duration Slider
            _buildSliderSetting(
              title: context.tr('focus_duration'),
              valueText: '$_workMinutes ${context.tr('minutes_short')}',
              min: 5,
              max: 60,
              value: _workMinutes.toDouble(),
              cardBg: cardBg,
              borderColor: borderColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              activeColor: brandPrimary,
              onChanged: (val) {
                setState(() {
                  _workMinutes = val.round();
                });
              },
            ),

            const SizedBox(height: 12),

            // 2. Short Break Duration Slider
            _buildSliderSetting(
              title: context.tr('short_break_duration'),
              valueText: '$_shortBreakMinutes ${context.tr('minutes_short')}',
              min: 1,
              max: 30,
              value: _shortBreakMinutes.toDouble(),
              cardBg: cardBg,
              borderColor: borderColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              activeColor: const Color(0xFF10B981),
              onChanged: (val) {
                setState(() {
                  _shortBreakMinutes = val.round();
                });
              },
            ),

            const SizedBox(height: 12),

            // 3. Long Break Duration Slider
            _buildSliderSetting(
              title: context.tr('long_break_duration'),
              valueText: '$_longBreakMinutes ${context.tr('minutes_short')}',
              min: 5,
              max: 60,
              value: _longBreakMinutes.toDouble(),
              cardBg: cardBg,
              borderColor: borderColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              activeColor: const Color(0xFF10B981),
              onChanged: (val) {
                setState(() {
                  _longBreakMinutes = val.round();
                });
              },
            ),

            const SizedBox(height: 12),

            // 4. Long Break Interval Slider
            _buildSliderSetting(
              title: context.tr('long_break_interval'),
              valueText: '$_longBreakInterval ${context.tr('sessions')}',
              min: 2,
              max: 8,
              value: _longBreakInterval.toDouble(),
              cardBg: cardBg,
              borderColor: borderColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              activeColor: const Color(0xFFF59E0B),
              onChanged: (val) {
                setState(() {
                  _longBreakInterval = val.round();
                });
              },
            ),

            const SizedBox(height: 14),

            // 5. Auto Start Next Phase Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('auto_start_phases'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          context.tr('auto_start_phases_desc'),
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _autoStartNext,
                    activeTrackColor: brandPrimary,
                    onChanged: (val) {
                      setState(() {
                        _autoStartNext = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Save Settings Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      context.tr('save_settings'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF060B24) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required String valueText,
    required double min,
    required double max,
    required double value,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: activeColor,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: activeColor,
            inactiveColor: secondaryTextColor.withValues(alpha: 0.2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
