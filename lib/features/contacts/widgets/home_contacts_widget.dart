import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../contacts_page.dart';
import '../providers/contacts_provider.dart';

/// Home screen widget prompting the user to reconnect with overdue contacts.
///
/// Only visible if at least 1 contact is currently overdue.
class HomeContactsWidget extends ConsumerWidget {
  const HomeContactsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdueContacts = ref.watch(overdueContactsProvider);
    if (overdueContacts.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    // Display up to 3 overdue contacts on Home
    final previewList = overdueContacts.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFFEF4444).withValues(alpha: 0.3)
              : const Color(0xFFFCA5A5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactsPage()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Title, Counter Badge & "View All" link
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('people_to_reach_out_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${overdueContacts.length} ${context.tr('due_label')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Overdue Contacts Mini List
                ...previewList.map((contact) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(contact.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contact.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                if (contact.role != null)
                                  Text(
                                    contact.role!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.tr('reach_out_cta'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
