import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/achievement_model.dart';

/// Individual card for displaying an Achievement badge in locked or unlocked state.
class AchievementCard extends StatelessWidget {
  final AchievementModel achievement;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementCard({
    super.key,
    required this.achievement,
    required this.isUnlocked,
    this.unlockedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    final cardBg = isUnlocked
        ? (isDark ? const Color(0xFF0F1B4C) : Colors.white)
        : (isDark
              ? const Color(0xFF0A102D).withValues(alpha: 0.6)
              : const Color(0xFFF1F5F9).withValues(alpha: 0.7));

    final borderColor = isUnlocked
        ? (isDark
              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
              : const Color(0xFFFDE68A))
        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: const Color(
                    0xFFF59E0B,
                  ).withValues(alpha: isDark ? 0.1 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Row: Badge Emoji & Lock/Check status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(
                          0xFFF59E0B,
                        ).withValues(alpha: isDark ? 0.2 : 0.12)
                      : (isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.04)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Opacity(
                    opacity: isUnlocked ? 1.0 : 0.35,
                    child: Text(
                      achievement.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: secondaryTextColor.withValues(alpha: 0.5),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Title & Description
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(achievement.titleKey),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isUnlocked
                      ? primaryTextColor
                      : secondaryTextColor.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                context.tr(achievement.descKey),
                style: TextStyle(
                  fontSize: 11,
                  color: isUnlocked
                      ? secondaryTextColor
                      : secondaryTextColor.withValues(alpha: 0.5),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Unlock date or locked caption
          if (isUnlocked && unlockedAt != null)
            Text(
              DateFormat.yMMMd().format(unlockedAt!),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF59E0B),
              ),
            )
          else
            Text(
              isUnlocked ? context.tr('unlocked') : context.tr('locked'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isUnlocked
                    ? const Color(0xFF10B981)
                    : secondaryTextColor.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}
