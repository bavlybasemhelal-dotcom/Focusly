import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../groups/groups_home_page.dart';
import '../groups/models/group_model.dart';
import '../groups/providers/groups_provider.dart';
import 'providers/connected_accounts_provider.dart';

/// Screen for managing Connected Third-Party Accounts (Google Account)
/// and sharing Focusly Group invite codes via the platform native share sheet.
///
/// ARCHITECTURAL NOTE FOR BEGINNER MAINTAINERS:
/// -------------------------------------------------------------
/// 1. Account Linking:
///    The user's primary login remains Email/Password. Linking a Google
///    account connects the Google Auth credential directly to Firebase Auth's
///    `user.providerData` list (checking for 'google.com').
///
/// 2. Group Invites via Native Share (`share_plus`):
///    Instead of requesting intrusive address book permissions or building
///    a complex custom contact-sync backend, we reuse the existing Group
///    invite-code system (`GRP-XXXXXX`) and invoke the OS native share sheet.
///    Connecting a Google account makes Gmail and Google Contacts readily
///    available as instant share targets in the system picker.
class ConnectedAccountsPage extends ConsumerStatefulWidget {
  const ConnectedAccountsPage({super.key});

  @override
  ConsumerState<ConnectedAccountsPage> createState() =>
      _ConnectedAccountsPageState();
}

class _ConnectedAccountsPageState extends ConsumerState<ConnectedAccountsPage> {
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    // Observe Firebase Auth user changes for providerData
    final userAsync = ref.watch(currentUserStreamProvider);
    User? currentUser;
    try {
      currentUser = userAsync.value ?? FirebaseAuth.instance.currentUser;
    } catch (_) {
      currentUser = userAsync.value;
    }
    final linkService = ref.watch(accountLinkingServiceProvider);
    final isGoogleLinked = linkService.isGoogleLinked(currentUser);
    final linkedEmail = linkService.getLinkedGoogleEmail(currentUser);

    final isLoading = ref.watch(isAccountLinkingLoadingProvider);

    // Observe user's joined groups
    final groupsAsync = ref.watch(myGroupsStreamProvider);
    final groups = groupsAsync.value ?? <GroupModel>[];

    // Ensure selected group ID defaults to first group if available
    if (groups.isNotEmpty &&
        (_selectedGroupId == null ||
            !groups.any((g) => g.id == _selectedGroupId))) {
      _selectedGroupId = groups.first.id;
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('connected_accounts_title'),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: brandPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Ambient aurora bloom in background
          _buildAmbientGlowBlooms(isDark),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              children: [
                // -------------------------------------------------------------
                // SECTION 1: CONNECTED ACCOUNTS
                // -------------------------------------------------------------
                Text(
                  context.tr('connected_accounts_subtitle'),
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Google Account Card
                _buildGoogleAccountCard(
                  context: context,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  brandPrimary: brandPrimary,
                  isLinked: isGoogleLinked,
                  linkedEmail: linkedEmail,
                  isLoading: isLoading,
                ),

                const SizedBox(height: 32),

                // -------------------------------------------------------------
                // SECTION 2: INVITE FRIENDS TO A GROUP
                // -------------------------------------------------------------
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.share_rounded,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('invite_friends_section'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('invite_friends_desc'),
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),

                if (groups.isNotEmpty)
                  _buildGroupInviteCard(
                    context: context,
                    groups: groups,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    brandPrimary: brandPrimary,
                  )
                else
                  _buildEmptyGroupsCard(
                    context: context,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    brandPrimary: brandPrimary,
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Google Account linking card.
  Widget _buildGoogleAccountCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
    required bool isLinked,
    required String? linkedEmail,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Google Icon + Title + Status Pill
          Row(
            children: [
              // Google "G" Icon Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: _buildGoogleGIcon(),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('google_account_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLinked && linkedEmail != null
                          ? linkedEmail
                          : context.tr('google_account_desc'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isLinked ? const Color(0xFF10B981) : secondaryTextColor,
                        fontWeight: isLinked ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isLinked
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isLinked
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLinked
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLinked
                          ? context.tr('account_status_linked')
                          : context.tr('account_status_not_linked'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isLinked
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 16),

          // Action Button (Connect or Disconnect)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : isLinked
                    ? OutlinedButton.icon(
                        onPressed: () => _confirmDisconnectGoogle(context),
                        icon: const Icon(
                          Icons.link_off_rounded,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                        label: Text(
                          context.tr('disconnect_google_btn'),
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(connectedAccountsControllerProvider)
                              .connectGoogle(context);
                        },
                        icon: const Icon(
                          Icons.link_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          context.tr('connect_google_btn'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandPrimary,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Builds the Group Invite Card when user belongs to >= 1 group.
  Widget _buildGroupInviteCard({
    required BuildContext context,
    required List<GroupModel> groups,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
  }) {
    final selectedGroup = groups.firstWhere(
      (g) => g.id == _selectedGroupId,
      orElse: () => groups.first,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dropdown Label
          Text(
            context.tr('select_group_to_invite'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Group Dropdown Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedGroup.id,
                isExpanded: true,
                dropdownColor: cardBg,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: brandPrimary),
                items: groups.map((g) {
                  return DropdownMenuItem<String>(
                    value: g.id,
                    child: Row(
                      children: [
                        Text(
                          g.icon.isNotEmpty ? g.icon : '👥',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            g.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedGroupId = val;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Invite Code Preview Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                    : const Color(0xFFBFDBFE),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.vpn_key_rounded,
                  color: Color(0xFF3B82F6),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVITE CODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1D4ED8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedGroup.inviteCode,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Color(0xFF3B82F6),
                  ),
                  tooltip: 'Copy Invite Code',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(
                      ClipboardData(text: selectedGroup.inviteCode),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Code ${selectedGroup.inviteCode} copied!'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Share Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _shareGroupInvite(context, selectedGroup),
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                context.tr('share_invite_btn'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds prompt when user has 0 groups.
  Widget _buildEmptyGroupsCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: brandPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.groups_rounded,
                color: brandPrimary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('no_groups_invite_prompt'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GroupsHomePage(),
                  ),
                );
              },
              icon: Icon(Icons.arrow_forward_rounded, size: 16, color: brandPrimary),
              label: Text(
                context.tr('go_to_groups_btn'),
                style: TextStyle(
                  color: brandPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: brandPrimary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Triggers the native OS share sheet using `share_plus`.
  void _shareGroupInvite(BuildContext context, GroupModel group) {
    HapticFeedback.lightImpact();
    final message = context.tr(
      'group_invite_msg_template',
      args: {
        'groupName': group.name,
        'inviteCode': group.inviteCode,
      },
    );

    Share.share(
      message,
      subject: 'Focusly Group Invite: ${group.name}',
    );
  }

  /// Displays confirmation dialog before disconnecting Google account.
  Future<void> _confirmDisconnectGoogle(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            dialogCtx.tr('disconnect_google_dialog_title'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            dialogCtx.tr('disconnect_google_dialog_msg'),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(dialogCtx.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                dialogCtx.tr('disconnect_google_btn'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      ref
          .read(connectedAccountsControllerProvider)
          .disconnectGoogle(context);
    }
  }

  /// Renders a colorful Google "G" icon using standard Material Icons & Colors.
  Widget _buildGoogleGIcon() {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: Color(0xFF4285F4),
        fontFamily: 'sans-serif',
      ),
    );
  }

  /// Ambient decorative glow blooms
  Widget _buildAmbientGlowBlooms(bool isDark) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4285F4).withValues(
                  alpha: isDark ? 0.08 : 0.05,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(
                  alpha: isDark ? 0.08 : 0.04,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
