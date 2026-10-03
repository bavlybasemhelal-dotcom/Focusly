import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../contacts/contacts_page.dart';
import '../contacts/providers/contacts_provider.dart';
import 'providers/relationship_health_provider.dart';
import 'widgets/interaction_card.dart';
import 'widgets/interaction_form_modal.dart';
import 'widgets/keep_in_touch_card.dart';

/// Main Relationship Health screen displaying Recent Interactions and Keep In Touch lists.
class RelationshipHealthPage extends ConsumerWidget {
  const RelationshipHealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final recentInteractions = ref.watch(recentInteractionsProvider);
    final allLogsAsync = ref.watch(relationshipLogsStreamProvider);
    final contactsAsync = ref.watch(contactsStreamProvider);

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
              context.tr('relationship_health_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('relationship_health_subtitle'),
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
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFFEF4444),
            ),
            tooltip: context.tr('add_interaction_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              InteractionFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.favorite_rounded, size: 20),
        label: Text(
          context.tr('add_interaction_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          InteractionFormModal.show(context);
        },
      ),
      body: allLogsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFEF4444)),
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
        data: (allLogs) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            children: [
              // =======================================================
              // SECTION 1: RECENT INTERACTIONS (8 Most Recent)
              // =======================================================
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('recent_interactions_header'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (recentInteractions.isEmpty)
                _buildEmptyInteractionsState(
                  context,
                  primaryTextColor,
                  secondaryTextColor,
                )
              else
                ...recentInteractions.map((log) => InteractionCard(log: log)),

              const SizedBox(height: 24),

              // =======================================================
              // SECTION 2: KEEP IN TOUCH (All Contacts with Recency)
              // =======================================================
              Row(
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    size: 18,
                    color: Color(0xFF2E6FF2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('keep_in_touch_header'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              contactsAsync.when(
                loading: () => const SizedBox(
                  height: 60,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2E6FF2),
                    ),
                  ),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (contacts) {
                  if (contacts.isEmpty) {
                    return _buildNoContactsState(
                      context,
                      primaryTextColor,
                      secondaryTextColor,
                    );
                  }

                  return Column(
                    children: contacts
                        .map((c) => KeepInTouchCard(contact: c))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyInteractionsState(
    BuildContext context,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.favorite_rounded,
                size: 30,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('empty_interactions_title'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('empty_interactions_subtitle'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              context.tr('add_interaction_btn'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              InteractionFormModal.show(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoContactsState(
    BuildContext context,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            context.tr('no_contacts_registered_msg'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E6FF2),
              side: const BorderSide(color: Color(0xFF2E6FF2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_rounded, size: 16),
            label: Text(
              context.tr('go_to_contacts_btn'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ContactsPage()));
            },
          ),
        ],
      ),
    );
  }
}
