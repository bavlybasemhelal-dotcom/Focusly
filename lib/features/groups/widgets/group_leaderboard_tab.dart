import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/group_member_model.dart';
import '../providers/groups_provider.dart';

/// Leaderboard tab displaying ranked group members by weekly XP
/// with gold, silver, and bronze visual treatments for top performers.
class GroupLeaderboardTab extends ConsumerWidget {
  final String groupId;

  const GroupLeaderboardTab({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F5);
    String currentUid = '';
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {}

    final leaderboard = ref.watch(groupLeaderboardProvider(groupId));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------------
          // 1. WEEKLY RESET BANNER
          // -------------------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF0F1B4C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                    : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('leaderboard_weekly_notice'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // 2. LEADERBOARD LIST
          // -------------------------------------------------------------------
          if (leaderboard.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  context.tr('no_leaderboard_members'),
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: leaderboard.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final member = leaderboard[index];
                final rank = index + 1;
                final isCurrentUser = member.uid == currentUid;

                return _buildLeaderboardRow(
                  member: member,
                  rank: rank,
                  isCurrentUser: isCurrentUser,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  brandPrimary: brandPrimary,
                  isDark: isDark,
                  context: context,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow({
    required GroupMemberModel member,
    required int rank,
    required bool isCurrentUser,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
    required bool isDark,
    required BuildContext context,
  }) {
    Color rankColor = secondaryTextColor;
    String rankBadge = '#$rank';
    Color rowBg = isCurrentUser
        ? (isDark
            ? brandPrimary.withValues(alpha: 0.18)
            : brandPrimary.withValues(alpha: 0.08))
        : cardBg;

    Color rowBorder = isCurrentUser
        ? brandPrimary.withValues(alpha: 0.5)
        : borderColor;

    if (rank == 1) {
      rankColor = const Color(0xFFF59E0B); // Gold
      rankBadge = '🥇';
    } else if (rank == 2) {
      rankColor = const Color(0xFF94A3B8); // Silver
      rankBadge = '🥈';
    } else if (rank == 3) {
      rankColor = const Color(0xFFD97706); // Bronze
      rankBadge = '🥉';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: rowBorder, width: isCurrentUser ? 1.5 : 1.0),
        boxShadow: rank <= 3
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: isDark ? 0.12 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank Badge or Medal
          SizedBox(
            width: 34,
            child: Center(
              child: rank <= 3
                  ? Text(rankBadge, style: const TextStyle(fontSize: 22))
                  : Text(
                      rankBadge,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // User Avatar Initial Circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? brandPrimary
                  : (isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isCurrentUser
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Member Name & Role / You Tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: brandPrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.tr('you_badge'),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (member.isAdmin)
                  Text(
                    context.tr('role_admin'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: brandPrimary,
                    ),
                  ),
              ],
            ),
          ),

          // Weekly XP Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0B1238)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '${member.weeklyXP} XP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
