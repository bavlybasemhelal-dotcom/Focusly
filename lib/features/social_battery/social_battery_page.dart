import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'providers/social_battery_provider.dart';
import 'widgets/social_battery_entry_card.dart';
import 'widgets/social_battery_form_modal.dart';
import 'widgets/social_battery_summary_card.dart';

/// Main Social Battery screen displaying the 10 most recent logs and net-energy summary metrics.
class SocialBatteryPage extends ConsumerWidget {
  const SocialBatteryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final recentLogs = ref.watch(recentSocialBatteryLogsProvider);
    final allEntriesAsync = ref.watch(socialBatteryStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('social_battery_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('social_battery_subtitle'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF10B981),
            ),
            tooltip: context.tr('add_social_interaction_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              SocialBatteryFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.battery_charging_full_rounded, size: 20),
        label: Text(
          context.tr('add_social_interaction_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          SocialBatteryFormModal.show(context);
        },
      ),
      body: allEntriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '${context.tr('error')}: $err',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ),
        data: (allEntries) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            children: [
              // =======================================================
              // SECTION 1: SOCIAL BATTERY LOG (10 Most Recent)
              // =======================================================
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('social_battery_log_header'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (recentLogs.isEmpty)
                _buildEmptyLogState(
                  context,
                  primaryTextColor,
                  secondaryTextColor,
                )
              else
                ...recentLogs.map(
                  (entry) => SocialBatteryEntryCard(entry: entry),
                ),

              const SizedBox(height: 24),

              // =======================================================
              // SECTION 2: ENERGY SUMMARY (Net Balance & Counts)
              // =======================================================
              Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: Color(0xFF2E6FF2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('social_battery_summary_header'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              const SocialBatterySummaryCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyLogState(
    BuildContext context,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.battery_charging_full_rounded,
                size: 30,
                color: Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('empty_social_battery_title'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('empty_social_battery_subtitle'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              context.tr('add_social_interaction_btn'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              SocialBatteryFormModal.show(context);
            },
          ),
        ],
      ),
    );
  }
}
