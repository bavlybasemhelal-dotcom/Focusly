import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/ritual_model.dart';
import 'providers/rituals_provider.dart';
import 'widgets/morning_intention_modal.dart';
import 'widgets/shutdown_wizard_modal.dart';

/// Dedicated Daily Rituals Hub screen (Morning Intention & Evening Shutdown).
class DailyRitualsPage extends ConsumerWidget {
  const DailyRitualsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final todayRitualAsync = ref.watch(todayRitualStreamProvider);
    final historyAsync = ref.watch(ritualsHistoryStreamProvider);

    final todayRitual = todayRitualAsync.value;
    final history = historyAsync.value ?? [];

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
          context.tr('daily_rituals_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Morning Intention Card
            _buildMorningIntentionCard(
              context: context,
              ritual: todayRitual,
              isDark: isDark,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              borderColor: borderColor,
            ),
            const SizedBox(height: 16),

            // 2. Evening Shutdown Ritual Card ("End My Day")
            _buildShutdownCard(
              context: context,
              ritual: todayRitual,
              isDark: isDark,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              borderColor: borderColor,
            ),
            const SizedBox(height: 28),

            // 3. Rituals History Section
            Text(
              context.tr('rituals_history_header'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),

            if (history.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    const Text('🌅', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('no_rituals_history_title'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('no_rituals_history_sub'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ],
                ),
              )
            else
              ...history.map((r) => _buildHistoryCard(
                    context: context,
                    ritual: r,
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    borderColor: borderColor,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildMorningIntentionCard({
    required BuildContext context,
    required RitualModel? ritual,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    final hasIntention = ritual?.hasIntention == true;
    final intentionText = ritual?.intention ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('🌅', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('morning_intention_title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasIntention
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasIntention ? context.tr('status_set') : context.tr('status_pending'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasIntention ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasIntention ? intentionText : context.tr('set_morning_intention_prompt_sub'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: hasIntention ? FontWeight.w700 : FontWeight.w500,
              color: hasIntention ? primaryTextColor : secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => MorningIntentionModal.show(
                context,
                initialIntention: hasIntention ? intentionText : null,
              ),
              icon: Icon(
                hasIntention ? Icons.edit_outlined : Icons.add_rounded,
                size: 16,
              ),
              label: Text(
                hasIntention
                    ? context.tr('edit_intention_btn')
                    : context.tr('set_intention_btn'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShutdownCard({
    required BuildContext context,
    required RitualModel? ritual,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    final isDone = ritual?.isShutdownCompleted == true;
    final shutdown = ritual?.shutdown;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('🌙', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('shutdown_ritual_title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDone ? context.tr('status_done') : context.tr('status_pending'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDone ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isDone
                ? context.tr('shutdown_completed_today_sub')
                : context.tr('shutdown_ritual_card_desc'),
            style: TextStyle(
              fontSize: 13,
              color: secondaryTextColor,
            ),
          ),
          if (isDone && shutdown != null) ...[
            const SizedBox(height: 10),
            if (shutdown.gratitudeText.isNotEmpty)
              Text(
                '🙏 ${shutdown.gratitudeText}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ShutdownWizardModal.show(context),
              icon: Icon(isDone ? Icons.check_circle_rounded : Icons.nightlight_round, size: 16),
              label: Text(
                isDone
                    ? context.tr('view_shutdown_btn')
                    : context.tr('start_shutdown_btn'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard({
    required BuildContext context,
    required RitualModel ritual,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    final parsedDate = DateTime.tryParse(ritual.date) ?? DateTime.now();
    final formattedDate = DateFormat.yMMMMd().format(parsedDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              if (ritual.isShutdownCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '🌙 Closed',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          if (ritual.hasIntention) ...[
            const SizedBox(height: 8),
            Text(
              '🎯 ${ritual.intention}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryTextColor),
            ),
          ],
          if (ritual.shutdown?.gratitudeText.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              '🙏 ${ritual.shutdown!.gratitudeText}',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          ],
          if (ritual.shutdown?.lesson?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              '💡 ${ritual.shutdown!.lesson}',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: secondaryTextColor),
            ),
          ],
        ],
      ),
    );
  }
}
