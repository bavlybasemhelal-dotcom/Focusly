import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/inbox_item_model.dart';
import 'providers/gtd_provider.dart';
import 'services/gtd_service.dart';
import 'widgets/clarify_wizard_sheet.dart';
import 'widgets/quick_capture_sheet.dart';

enum InboxFilter { all, unprocessed, processed }

/// Main GTD Inbox screen.
///
/// Displays raw captured thoughts, filter chips, relative timestamps,
/// and direct access to the Clarify Wizard.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  InboxFilter _activeFilter = InboxFilter.unprocessed;

  String _formatRelativeTime(DateTime dateTime, BuildContext context) {
    final diff = DateTime.now().difference(dateTime);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (diff.inMinutes < 1) {
      return isArabic ? 'الآن' : 'Just now';
    } else if (diff.inHours < 1) {
      return isArabic ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return isArabic ? 'منذ ${diff.inHours} س' : '${diff.inHours}h ago';
    } else {
      return isArabic ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);

    final inboxAsync = ref.watch(inboxStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildAmbientGlowBlooms(isDark),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------------------
                // 1. SCREEN HEADER & BACK BUTTON
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('inbox_screen_title'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: primaryTextColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              context.tr('inbox_screen_subtitle'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quick Capture header button
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E6FF2), Color(0xFF00D2FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E6FF2).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => QuickCaptureSheet.show(context),
                          icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                          tooltip: context.tr('quick_capture_title'),
                        ),
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 2. FILTER CHIPS (All / Unprocessed / Processed)
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: context.tr('inbox_filter_unprocessed'),
                        filter: InboxFilter.unprocessed,
                        isDark: isDark,
                        brandPrimary: brandPrimary,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: context.tr('inbox_filter_all'),
                        filter: InboxFilter.all,
                        isDark: isDark,
                        brandPrimary: brandPrimary,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: context.tr('inbox_filter_processed'),
                        filter: InboxFilter.processed,
                        isDark: isDark,
                        brandPrimary: brandPrimary,
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 3. INBOX LIST
                // -------------------------------------------------------------
                Expanded(
                  child: inboxAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text(
                        context.tr('inbox_load_error'),
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    ),
                    data: (items) {
                      final filteredItems = items.where((item) {
                        switch (_activeFilter) {
                          case InboxFilter.unprocessed:
                            return !item.processed;
                          case InboxFilter.processed:
                            return item.processed;
                          case InboxFilter.all:
                            return true;
                        }
                      }).toList();

                      if (filteredItems.isEmpty) {
                        return _buildEmptyState(context, isDark, primaryTextColor, secondaryTextColor);
                      }

                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildInboxRow(context, item, isDark, primaryTextColor, secondaryTextColor, brandPrimary);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required InboxFilter filter,
    required bool isDark,
    required Color brandPrimary,
  }) {
    final isSelected = _activeFilter == filter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? brandPrimary
              : (isDark ? const Color(0xFF0F1B4C) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? brandPrimary
                : (isDark ? Colors.white10 : const Color(0xFFE2E8F5)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInboxRow(
    BuildContext context,
    InboxItemModel item,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color brandPrimary,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F5);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0xFF2E6FF2).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.processed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: item.processed ? secondaryTextColor : primaryTextColor,
                    decoration: item.processed ? TextDecoration.lineThrough : null,
                    height: 1.3,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: secondaryTextColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (value) async {
                  if (value == 'delete') {
                    await GTDService().deleteInboxItem(item.id);
                  } else if (value == 'toggle') {
                    await GTDService().markInboxProcessed(item.id, processed: !item.processed);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          item.processed ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: primaryTextColor,
                        ),
                        const SizedBox(width: 8),
                        Text(item.processed ? ctx.tr('mark_unprocessed') : ctx.tr('mark_processed')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Text(ctx.tr('delete'), style: const TextStyle(color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    _formatRelativeTime(item.createdAt, context),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: secondaryTextColor),
                  ),
                ],
              ),
              if (!item.processed)
                GestureDetector(
                  onTap: () => ClarifyWizardSheet.show(context, item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E6FF2), Color(0xFF00D2FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E6FF2).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_fix_high_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          context.tr('inbox_clarify_btn'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.inbox_rounded, size: 48, color: Color(0xFF2E6FF2)),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('inbox_empty_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('inbox_empty_prompt'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => QuickCaptureSheet.show(context),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(context.tr('quick_capture_title')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF2E6FF2).withValues(alpha: 0.12)
                    : const Color(0xFF2E6FF2).withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
