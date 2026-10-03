import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../constants/xp_constants.dart';
import '../models/level_logic.dart';
import '../models/xp_log_model.dart';
import '../providers/progress_provider.dart';

/// Screen displaying the complete audit breakdown of user XP history and reward rules.
///
/// Gives users complete transparency into where their XP came from and why they leveled up.
class XpHistoryPage extends ConsumerWidget {
  const XpHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final levelInfo = ref.watch(userLevelProvider);
    final xpLogsAsync = ref.watch(xpLogStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryTextColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('xp_history_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // 1. LEVEL PROGRESS SUMMARY CARD
            // -----------------------------------------------------------------
            _buildLevelSummaryCard(context, levelInfo, isDark, brandPrimary),

            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // 2. HOW TO EARN XP GUIDE CARD (Single-source-of-truth from XpConstants)
            // -----------------------------------------------------------------
            _buildHowToEarnCard(
              context,
              isDark,
              primaryTextColor,
              secondaryTextColor,
            ),

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // 3. RECENT XP ACTIVITY LOG
            // -----------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('xp_recent_activity'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                  ),
                ),
                Text(
                  '${levelInfo.totalXp} ${context.tr('total_xp')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: brandPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            xpLogsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => _buildEmptyState(context, secondaryTextColor),
              data: (logs) {
                if (logs.isEmpty) {
                  return _buildEmptyState(context, secondaryTextColor);
                }

                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogItemRow(
                      context,
                      log,
                      isDark,
                      primaryTextColor,
                      secondaryTextColor,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSummaryCard(
    BuildContext context,
    UserLevelInfo levelInfo,
    bool isDark,
    Color brandPrimary,
  ) {
    final isMax = levelInfo.level >= 20;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark
        ? Colors.white70
        : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F1B4C), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
              : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF38BDF8).withValues(alpha: 0.12)
                : const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1238) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    levelInfo.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('level')} ${levelInfo.level} • ${context.tr(levelInfo.titleKey)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${levelInfo.totalXp} ${context.tr('total_xp')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: levelInfo.percentToNextLevel,
                backgroundColor: isDark
                    ? Colors.white12
                    : const Color(0xFFCBD5E1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Breakdown text
          Text(
            isMax
                ? context.tr('max_level_reached')
                : context.tr(
                    'xp_level_progress_desc',
                    args: {
                      'needed': levelInfo.xpToNextLevel.toString(),
                      'nextLevel': (levelInfo.level + 1).toString(),
                      'earned': levelInfo.currentLevelXp.toString(),
                    },
                  ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToEarnCard(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final List<Map<String, dynamic>> rules = [
      {
        'emoji': '🎯',
        'titleKey': 'xp_rule_task',
        'xp': '+${XpConstants.taskCompletion} XP',
      },
      {
        'emoji': '🔥',
        'titleKey': 'xp_rule_habit',
        'xp': '+${XpConstants.habitDayCompletion} XP',
      },
      {
        'emoji': '🍅',
        'titleKey': 'xp_rule_pomodoro',
        'xp': '+${XpConstants.pomodoroFullSession} XP',
      },
      {
        'emoji': '⚡',
        'titleKey': 'xp_rule_checkin',
        'xp': '+${XpConstants.dailyCheckin} XP',
      },
      {
        'emoji': '💧',
        'titleKey': 'xp_rule_water',
        'xp': '+${XpConstants.waterPerGlass} XP',
      },
      {
        'emoji': '🌙',
        'titleKey': 'xp_rule_sleep',
        'xp': '+${XpConstants.sleepLogged} XP',
      },
      {
        'emoji': '📚',
        'titleKey': 'xp_rule_reading_progress',
        'xp': '+${XpConstants.readingProgress} XP',
      },
      {
        'emoji': '📖',
        'titleKey': 'xp_rule_reading_finish',
        'xp': '+${XpConstants.readingBookFinished} XP',
      },
      {
        'emoji': '🗺️',
        'titleKey': 'xp_rule_learning',
        'xp': '+${XpConstants.learningPathDay} XP',
      },
      {
        'emoji': '🗂️',
        'titleKey': 'xp_rule_flashcards',
        'xp': '+${XpConstants.flashcardReviewPerCard} XP',
      },
      {
        'emoji': '🌅',
        'titleKey': 'xp_rule_rituals',
        'xp': '+${XpConstants.eveningShutdown} XP',
      },
      {
        'emoji': '📊',
        'titleKey': 'xp_rule_weekly_review',
        'xp': '+${XpConstants.weeklyReview} XP',
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                context.tr('xp_how_to_earn'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('xp_how_to_earn_subtitle'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rules.map((r) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r['emoji'] as String,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr(r['titleKey'] as String),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r['xp'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItemRow(
    BuildContext context,
    XpLogModel log,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                log.sourceEmoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.source,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeDate(log.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+${log.amount} XP',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color secondaryTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            context.tr('xp_empty_history'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1 ||
        (diff.inHours < 48 &&
            dt.day == now.subtract(const Duration(days: 1)).day)) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}
