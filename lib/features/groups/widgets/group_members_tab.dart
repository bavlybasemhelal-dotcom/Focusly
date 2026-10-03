import '../group_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';
import '../providers/groups_provider.dart';
import '../services/group_service.dart';

/// Members tab managing approved members, admin pending request approvals,
/// member removals, leaving, and group deletion.
class GroupMembersTab extends ConsumerWidget {
  final String groupId;
  final GroupModel group;

  const GroupMembersTab({
    super.key,
    required this.groupId,
    required this.group,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F5);

    final membersAsync = ref.watch(groupMembersStreamProvider(groupId));
    final currentUid = ref.watch(currentUserIdProvider) ?? '';

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          context.tr('members_load_error'),
          style: TextStyle(color: secondaryTextColor),
        ),
      ),
      data: (members) {
        final approved = members.where((m) => m.isApproved).toList();
        final pending = members.where((m) => m.isPending).toList();

        final currentUserMember = members
            .where((m) => m.uid == currentUid)
            .firstOrNull;
        final isCurrentUserAdmin = currentUserMember?.isAdmin == true;
        final canApprove =
            isCurrentUserAdmin || currentUserMember?.role == 'moderator';

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'إدارة الأدوار والدعوة وسجل القرارات'
                      : 'Roles, invitation & audit log',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupManagementPage(groupId: groupId),
                  ),
                ),
              ),
              // ---------------------------------------------------------------
              // 1. ADMIN-ONLY PENDING REQUESTS SECTION
              // ---------------------------------------------------------------
              if (canApprove && pending.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${pending.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('pending_requests_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: pending.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final member = pending[index];
                    return _buildPendingMemberRow(
                      context: context,
                      member: member,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // ---------------------------------------------------------------
              // 2. APPROVED MEMBERS SECTION
              // ---------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${context.tr('members_title')} (${approved.length}/${group.maxMembers})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: approved.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final member = approved[index];
                  final isSelf = member.uid == currentUid;

                  return _buildApprovedMemberRow(
                    context: context,
                    member: member,
                    isSelf: isSelf,
                    isCurrentUserAdmin: isCurrentUserAdmin,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    brandPrimary: brandPrimary,
                    isDark: isDark,
                  );
                },
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // 3. ACTIONS (Leave Group / Delete Group)
              // ---------------------------------------------------------------
              if (group.createdBy != currentUid) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLeaveGroup(context, currentUid),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      context.tr('leave_group_btn'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDeleteGroup(context, approved),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: Text(
                      context.tr('delete_group_btn'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingMemberRow({
    required BuildContext context,
    required GroupMemberModel member,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
          ),
          // Action Buttons: Approve (✅) & Reject (❌)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _approveMember(context, member),
                icon: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 26,
                ),
                tooltip: context.tr('approve_btn'),
              ),
              IconButton(
                onPressed: () => _rejectMember(context, member),
                icon: const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFEF4444),
                  size: 26,
                ),
                tooltip: context.tr('reject_btn'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedMemberRow({
    required BuildContext context,
    required GroupMemberModel member,
    required bool isSelf,
    required bool isCurrentUserAdmin,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelf
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
                  fontWeight: FontWeight.w900,
                  color: isSelf
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                    if (isSelf) ...[
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
                Text(
                  member.isAdmin
                      ? context.tr('role_admin')
                      : context.tr('role_member'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: member.isAdmin ? brandPrimary : secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUserAdmin && !isSelf)
            IconButton(
              onPressed: () => _confirmRemoveMember(context, member),
              icon: const Icon(
                Icons.person_remove_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              tooltip: context.tr('remove_member_btn'),
            ),
        ],
      ),
    );
  }

  Future<void> _approveMember(
    BuildContext context,
    GroupMemberModel member,
  ) async {
    try {
      await GroupService().approveMember(groupId, member.uid);
    } catch (e) {
      debugPrint('Error approving member: $e');
    }
  }

  Future<void> _rejectMember(
    BuildContext context,
    GroupMemberModel member,
  ) async {
    try {
      await GroupService().cancelPendingRequest(groupId, member.uid);
    } catch (e) {
      debugPrint('Error rejecting member: $e');
    }
  }

  void _confirmRemoveMember(BuildContext context, GroupMemberModel member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('remove_member_title')),
        content: Text(
          '${context.tr('remove_member_confirm')} "${member.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await GroupService().leaveGroup(groupId, member.uid);
              } catch (e) {
                debugPrint('Error removing member: $e');
              }
            },
            child: Text(
              context.tr('remove_member_btn'),
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(BuildContext context, String currentUid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('leave_group_title')),
        content: Text(context.tr('leave_group_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await GroupService().leaveGroup(groupId, currentUid);

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                debugPrint('Error leaving group: $e');
              }
            },
            child: Text(
              context.tr('leave_group_btn'),
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(
    BuildContext context,
    List<GroupMemberModel> members,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_group_title')),
        content: Text(context.tr('delete_group_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await GroupService().deleteGroup(groupId, members: members);

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                debugPrint('Error deleting group: $e');
              }
            },
            child: Text(
              context.tr('delete_group_btn'),
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
