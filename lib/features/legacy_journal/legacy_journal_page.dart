import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_colors.dart';
import 'models/legacy_entry_model.dart';
import 'providers/legacy_journal_provider.dart';
import 'widgets/legacy_entry_form_modal.dart';

/// Main screen for Focusly's Legacy Journal feature, dynamically rendering
/// sections for Letters to Future Self, Core Values, and Will Guidelines.
class LegacyJournalPage extends ConsumerWidget {
  const LegacyJournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    final allEntriesAsync = ref.watch(legacyJournalStreamProvider);
    final allEntries = allEntriesAsync.value ?? <LegacyEntryModel>[];
    final letters = ref.watch(letterEntriesProvider);
    final values = ref.watch(valueEntriesProvider);
    final willEntries = ref.watch(willEntriesProvider);

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
              context.tr('legacy_journal_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('legacy_journal_subtitle'),
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
      body: allEntriesAsync.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : allEntries.isEmpty
          ? _buildEmptyState(
              context,
              isDark,
              primaryTextColor,
              secondaryTextColor,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Letters to Future Self Section (Rendered only if letters exist)
                if (letters.isNotEmpty) ...[
                  _buildSectionHeader(
                    context: context,
                    title: context.tr('legacy_section_letters'),
                    accentColor: const Color(0xFF00E5FF),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  ...letters.map(
                    (entry) => _buildEntryCard(
                      context: context,
                      ref: ref,
                      entry: entry,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 2. Core Values & Beliefs Section (Rendered only if values exist)
                if (values.isNotEmpty) ...[
                  _buildSectionHeader(
                    context: context,
                    title: context.tr('legacy_section_values'),
                    accentColor: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  ...values.map(
                    (entry) => _buildEntryCard(
                      context: context,
                      ref: ref,
                      entry: entry,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 3. Will & Philosophy Guidelines Section (Rendered only if will entries exist)
                if (willEntries.isNotEmpty) ...[
                  _buildSectionHeader(
                    context: context,
                    title: context.tr('legacy_section_will'),
                    accentColor: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  ...willEntries.map(
                    (entry) => _buildEntryCard(
                      context: context,
                      ref: ref,
                      entry: entry,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          context.tr('new_legacy_entry_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          LegacyEntryFormModal.show(context);
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: accentColor.withValues(alpha: isDark ? 0.35 : 0.3),
            width: 1.8,
          ),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: accentColor,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildEntryCard({
    required BuildContext context,
    required WidgetRef ref,
    required LegacyEntryModel entry,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title, Date & Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
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
                  LegacyEntryFormModal.show(context, entryToEdit: entry);
                },
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: const Color(0xFFEF4444),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(context, ref, entry),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Inset Text Panel preserving line breaks
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: SelectableText(
              entry.content,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
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
                color: const Color(
                  0xFF6366F1,
                ).withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('✍️', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('empty_legacy_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('empty_legacy_subtitle'),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                context.tr('new_legacy_entry_btn'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                LegacyEntryFormModal.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LegacyEntryModel entry,
  ) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_legacy_dialog_title')),
        content: Text(context.tr('delete_legacy_dialog_msg')),
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
            child: Text(context.tr('delete_legacy_entry_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && uid.isNotEmpty) {
        await ref.read(legacyJournalServiceProvider).deleteEntry(uid, entry.id);
      }
    }
  }
}
