import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/flashcard_model.dart';
import 'providers/flashcards_provider.dart';
import 'review_session_page.dart';
import 'widgets/flashcard_form_modal.dart';

/// Main Spaced Repetition (Flashcards) screen for reviewing and managing cards.
class FlashcardsListPage extends ConsumerWidget {
  const FlashcardsListPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FlashcardModel card,
  ) async {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dialogCtx.tr('delete_flashcard_confirm_title'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          dialogCtx.tr('delete_flashcard_confirm_msg'),
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
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        final service = ref.read(flashcardsServiceProvider);
        await service.deleteFlashcard(uid: uid, cardId: card.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('flashcard_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
      }
    }
  }

  Widget _buildDueBadge(BuildContext context, FlashcardModel card, bool isDark) {
    final remaining = card.dueDaysRemaining;
    Color badgeColor;
    String label;

    if (remaining < 0) {
      badgeColor = const Color(0xFFEF4444); // Red overdue
      label = context.tr('due_overdue_badge', args: {'days': (-remaining).toString()});
    } else if (remaining == 0) {
      badgeColor = const Color(0xFF10B981); // Green due today
      label = context.tr('due_today_badge');
    } else {
      badgeColor = const Color(0xFF64748B); // Slate future
      label = context.tr('due_in_days_badge', args: {'days': remaining.toString()});
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: badgeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final flashcardsAsync = ref.watch(flashcardsStreamProvider);
    final dueCards = ref.watch(dueFlashcardsProvider);

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
              context.tr('flashcards_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('flashcards_subtitle'),
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
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2E6FF2)),
            tooltip: context.tr('add_flashcard_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              FlashcardFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E6FF2),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          context.tr('add_flashcard_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          FlashcardFormModal.show(context);
        },
      ),
      body: flashcardsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E6FF2)),
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
        data: (cards) {
          if (cards.isEmpty) {
            return _buildEmptyState(context, primaryTextColor, secondaryTextColor);
          }

          return Column(
            children: [
              // Top Session Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    // 1. Review Due Cards Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.alarm_on_rounded, size: 18),
                        label: Text(
                          '${context.tr('review_due_cards_btn')} (${dueCards.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (dueCards.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('no_due_cards_toast')),
                                backgroundColor: const Color(0xFF64748B),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            );
                          } else {
                            ReviewSessionPage.start(context, ref, dueCards);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 2. Review All Cards Button
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: const Color(0xFF2E6FF2),
                          side: const BorderSide(color: Color(0xFF2E6FF2), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: Text(
                          context.tr('review_all_cards_btn'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ReviewSessionPage.start(context, ref, cards);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Flashcard Rows List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  physics: const BouncingScrollPhysics(),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          // Card Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.style_rounded,
                              size: 18,
                              color: Color(0xFF2E6FF2),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Front Text & Due Badge
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.front,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                _buildDueBadge(context, card, isDark),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Edit Action
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: secondaryTextColor,
                            tooltip: context.tr('edit_flashcard_title'),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              FlashcardFormModal.show(context, cardToEdit: card);
                            },
                          ),
                          const SizedBox(width: 4),

                          // Delete Action
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: const Color(0xFFEF4444),
                            tooltip: context.tr('delete'),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => _confirmDelete(context, ref, card),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.style_rounded,
                  size: 40,
                  color: Color(0xFF2E6FF2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('empty_flashcards_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('empty_flashcards_subtitle'),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                context.tr('add_flashcard_btn'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                FlashcardFormModal.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
