import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../contacts/providers/contacts_provider.dart';
import '../models/relationship_log_model.dart';
import '../providers/relationship_health_provider.dart';
import 'interaction_form_modal.dart';

/// Card widget rendering a single interaction log row in the Recent Interactions section.
class InteractionCard extends ConsumerWidget {
  final RelationshipLogModel log;

  const InteractionCard({super.key, required this.log});

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
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dialogCtx.tr('delete_interaction_confirm_title'),
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
          dialogCtx.tr('delete_interaction_confirm_msg'),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
        final service = ref.read(relationshipHealthServiceProvider);
        await service.deleteLog(uid: uid, logId: log.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('interaction_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
    final notesBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);

    // Resolve linked contact name
    final contacts = ref.watch(contactsStreamProvider).value ?? [];
    final contact = contacts.cast<dynamic>().firstWhere(
      (c) => c.id == log.contactId,
      orElse: () => null,
    );

    final contactName = contact != null
        ? contact.name as String
        : context.tr('unknown_contact_fallback');
    final contactEmoji = contact != null
        ? (contact.emoji as String? ?? '👤')
        : '👤';

    final dateStr =
        '${log.date.year}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Contact Name + Stars + Action Icons
            Row(
              children: [
                // Contact Emoji Avatar
                Text(contactEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),

                // Contact Name & Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Star Rating Display
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final isFilled = index < log.rating;
                    return Icon(
                      isFilled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: isFilled
                          ? const Color(0xFFF59E0B) // Amber Gold
                          : secondaryTextColor.withValues(alpha: 0.3),
                    );
                  }),
                ),
                const SizedBox(width: 8),

                // Edit Action
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: secondaryTextColor,
                  tooltip: context.tr('edit_interaction_title'),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    InteractionFormModal.show(context, logToEdit: log);
                  },
                ),
                const SizedBox(width: 2),

                // Delete Action
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

            // Optional Notes Quoted Box
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: notesBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 13,
                      color: secondaryTextColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: primaryTextColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
