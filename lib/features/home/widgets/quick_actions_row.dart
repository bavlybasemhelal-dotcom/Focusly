import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../gtd/widgets/quick_capture_sheet.dart';
import '../../tasks/widgets/add_edit_task_sheet.dart';

/// Quick Actions row for the Home Feed.
///
/// Surfaces the top 3 starting actions:
/// 1. "▶️ Start Pomodoro"
/// 2. "✏️ Quick Capture"
/// 3. "➕ Add Task"
class QuickActionsRow extends StatelessWidget {
  final VoidCallback onStartPomodoro;

  const QuickActionsRow({
    super.key,
    required this.onStartPomodoro,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            context.tr('quick_actions_title'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // 1. Start Pomodoro Action
            Expanded(
              child: _buildActionChip(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                icon: Icons.play_arrow_rounded,
                iconGradient: const [Color(0xFFEF4444), Color(0xFFF97316)],
                title: context.tr('start_pomodoro_action'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onStartPomodoro();
                },
              ),
            ),
            const SizedBox(width: 8),

            // 2. Quick Capture Action
            Expanded(
              child: _buildActionChip(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                icon: Icons.edit_note_rounded,
                iconGradient: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                title: context.tr('quick_capture_action'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  QuickCaptureSheet.show(context);
                },
              ),
            ),
            const SizedBox(width: 8),

            // 3. Add Task Action
            Expanded(
              child: _buildActionChip(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                icon: Icons.add_task_rounded,
                iconGradient: const [Color(0xFF2E6FF2), Color(0xFF00E5FF)],
                title: context.tr('add_task_action'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  AddEditTaskSheet.show(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required VoidCallback onTap,
  }) {
    final primaryTextColor = AppColors.textPrimary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF2E6FF2).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.first.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
