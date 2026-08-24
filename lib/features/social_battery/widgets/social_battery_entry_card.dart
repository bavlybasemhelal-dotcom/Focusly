import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/social_battery_entry_model.dart';
import '../providers/social_battery_provider.dart';
import 'social_battery_form_modal.dart';

/// Card widget rendering a single Social Battery log entry row.
class SocialBatteryEntryCard extends ConsumerWidget {
  final SocialBatteryEntryModel entry;

  const SocialBatteryEntryCard({
    super.key,
    required this.entry,
  });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
                dialogCtx.tr('delete_social_entry_confirm_title'),
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
          dialogCtx.tr('delete_social_entry_confirm_msg'),
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
        final service = ref.read(socialBatteryServiceProvider);
        await service.deleteEntry(uid: uid, entryId: entry.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('social_entry_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final isEnergizer = entry.isEnergizer;
    final typeColor = isEnergizer ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final typeEmoji = isEnergizer ? '🔋' : '🪫';

    final badgeLabel = isEnergizer
        ? context.tr('energizer_badge', args: {'impact': entry.impact.toString()})
        : context.tr('drainer_badge', args: {'impact': entry.impact.toString()});

    final dateStr =
        '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Battery Emoji Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              typeEmoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),

          // Name, Type & Sub-row, Notes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Sub-row: Date + Type Impact Pill
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // Optional Notes
                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: secondaryTextColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action Icons (Edit & Delete)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: secondaryTextColor,
                tooltip: context.tr('edit_social_interaction_title'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  SocialBatteryFormModal.show(context, entryToEdit: entry);
                },
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                color: const Color(0xFFEF4444),
                tooltip: context.tr('delete'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
