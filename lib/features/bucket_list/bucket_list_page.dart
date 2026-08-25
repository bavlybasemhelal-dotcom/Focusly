import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_colors.dart';
import 'models/bucket_item_model.dart';
import 'providers/bucket_list_provider.dart';
import 'widgets/bucket_item_form_modal.dart';

// TODO: In future roadmap updates, this feature can be grouped under a dedicated
// "Vision" drawer section alongside Legacy Journal and Annual Review once implemented.

/// Main screen for Focusly's Bucket List feature, separating pending dreams to achieve
/// from achieved memories with celebratory completion and memory reflection flows.
class BucketListPage extends ConsumerWidget {
  const BucketListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

    final allItemsAsync = ref.watch(bucketListStreamProvider);
    final allItems = allItemsAsync.value ?? <BucketItemModel>[];
    final pendingItems = ref.watch(pendingBucketItemsProvider);
    final completedItems = ref.watch(completedBucketItemsProvider);

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
              context.tr('bucket_list_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('bucket_list_subtitle'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: allItemsAsync.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : allItems.isEmpty
              ? _buildOverallEmptyState(context, isDark, primaryTextColor, secondaryTextColor)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // =========================================================
                    // 1. DREAMS TO ACHIEVE SECTION (PENDING)
                    // =========================================================
                    _buildSectionHeader(
                      context: context,
                      title: context.tr(
                        'dreams_to_achieve_section',
                        args: {'count': '${pendingItems.length}'},
                      ),
                      count: pendingItems.length,
                      color: const Color(0xFF6366F1),
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                    ),
                    const SizedBox(height: 12),

                    if (pendingItems.isEmpty)
                      _buildSectionEmptyState(
                        context: context,
                        text: context.tr('no_pending_dreams'),
                        cardBg: cardBg,
                        borderColor: borderColor,
                        secondaryTextColor: secondaryTextColor,
                      )
                    else
                      ...pendingItems.map((item) {
                        return _buildPendingDreamCard(
                          context: context,
                          ref: ref,
                          item: item,
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        );
                      }),

                    const SizedBox(height: 28),

                    // =========================================================
                    // 2. ACHIEVED MEMORIES SECTION (COMPLETED)
                    // =========================================================
                    _buildSectionHeader(
                      context: context,
                      title: context.tr(
                        'achieved_memories_section',
                        args: {'count': '${completedItems.length}'},
                      ),
                      count: completedItems.length,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                    ),
                    const SizedBox(height: 12),

                    if (completedItems.isEmpty)
                      _buildSectionEmptyState(
                        context: context,
                        text: context.tr('no_achieved_memories'),
                        cardBg: cardBg,
                        borderColor: borderColor,
                        secondaryTextColor: secondaryTextColor,
                      )
                    else
                      ...completedItems.map((item) {
                        return _buildAchievedMemoryCard(
                          context: context,
                          ref: ref,
                          item: item,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        );
                      }),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          context.tr('add_dream_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          BucketItemFormModal.show(context);
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required int count,
    required Color color,
    required bool isDark,
    required Color primaryTextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionEmptyState({
    required BuildContext context,
    required String text,
    required Color cardBg,
    required Color borderColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildOverallEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🪣', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('bucket_list_empty_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('bucket_list_empty_subtitle'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                context.tr('add_dream_btn'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                BucketItemFormModal.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a pending dream card with direct "🎉 Done" one-tap completion
  /// which immediately prompts for memory writing in the edit modal.
  Widget _buildPendingDreamCard({
    required BuildContext context,
    required WidgetRef ref,
    required BucketItemModel item,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📌', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    if (item.formattedTargetDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: secondaryTextColor),
                          const SizedBox(width: 5),
                          Text(
                            context.tr(
                              'target_date_label',
                              args: {'date': item.formattedTargetDate!},
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: secondaryTextColor,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  BucketItemFormModal.show(context, itemToEdit: item);
                },
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: const Color(0xFFEF4444),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(context, ref, item),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // "🎉 Done" Quick Completion Action
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                foregroundColor: const Color(0xFF10B981),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                ),
              ),
              icon: const Text('🎉', style: TextStyle(fontSize: 14)),
              label: Text(
                context.tr('bucket_done_btn'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final uid = ref.read(currentUserIdProvider);
                if (uid != null && uid.isNotEmpty) {
                  // 1. Mark status as completed
                  final completedItem = await ref
                      .read(bucketListServiceProvider)
                      .markItemCompleted(uid, item);

                  // 2. Show celebratory notification
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('dream_completed_toast')),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 3),
                      ),
                    );

                    // 3. Automatically open edit modal for reflective memory logging
                    BucketItemFormModal.show(context, itemToEdit: completedItem);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an achieved memory card with green accents and reflective memory note
  Widget _buildAchievedMemoryCard({
    required BuildContext context,
    required WidgetRef ref,
    required BucketItemModel item,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final accentGreen = const Color(0xFF10B981);
    final cardBg = isDark
        ? const Color(0xFF0F2D24).withValues(alpha: 0.6)
        : const Color(0xFFF0FDF4);
    final borderColor = accentGreen.withValues(alpha: isDark ? 0.35 : 0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: accentGreen,
                      ),
                    ),
                    if (item.formattedTargetDate != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        context.tr(
                          'target_date_label',
                          args: {'date': item.formattedTargetDate!},
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: secondaryTextColor,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  BucketItemFormModal.show(context, itemToEdit: item);
                },
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: const Color(0xFFEF4444),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(context, ref, item),
              ),
            ],
          ),

          // Reflective Memory Note Container
          if (item.memory != null && item.memory!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✍️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.memory!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: primaryTextColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, BucketItemModel item) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_item_dialog_title')),
        content: Text(context.tr('delete_item_dialog_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.tr('delete_item_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && uid.isNotEmpty) {
        await ref.read(bucketListServiceProvider).deleteBucketItem(uid, item.id);
      }
    }
  }
}
