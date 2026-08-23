import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/challenge_model.dart';
import '../providers/groups_provider.dart';
import '../services/challenge_service.dart';
import 'create_challenge_sheet.dart';

/// Challenges tab displaying active group competitions, participant progress bars,
/// join actions, and victory celebrations.
class GroupChallengesTab extends ConsumerStatefulWidget {
  final String groupId;

  const GroupChallengesTab({super.key, required this.groupId});

  @override
  ConsumerState<GroupChallengesTab> createState() => _GroupChallengesTabState();
}

class _GroupChallengesTabState extends ConsumerState<GroupChallengesTab> {
  bool _evaluatedAutoFinish = false;

  @override
  void initState() {
    super.initState();
    ChallengeService().syncAllActiveChallenges();
  }

  void _checkAutoFinish(List<ChallengeModel> challenges) async {
    if (_evaluatedAutoFinish) return;
    _evaluatedAutoFinish = true;

    final wonChallengeTitle = await ChallengeService().evaluateAutoFinish(
      groupId: widget.groupId,
      challenges: challenges,
    );

    if (wonChallengeTitle != null && mounted) {
      _showWinnerCelebrationDialog(wonChallengeTitle);
    }
  }

  void _showWinnerCelebrationDialog(String challengeTitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 14),
              Text(
                context.tr('challenge_victory_title'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF59E0B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${context.tr('challenge_victory_msg')} "$challengeTitle"!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.tr('celebrate_btn'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F5);
    final challengesAsync =
        ref.watch(groupChallengesStreamProvider(widget.groupId));
    final currentUid = ref.watch(currentUserIdProvider) ?? '';

    return challengesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          context.tr('challenges_load_error'),
          style: TextStyle(color: secondaryTextColor),
        ),
      ),
      data: (challenges) {
        _checkAutoFinish(challenges);

        final active = challenges.where((c) => c.isActive).toList();
        final finished = challenges.where((c) => c.isFinished).toList();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------------------------------------------------
              // 1. CREATE CHALLENGE ACTION BUTTON
              // ---------------------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => CreateChallengeSheet(
                        groupId: widget.groupId,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    context.tr('create_challenge_btn'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brandPrimary,
                    side: BorderSide(color: brandPrimary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ---------------------------------------------------------------
              // 2. ACTIVE CHALLENGES SECTION
              // ---------------------------------------------------------------
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('active_challenges_title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (active.isEmpty)
                _buildEmptyActiveCard(
                  context,
                  isDark,
                  primaryTextColor,
                  secondaryTextColor,
                )
              else
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _ChallengeCard(
                      groupId: widget.groupId,
                      challenge: active[index],
                      currentUid: currentUid,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      isDark: isDark,
                    );
                  },
                ),

              // ---------------------------------------------------------------
              // 3. FINISHED CHALLENGES SECTION
              // ---------------------------------------------------------------
              if (finished.isNotEmpty) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('finished_challenges_title'),
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
                  itemCount: finished.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _FinishedChallengeCard(
                      challenge: finished[index],
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyActiveCard(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F5),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 10),
            Text(
              context.tr('no_active_challenges_title'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('no_active_challenges_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  final String groupId;
  final ChallengeModel challenge;
  final String currentUid;
  final Color cardBg;
  final Color borderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color brandPrimary;
  final bool isDark;

  const _ChallengeCard({
    required this.groupId,
    required this.challenge,
    required this.currentUid,
    required this.cardBg,
    required this.borderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.brandPrimary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(
      challengeParticipantsStreamProvider((
        groupId: groupId,
        challengeId: challenge.id,
      )),
    );

    final participants = participantsAsync.value ?? [];
    final userParticipant =
        participants.where((p) => p.uid == currentUid).firstOrNull;
    final hasJoined = userParticipant != null;
    final userScore = userParticipant?.score ?? 0;
    final progressRatio = (userScore / challenge.goal).clamp(0.0, 1.0);

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Emoji + Title + Days Remaining Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: brandPrimary.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    challenge.typeEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${context.tr('goal_prefix')}: ${challenge.goal} ${context.tr(challenge.typeTitleKey)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${challenge.daysRemaining}d ${context.tr('left_short')}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar or Join Button
          if (hasJoined) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: progressRatio,
                  backgroundColor: isDark
                      ? Colors.white10
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressRatio >= 1.0
                        ? const Color(0xFF10B981)
                        : brandPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$userScore / ${challenge.goal} (${(progressRatio * 100).toInt()}%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: progressRatio >= 1.0
                        ? const Color(0xFF10B981)
                        : brandPrimary,
                  ),
                ),
                Text(
                  '${challenge.participantCount} ${context.tr('participants_label')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${challenge.participantCount} ${context.tr('participants_label')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final joined = await ChallengeService().joinChallenge(
                      groupId: groupId,
                      challengeId: challenge.id,
                      type: challenge.type,
                    );
                    if (joined && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          content: Text(
                            context.tr('joined_challenge_success'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.tr('join_btn'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FinishedChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final Color cardBg;
  final Color borderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final bool isDark;

  const _FinishedChallengeCard({
    required this.challenge,
    required this.cardBg,
    required this.borderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A102D).withValues(alpha: 0.7)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  challenge.winnerName != null
                      ? '${context.tr('winner_prefix')}: ${challenge.winnerName} (${challenge.winnerScore ?? 0} pts)'
                      : context.tr('challenge_ended_no_winner'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
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
