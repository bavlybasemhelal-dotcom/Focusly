import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'providers/nutrition_log_provider.dart';
import 'widgets/last_7_days_card.dart';
import 'widgets/nutrition_form_modal.dart';
import 'widgets/nutrition_history_card.dart';
import 'widgets/weekly_comparison_card.dart';

/// Main Nutrition Log screen displaying 7-day emoji scale, 15-entry history list,
/// and week-over-week average rating comparison.
class NutritionLogPage extends ConsumerWidget {
  const NutritionLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final allLogsAsync = ref.watch(nutritionLogsStreamProvider);

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
              context.tr('nutrition_log_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('nutrition_log_subtitle'),
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
            tooltip: context.tr('nutrition_add_log_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              NutritionFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.restaurant_rounded, size: 20),
        label: Text(
          context.tr('nutrition_rate_food_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          NutritionFormModal.show(context);
        },
      ),
      body: allLogsAsync.when(
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
        data: (allLogs) {
          // Zero entries state check
          if (allLogs.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration Circle
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF10B981,
                        ).withValues(alpha: isDark ? 0.15 : 0.1),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text('🥗', style: TextStyle(fontSize: 44)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Empty Title
                    Text(
                      context.tr('nutrition_empty_title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    // Empty Subtitle
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(
                        context.tr('nutrition_empty_subtitle'),
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Button: Rate Food
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                      icon: const Icon(Icons.restaurant_rounded, size: 20),
                      label: Text(
                        context.tr('nutrition_rate_food_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        NutritionFormModal.show(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Non-empty state: Render 7-day scale, history card, and weekly comparison
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;

              if (isWide) {
                // Wide Screen 2-Column Layout
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: 7-Day Scale & History
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: const [
                            Last7DaysCard(),
                            SizedBox(height: 20),
                            NutritionHistoryCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right Column: Weekly Comparison
                      const Expanded(flex: 2, child: WeeklyComparisonCard()),
                    ],
                  ),
                );
              }

              // Mobile Vertical Stack Layout
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                physics: const BouncingScrollPhysics(),
                children: const [
                  Last7DaysCard(),
                  SizedBox(height: 16),
                  WeeklyComparisonCard(),
                  SizedBox(height: 16),
                  NutritionHistoryCard(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
