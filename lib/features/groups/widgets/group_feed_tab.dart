import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/group_feed_model.dart';
import '../providers/groups_provider.dart';
import '../services/group_feed_service.dart';

/// Feed tab displaying live group activity stream, weekly stats strip,
/// and interactive atomic emoji reactions.
class GroupFeedTab extends ConsumerWidget {
  final String groupId;

  const GroupFeedTab({super.key, required this.groupId});

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
      return isArabic ? 'منذ ${diff.inDays} ي' : '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F5);

    final stats = ref.watch(groupStatsSummaryProvider(groupId));
    final feedAsync = ref.watch(groupFeedStreamProvider(groupId));
    final currentUid = ref.watch(currentUserIdProvider) ?? '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------------
          // 1. TOP STATS STRIP (Weekly XP, Active Members, Recent Activity)
          // -------------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : const Color(0xFF2E6FF2).withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildStatCell(
                  label: context.tr('group_stat_weekly_xp'),
                  value: '${stats.totalWeeklyXP}',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF38BDF8),
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                _buildDivider(borderColor),
                _buildStatCell(
                  label: context.tr('group_stat_active_members'),
                  value: '${stats.activeMembersCount}',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                _buildDivider(borderColor),
                _buildStatCell(
                  label: context.tr('group_stat_activities'),
                  value: '${stats.recentActivityCount}',
                  icon: Icons.dynamic_feed_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // 2. RECENT ACTIVITY HEADER
          // -------------------------------------------------------------------
          Row(
            children: [
              Icon(Icons.stream_rounded, size: 18, color: brandPrimary),
              const SizedBox(width: 8),
              Text(
                context.tr('group_activity_feed_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // 3. LIVE FEED STREAM LIST
          // -------------------------------------------------------------------
          feedAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  context.tr('feed_load_error'),
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
            ),
            data: (feedItems) {
              if (feedItems.isEmpty) {
                return _buildEmptyFeed(
                  context,
                  isDark,
                  primaryTextColor,
                  secondaryTextColor,
                );
              }

              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: feedItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = feedItems[index];
                  return _buildFeedItemCard(
                    item: item,
                    currentUid: currentUid,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    brandPrimary: brandPrimary,
                    isDark: isDark,
                    context: context,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: primaryTextColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color borderColor) {
    return Container(
      width: 1,
      height: 36,
      color: borderColor,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildFeedItemCard({
    required GroupFeedModel item,
    required String currentUid,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
    required bool isDark,
    required BuildContext context,
  }) {
    final userReaction = item.getUserReaction(currentUid);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Member Icon + Name + Relative Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0B1238)
                          : const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: brandPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        _formatRelativeTime(item.createdAt, context),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Message Content
          Text(
            item.message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 14),

          // Reaction Buttons Row: 👍 Like, 🔥 Fire, 👏 Clap
          Row(
            children: [
              _buildReactionButton(
                emoji: '👍',
                count: item.likeCount,
                isSelected: userReaction == 'like',
                onTap: () {
                  GroupFeedService().toggleReaction(
                    groupId: groupId,
                    feedId: item.id,
                    emojiType: 'like',
                  );
                },
                brandPrimary: brandPrimary,
                isDark: isDark,
                borderColor: borderColor,
              ),
              const SizedBox(width: 8),
              _buildReactionButton(
                emoji: '🔥',
                count: item.fireCount,
                isSelected: userReaction == 'fire',
                onTap: () {
                  GroupFeedService().toggleReaction(
                    groupId: groupId,
                    feedId: item.id,
                    emojiType: 'fire',
                  );
                },
                brandPrimary: const Color(0xFFF59E0B),
                isDark: isDark,
                borderColor: borderColor,
              ),
              const SizedBox(width: 8),
              _buildReactionButton(
                emoji: '👏',
                count: item.clapCount,
                isSelected: userReaction == 'clap',
                onTap: () {
                  GroupFeedService().toggleReaction(
                    groupId: groupId,
                    feedId: item.id,
                    emojiType: 'clap',
                  );
                },
                brandPrimary: const Color(0xFF10B981),
                isDark: isDark,
                borderColor: borderColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButton({
    required String emoji,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required Color brandPrimary,
    required bool isDark,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? brandPrimary.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? brandPrimary : borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? brandPrimary
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFeed(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Column(
          children: [
            const Text('💬', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text(
              context.tr('empty_feed_title'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('empty_feed_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
