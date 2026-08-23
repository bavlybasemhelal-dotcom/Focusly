import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'group_detail_page.dart';
import 'models/group_model.dart';
import 'providers/groups_provider.dart';
import 'services/group_feed_service.dart';
import 'widgets/create_group_sheet.dart';
import 'widgets/join_group_sheet.dart';

/// Main screen for Focusly Groups & Challenges.
class GroupsHomePage extends ConsumerWidget {
  const GroupsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final groupsAsync = ref.watch(myGroupsStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Aurora Bloom
          _buildAmbientGlowBlooms(isDark),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -----------------------------------------------------------
                  // 1. SCREEN HEADER
                  // -----------------------------------------------------------
                  Text(
                    context.tr('groups_and_challenges_title'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('groups_subtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // -----------------------------------------------------------
                  // 2. ACTION BUTTONS (Create Group / Join Group)
                  // -----------------------------------------------------------
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const CreateGroupSheet(),
                            );
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            context.tr('create_group_btn'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const JoinGroupSheet(),
                            );
                          },
                          icon: const Icon(Icons.tag_rounded, size: 18),
                          label: Text(
                            context.tr('join_group_btn'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: brandPrimary,
                            side: BorderSide(color: brandPrimary, width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // -----------------------------------------------------------
                  // 3. GROUPS LIST
                  // -----------------------------------------------------------
                  groupsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        context.tr('groups_load_error'),
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    ),
                    data: (groups) {
                      if (groups.isEmpty) {
                        return _buildEmptyState(
                          context,
                          isDark,
                          brandPrimary,
                          primaryTextColor,
                          secondaryTextColor,
                        );
                      }

                      return ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _GroupListCard(
                            group: group,
                            isDark: isDark,
                            brandPrimary: brandPrimary,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color brandPrimary,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F5),
        ),
      ),
      child: Column(
        children: [
          const Text('👥', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(
            context.tr('empty_groups_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('empty_groups_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const CreateGroupSheet(),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              context.tr('create_first_group_btn'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: -90,
          right: -70,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF38BDF8)
                  .withValues(alpha: isDark ? 0.12 : 0.14),
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupListCard extends ConsumerWidget {
  final GroupModel group;
  final bool isDark;
  final Color brandPrimary;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  const _GroupListCard({
    required this.group,
    required this.isDark,
    required this.brandPrimary,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  Future<bool> _hasUnreadActivity(WidgetRef ref) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('group_activity_badges_enabled') ?? true;
      if (!enabled) return false;

      final lastViewed = await GroupFeedService().getGroupLastViewed(group.id);
      if (lastViewed == null) return false;

      final feedAsync = ref.read(groupFeedStreamProvider(group.id));
      final items = feedAsync.value ?? [];
      if (items.isNotEmpty && items.first.createdAt.isAfter(lastViewed)) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F5);

    return FutureBuilder<bool>(
      future: _hasUnreadActivity(ref),
      builder: (context, snapshot) {
        final isUnread = snapshot.data ?? false;

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GroupDetailPage(groupId: group.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
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
                // Group Icon
                Container(
                  width: 52,
                  height: 52,
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
                      group.icon,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Group Name, Description, Members
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              group.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: primaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                context.tr('new_activity_badge'),
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
                      if (group.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          group.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${group.memberCount}/${group.maxMembers} ${context.tr('members_label')}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: secondaryTextColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
