import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'controllers/review_session_controller.dart';
import 'models/flashcard_model.dart';
import 'providers/flashcards_provider.dart';
import 'session_summary_page.dart';

/// Active full-screen flashcard review session with SM-2 4-tier rating interface.
class ReviewSessionPage extends ConsumerWidget {
  const ReviewSessionPage({super.key});

  /// Static helper to start a session and push this page.
  static Future<void> start(
    BuildContext context,
    WidgetRef ref,
    List<FlashcardModel> cards,
  ) async {
    ref.read(reviewSessionControllerProvider.notifier).startSession(cards);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReviewSessionPage()));
  }

  Future<void> _confirmEndSession(BuildContext context, WidgetRef ref) async {
    final session = ref.read(reviewSessionControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);

    if (session.totalReviewed == 0) {
      Navigator.of(context).pop();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          dialogCtx.tr('end_session_confirm_title'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
          ),
        ),
        content: Text(
          dialogCtx.tr('end_session_confirm_msg'),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(dialogCtx.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E6FF2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.tr('end_session_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitRating(
    BuildContext context,
    WidgetRef ref,
    int quality,
  ) async {
    HapticFeedback.selectionClick();
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final service = ref.read(flashcardsServiceProvider);
    final controller = ref.read(reviewSessionControllerProvider.notifier);

    final saved = await controller.submitRating(
      quality: quality,
      uid: uid,
      service: service,
    );

    if (!saved) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('save_failed'))));
      }
      return;
    }

    final session = ref.read(reviewSessionControllerProvider);
    if (session.isCompleted && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SessionSummaryPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final session = ref.watch(reviewSessionControllerProvider);
    final currentCard = session.currentCard;

    if (currentCard == null || session.isCompleted) {
      return const SessionSummaryPage();
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: primaryTextColor),
          onPressed: () => _confirmEndSession(context, ref),
        ),
        title: Text(
          context.tr(
            'review_progress_header',
            args: {
              'current': session.currentDisplayNumber.toString(),
              'total': session.totalCards.toString(),
            },
          ),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => _confirmEndSession(context, ref),
            child: Text(
              context.tr('end_session_btn'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              // Top Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: session.currentDisplayNumber / session.totalCards,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white12
                      : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2E6FF2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Main Flashcard Presentation Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // FRONT Section (Question / Concept)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2E6FF2,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr('review_front_header'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2E6FF2),
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              currentCard.front,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),

                      // BACK Section (Revealed on tap)
                      if (session.isAnswerRevealed) ...[
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.tr('review_back_header'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF10B981),
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                currentCard.back,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Action Controls
              if (!session.isAnswerRevealed)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2E6FF2),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(reviewSessionControllerProvider.notifier)
                          .revealAnswer();
                    },
                    child: Text(
                      context.tr('show_answer_btn'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else
                // 4 Rating Buttons Row
                Row(
                  children: [
                    // 1. Forgot (0 pts) - Red
                    Expanded(
                      child: _buildRatingButton(
                        context: context,
                        label: context.tr('rating_forgot'),
                        points: context.tr('rating_forgot_points'),
                        color: const Color(0xFFEF4444),
                        onTap: () => _submitRating(context, ref, 1),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Hard (3 pts) - Orange
                    Expanded(
                      child: _buildRatingButton(
                        context: context,
                        label: context.tr('rating_hard'),
                        points: context.tr('rating_hard_points'),
                        color: const Color(0xFFF97316),
                        onTap: () => _submitRating(context, ref, 2),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. Good (5 pts) - Amber
                    Expanded(
                      child: _buildRatingButton(
                        context: context,
                        label: context.tr('rating_good'),
                        points: context.tr('rating_good_points'),
                        color: const Color(0xFFF59E0B),
                        onTap: () => _submitRating(context, ref, 3),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 4. Easy (10 pts) - Emerald
                    Expanded(
                      child: _buildRatingButton(
                        context: context,
                        label: context.tr('rating_easy'),
                        points: context.tr('rating_easy_points'),
                        color: const Color(0xFF10B981),
                        onTap: () => _submitRating(context, ref, 4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingButton({
    required BuildContext context,
    required String label,
    required String points,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            points,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
