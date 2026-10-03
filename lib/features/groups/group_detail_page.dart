import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'assignments/widgets/group_assignments_tab.dart';
import 'providers/groups_provider.dart';
import 'services/group_feed_service.dart';
import 'widgets/group_challenges_tab.dart';
import 'widgets/group_feed_tab.dart';
import 'widgets/group_leaderboard_tab.dart';
import 'widgets/group_members_tab.dart';

/// Comprehensive Group Detail screen hosting the Feed, Leaderboard,
/// Challenges, Assignments, and Members tabs.
class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  int _selectedTab =
      0; // 0: Feed, 1: Leaderboard, 2: Challenges, 3: Assignments, 4: Members

  @override
  void initState() {
    super.initState();
    GroupFeedService().markGroupViewed(widget.groupId);
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF10B981),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          context.tr('invite_code_copied'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F5);

    final groupAsync = ref.watch(groupDetailStreamProvider(widget.groupId));
    final currentUid = ref.watch(currentUserIdProvider) ?? '';

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Aurora Blooms
          _buildAmbientGlowBlooms(isDark),

          SafeArea(
            child: groupAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  context.tr('group_load_error'),
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
              data: (group) {
                if (group == null) {
                  return Center(
                    child: Text(
                      context.tr('group_not_found'),
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  );
                }

                final isAdmin = group.createdBy == currentUid;

                return Column(
                  children: [
                    // ---------------------------------------------------------
                    // 1. TOP APP BAR & GROUP HEADER
                    // ---------------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: primaryTextColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                group.icon,
                                style: const TextStyle(fontSize: 26),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: primaryTextColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${group.memberCount} ${context.tr('members_label')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: brandPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Admin Invite Code Card
                          if (isAdmin) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        context.tr('invite_code_label'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        group.inviteCode,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: brandPrimary,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () =>
                                        _copyInviteCode(group.inviteCode),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: brandPrimary.withValues(
                                          alpha: isDark ? 0.25 : 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.copy_rounded,
                                            size: 13,
                                            color: brandPrimary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            context.tr('copy_btn'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: brandPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // ---------------------------------------------------
                          // 2. FIVE SUB-TAB SWITCHER (Feed, Leaderboard, Challenges, Assignments, Members)
                          // ---------------------------------------------------
                          Container(
                            height: 44,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F1B4C)
                                  : const Color(0xFFE2E8F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                _buildSubTabItem(
                                  index: 0,
                                  title: context.tr('tab_group_feed'),
                                  icon: Icons.dynamic_feed_rounded,
                                  brandPrimary: brandPrimary,
                                  isDark: isDark,
                                ),
                                _buildSubTabItem(
                                  index: 1,
                                  title: context.tr('tab_group_leaderboard'),
                                  icon: Icons.leaderboard_rounded,
                                  brandPrimary: brandPrimary,
                                  isDark: isDark,
                                ),
                                _buildSubTabItem(
                                  index: 2,
                                  title: context.tr('tab_group_challenges'),
                                  icon: Icons.military_tech_rounded,
                                  brandPrimary: brandPrimary,
                                  isDark: isDark,
                                ),
                                _buildSubTabItem(
                                  index: 3,
                                  title: context.tr('tab_group_assignments'),
                                  icon: Icons.assignment_turned_in_rounded,
                                  brandPrimary: brandPrimary,
                                  isDark: isDark,
                                ),
                                _buildSubTabItem(
                                  index: 4,
                                  title: context.tr('tab_group_members'),
                                  icon: Icons.people_alt_rounded,
                                  brandPrimary: brandPrimary,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ---------------------------------------------------------
                    // 3. TAB CONTENT
                    // ---------------------------------------------------------
                    Expanded(
                      child: IndexedStack(
                        index: _selectedTab,
                        children: [
                          GroupFeedTab(groupId: widget.groupId),
                          GroupLeaderboardTab(groupId: widget.groupId),
                          GroupChallengesTab(groupId: widget.groupId),
                          GroupAssignmentsTab(
                            groupId: widget.groupId,
                            group: group,
                          ),
                          GroupMembersTab(
                            groupId: widget.groupId,
                            group: group,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabItem({
    required int index,
    required String title,
    required IconData icon,
    required Color brandPrimary,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.05,
                      ),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? brandPrimary
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF38BDF8,
              ).withValues(alpha: isDark ? 0.12 : 0.14),
            ),
          ),
        ),
      ],
    );
  }
}
