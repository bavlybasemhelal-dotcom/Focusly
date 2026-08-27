import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/rituals_provider.dart';
import 'morning_intention_modal.dart';

/// Persistent banner on the Home screen displaying today's Morning Intention.
class MorningIntentionBanner extends ConsumerWidget {
  const MorningIntentionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final isDismissed = ref.watch(morningIntentionDismissedProvider);
    final ritualAsync = ref.watch(todayRitualStreamProvider);
    final ritual = ritualAsync.value;

    final hasIntention = ritual?.hasIntention == true;
    final intentionText = ritual?.intention ?? '';

    // If intention is set: show rich amber banner with edit tap & dismiss action
    if (hasIntention) {
      if (isDismissed) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF78350F).withValues(alpha: 0.5),
                    const Color(0xFFB45309).withValues(alpha: 0.3),
                  ]
                : [
                    const Color(0xFFFEF3C7),
                    const Color(0xFFFDE68A),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.5),
          ),
        ),
        child: InkWell(
          onTap: () => MorningIntentionModal.show(context, initialIntention: intentionText),
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('todays_focus_label'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      intentionText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF78350F),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => MorningIntentionModal.show(context, initialIntention: intentionText),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : const Color(0xFFB45309),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(morningIntentionDismissedProvider.notifier).dismiss();
                },
              ),
            ],
          ),
        ),
      );
    }

    // If no intention is set AND the prompt has already been shown/dismissed today:
    // Render a subtle, non-intrusive calm entry point so setting intention is 1 tap away without nagging.
    if (isDismissed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard.withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: InkWell(
          onTap: () => MorningIntentionModal.show(context),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('set_morning_intention_prompt_title'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Text(
                context.tr('set_btn'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
              ),
            ],
          ),
        ),
      );
    }

    // If no intention is set yet and not dismissed: show initial inviting prompt card with dismiss option
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🌅', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('set_morning_intention_prompt_title'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                Text(
                  context.tr('set_morning_intention_prompt_sub'),
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => MorningIntentionModal.show(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              context.tr('set_btn'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: secondaryTextColor.withValues(alpha: 0.7),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: context.tr('cancel'),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(morningIntentionDismissedProvider.notifier).dismiss();
            },
          ),
        ],
      ),
    );
  }
}
