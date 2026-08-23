import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../gtd/inbox_screen.dart';
import '../../gtd/providers/gtd_provider.dart';
import '../../gtd/services/gtd_service.dart';
import '../../para/projects_page.dart';
import '../../para/providers/para_provider.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../providers/weekly_review_provider.dart';

/// 6-Step guided Weekly Review Wizard ("Get Clear, Get Current, Get Creative").
///
/// Steps:
/// 1. Mind Sweep (Textarea Dump -> Immediately writes to GTD Inbox)
/// 2. Get Clear (Inbox count & review prompt)
/// 3. Get Current (PARA Projects count & review prompt)
/// 4. Get Current (Tasks count & review prompt)
/// 5. Get Current (Someday/Maybe list with in-place "Activate ⚡" action)
/// 6. Get Creative (Weekly Priorities -> Dual writes to WeeklyReviews & GTD Inbox)
class WeeklyReviewWizard extends ConsumerStatefulWidget {
  const WeeklyReviewWizard({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WeeklyReviewWizard(),
    );
  }

  @override
  ConsumerState<WeeklyReviewWizard> createState() => _WeeklyReviewWizardState();
}

class _WeeklyReviewWizardState extends ConsumerState<WeeklyReviewWizard> {
  int _currentStep = 0; // 0 to 5
  bool _isProcessing = false;

  // Step 1: Mind Sweep controller
  final TextEditingController _mindSweepController = TextEditingController();

  // Step 6: Weekly Priorities controllers
  final TextEditingController _priority1Controller = TextEditingController();
  final TextEditingController _priority2Controller = TextEditingController();
  final TextEditingController _priority3Controller = TextEditingController();

  @override
  void dispose() {
    _mindSweepController.dispose();
    _priority1Controller.dispose();
    _priority2Controller.dispose();
    _priority3Controller.dispose();
    super.dispose();
  }

  /// Step 1 Next handler:
  ///
  /// ARCHITECTURAL NOTE:
  /// Step 1's Inbox writes happen immediately upon clicking Next (not deferred to Finish).
  /// This ensures that raw thoughts captured during the Mind Sweep are never lost if the user
  /// exits or gets interrupted during later review steps.
  Future<void> _handleStep1Next() async {
    final rawText = _mindSweepController.text;
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isNotEmpty) {
      setState(() => _isProcessing = true);
      int addedCount = 0;

      for (final line in lines) {
        final id = await GTDService().addInboxItem(line);
        if (id != null) addedCount++;
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _mindSweepController.clear();
        });

        if (addedCount > 0) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('mind_sweep_added_toast', args: {'count': addedCount.toString()}),
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }

    _nextStep();
  }

  /// Step 5 Promote Someday item to Active Task
  Future<void> _handlePromoteSomeday(TaskModel task) async {
    HapticFeedback.selectionClick();
    await GTDService().promoteSomedayToTask(
      task.id,
      newDate: DateTime.now(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('review_someday_promoted_toast', args: {'title': task.title}),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Step 6 Finish Weekly Review handler:
  ///
  /// Dual-writes priorities to `weeklyReviews` and `inbox`, updates `lastReviewDate`,
  /// and awards +40 XP.
  Future<void> _handleFinishReview() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final priorities = [
      _priority1Controller.text.trim(),
      _priority2Controller.text.trim(),
      _priority3Controller.text.trim(),
    ];

    setState(() => _isProcessing = true);

    final prefix = context.tr('weekly_priority_inbox_prefix');
    final success = await ref.read(weeklyReviewServiceProvider).finishWeeklyReview(
          uid: uid,
          priorities: priorities,
          priorityPrefix: prefix,
          ref: ref,
        );

    if (mounted) {
      setState(() => _isProcessing = false);

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('weekly_review_completed_toast')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _nextStep() {
    HapticFeedback.selectionClick();
    if (_currentStep < 5) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    HapticFeedback.selectionClick();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F5);
    final inputBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);

    final stepTitles = [
      context.tr('review_step_1_title'),
      context.tr('review_step_2_title'),
      context.tr('review_step_3_title'),
      context.tr('review_step_4_title'),
      context.tr('review_step_5_title'),
      context.tr('review_step_6_title'),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Step pill + Title + Close X button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E6FF2).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currentStep + 1} / 6',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2E6FF2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        stepTitles[_currentStep],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Linear Progress Indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 6.0,
                  backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E6FF2)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 20),

              // Step Content
              if (_currentStep == 0)
                _buildStep1MindSweep(
                  context: context,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 1)
                _buildStep2GetClearInbox(
                  context: context,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 2)
                _buildStep3GetCurrentProjects(
                  context: context,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 3)
                _buildStep4GetCurrentTasks(
                  context: context,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 4)
                _buildStep5SomedayMaybe(
                  context: context,
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 5)
                _buildStep6WeeklyPriorities(
                  context: context,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                ),

              const SizedBox(height: 24),

              // Bottom Actions
              Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _prevStep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryTextColor,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        context.tr('back_btn'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : (_currentStep == 0
                                ? _handleStep1Next
                                : (_currentStep == 5
                                    ? _handleFinishReview
                                    : _nextStep)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: isDark ? const Color(0xFF060B24) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _currentStep == 5
                                    ? context.tr('finish_review_btn')
                                    : context.tr('continue_btn'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 1: Mind Sweep ---
  Widget _buildStep1MindSweep({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('review_step_1_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _mindSweepController,
          maxLines: 6,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryTextColor),
          decoration: InputDecoration(
            hintText: context.tr('mind_sweep_hint'),
            hintStyle: TextStyle(fontSize: 13, color: secondaryTextColor.withValues(alpha: 0.6)),
            filled: true,
            fillColor: inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('mind_sweep_footer_hint'),
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: secondaryTextColor),
        ),
      ],
    );
  }

  // --- Step 2: Get Clear (Inbox) ---
  Widget _buildStep2GetClearInbox({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    final inboxCount = ref.watch(unprocessedInboxCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('review_step_2_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),

        // Count summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.inbox_rounded, color: Color(0xFF2E6FF2), size: 28),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$inboxCount',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2E6FF2),
                ),
              ),
              Text(
                context.tr('unprocessed_inbox_items_label'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                inboxCount == 0
                    ? context.tr('inbox_zero_congrats')
                    : context.tr('inbox_process_reminder'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Go to Inbox quick button
        if (inboxCount > 0)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InboxScreen()),
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF2E6FF2)),
              label: Text(
                context.tr('go_to_inbox_btn'),
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2E6FF2)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2E6FF2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
      ],
    );
  }

  // --- Step 3: Get Current (Projects) ---
  Widget _buildStep3GetCurrentProjects({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    final projectsAsync = ref.watch(paraProjectsStreamProvider);
    final projects = projectsAsync.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('review_step_3_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),

        // Count summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.folder_special_rounded, color: Color(0xFF10B981), size: 28),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${projects.length}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
              ),
              Text(
                context.tr('active_projects_count_label'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('projects_review_reminder'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // View Projects button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProjectsPage()),
              );
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF10B981)),
            label: Text(
              context.tr('review_view_projects_btn'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF10B981)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // --- Step 4: Get Current (Tasks) ---
  Widget _buildStep4GetCurrentTasks({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final allTasks = tasksAsync.value ?? [];
    final activeNormalTasks = allTasks.where((t) => !t.done && t.listType == null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('review_step_4_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),

        // Count summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_outline_rounded, color: Color(0xFFF59E0B), size: 28),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${activeNormalTasks.length}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF59E0B),
                ),
              ),
              Text(
                context.tr('active_tasks_count_label'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('tasks_prune_reminder'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Step 5: Get Current (Someday/Maybe) ---
  Widget _buildStep5SomedayMaybe({
    required BuildContext context,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    final somedayAsync = ref.watch(somedayTasksStreamProvider);
    final somedayTasks = somedayAsync.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('review_step_5_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),

        if (somedayTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                const Text('✨', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  context.tr('no_someday_items_title'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: primaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('no_someday_items_sub'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                ),
              ],
            ),
          )
        else
          ...somedayTasks.map((task) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          if (task.notes != null && task.notes!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              task.notes!,
                              style: TextStyle(fontSize: 12, color: secondaryTextColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _handlePromoteSomeday(task),
                      icon: const Text('⚡', style: TextStyle(fontSize: 13)),
                      label: Text(
                        context.tr('activate_btn'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E6FF2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  // --- Step 6: Get Creative (Weekly Priorities) ---
  Widget _buildStep6WeeklyPriorities({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('review_step_6_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),

        _buildPriorityField(
          controller: _priority1Controller,
          number: '1',
          hint: context.tr('weekly_priority_1_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const SizedBox(height: 10),
        _buildPriorityField(
          controller: _priority2Controller,
          number: '2',
          hint: context.tr('weekly_priority_2_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const SizedBox(height: 10),
        _buildPriorityField(
          controller: _priority3Controller,
          number: '3',
          hint: context.tr('weekly_priority_3_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
      ],
    );
  }

  Widget _buildPriorityField({
    required TextEditingController controller,
    required String number,
    required String hint,
    required Color inputBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryTextColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: secondaryTextColor.withValues(alpha: 0.6)),
        filled: true,
        fillColor: inputBg,
        prefixIcon: Container(
          width: 32,
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E6FF2),
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
