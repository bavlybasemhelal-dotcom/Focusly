import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../progress/constants/xp_constants.dart';
import '../progress/services/progress_service.dart';
import 'controllers/review_session_controller.dart';

/// Screen displayed upon finishing a review session showing recall stats and points.
class SessionSummaryPage extends ConsumerStatefulWidget {
  const SessionSummaryPage({super.key});

  @override
  ConsumerState<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends ConsumerState<SessionSummaryPage> {
  @override
  void initState() {
    super.initState();
    // XP hook: Award +2 XP per card reviewed in the session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(reviewSessionControllerProvider);
      if (session.totalReviewed > 0) {
        final xpEarned = session.totalReviewed * XpConstants.flashcardReviewPerCard;
        ProgressService().awardXp(
          xpEarned,
          source: 'Flashcards reviewed: ${session.totalReviewed} card${session.totalReviewed > 1 ? "s" : ""}',
          sourceType: 'flashcards',
          context: context,
          ref: ref,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final session = ref.watch(reviewSessionControllerProvider);
    final forgotCount = session.ratingCounts[1] ?? 0;
    final hardCount = session.ratingCounts[2] ?? 0;
    final goodCount = session.ratingCounts[3] ?? 0;
    final easyCount = session.ratingCounts[4] ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('session_summary_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Celebration Header
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E6FF2), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      context.tr('session_summary_title'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('session_summary_subtitle'),
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Top Overview Stats (Cards Reviewed & Points Earned)
                    Row(
                      children: [
                        // Cards Reviewed
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  session.totalReviewed.toString(),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2E6FF2),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr('cards_reviewed_label'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: secondaryTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Points Earned
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  session.totalPoints.toString(),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr('points_earned_label'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: secondaryTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recall Performance Breakdown Title
                    Text(
                      context.tr('rating_breakdown_label'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rating Tiers Breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildRatingRow(
                            label: context.tr('rating_easy'),
                            points: context.tr('rating_easy_points'),
                            count: easyCount,
                            color: const Color(0xFF10B981),
                            icon: Icons.sentiment_very_satisfied_rounded,
                            primaryColor: primaryTextColor,
                          ),
                          const Divider(height: 20),
                          _buildRatingRow(
                            label: context.tr('rating_good'),
                            points: context.tr('rating_good_points'),
                            count: goodCount,
                            color: const Color(0xFFF59E0B),
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            primaryColor: primaryTextColor,
                          ),
                          const Divider(height: 20),
                          _buildRatingRow(
                            label: context.tr('rating_hard'),
                            points: context.tr('rating_hard_points'),
                            count: hardCount,
                            color: const Color(0xFFF97316),
                            icon: Icons.sentiment_neutral_rounded,
                            primaryColor: primaryTextColor,
                          ),
                          const Divider(height: 20),
                          _buildRatingRow(
                            label: context.tr('rating_forgot'),
                            points: context.tr('rating_forgot_points'),
                            count: forgotCount,
                            color: const Color(0xFFEF4444),
                            icon: Icons.sentiment_very_dissatisfied_rounded,
                            primaryColor: primaryTextColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Done Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF2E6FF2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr('done_btn'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingRow({
    required String label,
    required String points,
    required int count,
    required Color color,
    required IconData icon,
    required Color primaryColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($points)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
