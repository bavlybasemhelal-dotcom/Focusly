import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/contact_model.dart';
import 'providers/contacts_provider.dart';
import 'widgets/add_edit_contact_sheet.dart';

/// Main Personal CRM (Contacts) Screen.
///
/// Features contact list cards with overdue tracking, quick "Mark contacted today" action,
/// filter switching between All vs Due contacts, and smooth animations.
class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final contactsAsync = ref.watch(contactsStreamProvider);
    final filter = ref.watch(contactsFilterProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('contacts_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFF2E6FF2),
            ),
            tooltip: context.tr('add_contact_title'),
            onPressed: () => AddEditContactSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Filter Chips: All vs Due for Contact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A1232) : const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  context: context,
                  ref: ref,
                  label: context.tr('all_contacts_filter'),
                  filterKey: 'all',
                  currentFilter: filter,
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context: context,
                  ref: ref,
                  label: context.tr('due_contacts_filter'),
                  filterKey: 'due',
                  currentFilter: filter,
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  isWarning: true,
                ),
              ],
            ),
          ),

          // 2. Contacts List / Grid View
          Expanded(
            child: contactsAsync.when(
              data: (contacts) {
                final displayedContacts = filter == 'due'
                    ? (contacts.where((c) => c.isDue).toList()..sort(
                        (a, b) => b.overdueByDays.compareTo(a.overdueByDays),
                      ))
                    : contacts;

                if (displayedContacts.isEmpty) {
                  return _buildEmptyState(
                    context: context,
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    isDueFilter: filter == 'due',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                  itemCount: displayedContacts.length,
                  itemBuilder: (context, index) {
                    final contact = displayedContacts[index];
                    return _buildContactCard(
                      context: context,
                      ref: ref,
                      contact: contact,
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      borderColor: borderColor,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  context.tr('contacts_load_error'),
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddEditContactSheet.show(context),
        backgroundColor: const Color(0xFF2E6FF2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          context.tr('add_contact_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required String filterKey,
    required String currentFilter,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    bool isWarning = false,
  }) {
    final isSelected = currentFilter == filterKey;
    final activeColor = isWarning
        ? const Color(0xFFEF4444)
        : const Color(0xFF2E6FF2);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(contactsFilterProvider.notifier).setFilter(filterKey);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF0F1B4C) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWarning && isSelected) ...[
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required BuildContext context,
    required WidgetRef ref,
    required ContactModel contact,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    final isDue = contact.isDue;
    final badgeBg = isDue
        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
        : const Color(0xFF10B981).withValues(alpha: 0.12);
    final badgeTextColor = isDue
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    final badgeBorderColor = isDue
        ? const Color(0xFFEF4444).withValues(alpha: 0.3)
        : const Color(0xFF10B981).withValues(alpha: 0.3);

    final daysAgo = contact.daysSinceLast;
    final badgeText = !contact.hasContacted
        ? (Localizations.localeOf(context).languageCode == 'ar'
              ? 'لم يُسجَّل تواصل بعد'
              : 'No contact recorded yet')
        : isDue
        ? '⚠️ $daysAgo ${context.tr('days_ago_suffix')} • +${contact.overdueByDays}d ${context.tr('overdue_label')}'
        : '✅ $daysAgo ${context.tr('days_ago_suffix')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDue
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : borderColor,
          width: isDue ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDue ? const Color(0xFFEF4444) : const Color(0xFF2E6FF2))
                .withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Role & Action Buttons
            Row(
              children: [
                // Avatar Emoji Box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF08123A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      contact.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      if (contact.role != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E6FF2,
                            ).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            contact.role!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E6FF2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Quick Action: Mark as contacted today
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  color: const Color(0xFF10B981),
                  tooltip: context.tr('mark_contacted_today_btn'),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final uid = ref.read(currentUserIdProvider);
                    if (uid != null) {
                      await ref
                          .read(contactsServiceProvider)
                          .markContactedToday(uid: uid, contactId: contact.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(
                                'marked_contacted_today_toast',
                                args: {'name': contact.name},
                              ),
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),

                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: secondaryTextColor,
                  tooltip: context.tr('edit'),
                  onPressed: () =>
                      AddEditContactSheet.show(context, contact: contact),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle: Contact Info line (if present)
            if (contact.contactInfo != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.alternate_email_rounded,
                    size: 14,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      contact.contactInfo!,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Notes preview (if present)
            if (contact.notes != null) ...[
              Text(
                '“${contact.notes}”',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: secondaryTextColor,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
            ],

            // Bottom: Days Since Last Contact Badge & Reconnect Interval
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Days Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeBorderColor),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeTextColor,
                    ),
                  ),
                ),

                // Interval Hint
                Text(
                  '${context.tr('every_interval_prefix')} ${contact.remindDays} ${context.tr('days_unit')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isDueFilter,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color:
                    (isDueFilter
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2E6FF2))
                        .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isDueFilter ? '🎉' : '👥',
                  style: const TextStyle(fontSize: 38),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isDueFilter
                  ? context.tr('no_due_contacts_title')
                  : context.tr('no_contacts_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isDueFilter
                  ? context.tr('no_due_contacts_subtitle')
                  : context.tr('no_contacts_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            if (!isDueFilter) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => AddEditContactSheet.show(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(context.tr('add_first_contact_btn')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E6FF2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
