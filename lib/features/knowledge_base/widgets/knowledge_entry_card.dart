import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/knowledge_entry_model.dart';
import '../providers/knowledge_base_provider.dart';
import 'entry_form_modal.dart';

/// Card widget rendering an individual knowledge base entry.
class KnowledgeEntryCard extends ConsumerWidget {
  final KnowledgeEntryModel entry;

  const KnowledgeEntryCard({
    super.key,
    required this.entry,
  });

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'idea':
        return const Color(0xFFF59E0B); // Amber
      case 'quote':
        return const Color(0xFF8B5CF6); // Purple
      case 'link':
        return const Color(0xFF0EA5E9); // Sky Blue
      case 'summary':
        return const Color(0xFF10B981); // Emerald
      case 'note':
      default:
        return const Color(0xFF2E6FF2); // Royal Blue
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'idea':
        return Icons.lightbulb_outline_rounded;
      case 'quote':
        return Icons.format_quote_rounded;
      case 'link':
        return Icons.link_rounded;
      case 'summary':
        return Icons.menu_book_rounded;
      case 'note':
      default:
        return Icons.edit_note_rounded;
    }
  }

  String _getTypeLabelKey(String type) {
    switch (type.toLowerCase()) {
      case 'idea':
        return 'knowledge_type_idea';
      case 'quote':
        return 'knowledge_type_quote';
      case 'link':
        return 'knowledge_type_link';
      case 'summary':
        return 'knowledge_type_summary';
      case 'note':
      default:
        return 'knowledge_type_note';
    }
  }

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
                dialogCtx.tr('delete_knowledge_confirm_title'),
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
          dialogCtx.tr(
            'delete_knowledge_confirm_msg',
            args: {'title': entry.title},
          ),
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
        final service = ref.read(knowledgeBaseServiceProvider);
        await service.deleteEntry(uid: uid, entryId: entry.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('knowledge_deleted_toast')),
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
    final tagBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9);

    final typeColor = _getTypeColor(entry.type);
    final typeIcon = _getTypeIcon(entry.type);
    final typeLabelKey = _getTypeLabelKey(entry.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Colored left accent spine
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(color: typeColor),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header: Type Pill + Title + Action Icons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 13, color: typeColor),
                            const SizedBox(width: 4),
                            Text(
                              context.tr(typeLabelKey),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Title
                      Expanded(
                        child: Text(
                          entry.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Edit Action
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: secondaryTextColor,
                        tooltip: context.tr('edit_knowledge_title'),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          EntryFormModal.show(context, entryToEdit: entry);
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
                        onPressed: () => _confirmDelete(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Content (Preserving line breaks / white-space: pre-wrap)
                  Text(
                    entry.content,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: primaryTextColor.withValues(alpha: 0.9),
                    ),
                    softWrap: true,
                  ),

                  // Optional Source Line
                  if (entry.source != null && entry.source!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 13,
                          color: secondaryTextColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${context.tr('source_prefix')}: ${entry.source}',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: secondaryTextColor.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Tag Chips
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tagBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
