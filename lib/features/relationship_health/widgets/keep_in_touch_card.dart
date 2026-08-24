import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../contacts/models/contact_model.dart';
import '../helpers/relationship_health_helpers.dart';
import '../models/relationship_log_model.dart';
import '../providers/relationship_health_provider.dart';
import 'interaction_form_modal.dart';

/// Card widget rendering a single contact row in the Keep In Touch recency section.
class KeepInTouchCard extends ConsumerWidget {
  final ContactModel contact;

  const KeepInTouchCard({
    super.key,
    required this.contact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final allLogs = ref.watch(relationshipLogsStreamProvider).value ?? [];
    final recency = RelationshipHealthHelpers.computeRecency(contact, allLogs);

    String badgeLabel;
    if (recency.category == RecencyCategory.never) {
      badgeLabel = context.tr('never_contacted_badge');
    } else {
      final days = recency.days ?? 0;
      if (days == 0) {
        badgeLabel = context.tr('contacted_today_badge');
      } else if (days == 1) {
        badgeLabel = context.tr('contacted_yesterday_badge');
      } else {
        badgeLabel = context.tr('contacted_days_ago_badge', args: {'days': days.toString()});
      }
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        InteractionFormModal.show(context, preselectedContactId: contact.id);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            // Contact Emoji Avatar
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                contact.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),

            // Contact Name & Role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (contact.role != null && contact.role!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      contact.role!,
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Recency Badge (Color coded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: recency.badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: recency.badgeColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: recency.badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
