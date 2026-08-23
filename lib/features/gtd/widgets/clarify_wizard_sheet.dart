import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../schedule/widgets/add_edit_event_sheet.dart';
import '../../tasks/widgets/add_edit_task_sheet.dart';
import '../models/inbox_item_model.dart';
import '../services/gtd_service.dart';

/// The 5 steps of the GTD Clarify Decision Flow State Machine.
enum ClarifyStep {
  step1Actionable,
  step1bNoAction,
  step2TwoMinuteRule,
  step3Decision,
  step3WaitingForInput,
}

/// The Clarify Wizard modal sheet.
///
/// Implements the core GTD decision flow as a clean, multi-step state machine
/// with progress indicators, celebratory moments, and direct integration with
/// Tasks, Schedule, Waiting For, Someday/Maybe, and Reference collections.
class ClarifyWizardSheet extends StatefulWidget {
  final InboxItemModel inboxItem;

  const ClarifyWizardSheet({
    super.key,
    required this.inboxItem,
  });

  static Future<void> show(BuildContext context, InboxItemModel item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClarifyWizardSheet(inboxItem: item),
    );
  }

  @override
  State<ClarifyWizardSheet> createState() => _ClarifyWizardSheetState();
}

class _ClarifyWizardSheetState extends State<ClarifyWizardSheet> {
  ClarifyStep _currentStep = ClarifyStep.step1Actionable;
  final _waitingForController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _waitingForController.dispose();
    super.dispose();
  }

  void _goTo(ClarifyStep nextStep) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentStep = nextStep;
    });
  }

  void _showToast(String message, {IconData icon = Icons.check_circle_rounded, Color iconColor = const Color(0xFF10B981)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action Handlers
  // ---------------------------------------------------------------------------

  /// 1b - Reference destination
  Future<void> _handleReference() async {
    setState(() => _isProcessing = true);
    await GTDService().createReferenceTask(
      widget.inboxItem.text,
      originalInboxItemId: widget.inboxItem.id,
    );
    if (mounted) {
      Navigator.of(context).pop();
      _showToast(
        context.tr('clarify_moved_to_reference'),
        icon: Icons.bookmark_added_rounded,
        iconColor: const Color(0xFF38BDF8),
      );
    }
  }

  /// 1b - Archive destination
  ///
  /// TODO: In a future release, a dedicated Archive view can surface items marked as processed
  /// without an active task.
  Future<void> _handleArchive() async {
    setState(() => _isProcessing = true);
    await GTDService().markInboxProcessed(widget.inboxItem.id, processed: true);
    if (mounted) {
      Navigator.of(context).pop();
      _showToast(
        context.tr('clarify_archived_toast'),
        icon: Icons.archive_rounded,
        iconColor: const Color(0xFF94A3B8),
      );
    }
  }

  /// 1b - Delete destination (Destructive)
  Future<void> _handleDelete() async {
    setState(() => _isProcessing = true);
    await GTDService().deleteInboxItem(widget.inboxItem.id);
    if (mounted) {
      Navigator.of(context).pop();
      _showToast(
        context.tr('clarify_deleted_toast'),
        icon: Icons.delete_outline_rounded,
        iconColor: const Color(0xFFEF4444),
      );
    }
  }

  /// 2 - 2-Minute Rule "Do it now"
  Future<void> _handleDoItNow() async {
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();
    await GTDService().markInboxProcessed(widget.inboxItem.id, processed: true);
    if (mounted) {
      Navigator.of(context).pop();
      _showToast(
        context.tr('clarify_two_min_celebrate'),
        icon: Icons.timer_rounded,
        iconColor: const Color(0xFFF59E0B),
      );
    }
  }

  /// 3 - Now / Soon -> Opens AddEditTaskSheet prefilled
  Future<void> _handleNowOrSoon() async {
    final rootContext = context;
    Navigator.of(rootContext).pop();

    final result = await showModalBottomSheet<bool>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditTaskSheet(
        initialTitle: widget.inboxItem.text,
      ),
    );

    if (result == true) {
      await GTDService().markInboxProcessed(widget.inboxItem.id, processed: true);
    }
  }

  /// 3 - Someday / Maybe destination
  Future<void> _handleSomeday() async {
    setState(() => _isProcessing = true);
    await GTDService().createSomedayTask(
      widget.inboxItem.text,
      originalInboxItemId: widget.inboxItem.id,
    );
    if (mounted) {
      Navigator.of(context).pop();
      _showToast(
        context.tr('clarify_moved_to_someday'),
        icon: Icons.nightlight_round,
        iconColor: const Color(0xFF8B5CF6),
      );
    }
  }

  /// 3 - Waiting For confirm
  Future<void> _handleConfirmWaitingFor() async {
    final name = _waitingForController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isProcessing = true);
    await GTDService().createWaitingTask(
      widget.inboxItem.text,
      name,
      originalInboxItemId: widget.inboxItem.id,
    );
    if (mounted) {
      Navigator.of(context).pop();
      _showToast(
        context.tr('clarify_moved_to_waiting'),
        icon: Icons.hourglass_top_rounded,
        iconColor: const Color(0xFFF59E0B),
      );
    }
  }

  /// 3 - Event destination -> Opens AddEditEventSheet prefilled
  Future<void> _handleEvent() async {
    final rootContext = context;
    Navigator.of(rootContext).pop();

    final result = await showModalBottomSheet<bool>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditEventSheet(
        initialTitle: widget.inboxItem.text,
      ),
    );

    if (result == true) {
      await GTDService().markInboxProcessed(widget.inboxItem.id, processed: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F5);
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : const Color(0xFF2E6FF2).withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Strip: Progress dots & Back Button (if on sub-step)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep != ClarifyStep.step1Actionable)
                    GestureDetector(
                      onTap: () {
                        if (_currentStep == ClarifyStep.step1bNoAction ||
                            _currentStep == ClarifyStep.step2TwoMinuteRule) {
                          _goTo(ClarifyStep.step1Actionable);
                        } else if (_currentStep == ClarifyStep.step3Decision) {
                          _goTo(ClarifyStep.step2TwoMinuteRule);
                        } else if (_currentStep == ClarifyStep.step3WaitingForInput) {
                          _goTo(ClarifyStep.step3Decision);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.arrow_back_rounded, size: 18, color: primaryTextColor),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: brandPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.auto_fix_high_rounded, size: 18, color: brandPrimary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('clarify_wizard_title'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),

                  // Progress Step Dots
                  _buildProgressDots(isDark, brandPrimary),
                ],
              ),
              const SizedBox(height: 16),

              // Captured Item Highlight Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.inboxItem.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Step Content Body
              if (_isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _buildCurrentStepContent(context, isDark, primaryTextColor, secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots(bool isDark, Color brandPrimary) {
    int activeDot = 0;
    if (_currentStep == ClarifyStep.step1Actionable || _currentStep == ClarifyStep.step1bNoAction) {
      activeDot = 0;
    } else if (_currentStep == ClarifyStep.step2TwoMinuteRule) {
      activeDot = 1;
    } else {
      activeDot = 2;
    }

    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= activeDot;
        return Container(
          margin: const EdgeInsets.only(left: 6),
          width: index == activeDot ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? brandPrimary : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color secondaryColor,
  ) {
    switch (_currentStep) {
      // -----------------------------------------------------------------------
      // STEP 1: Does this need action?
      // -----------------------------------------------------------------------
      case ClarifyStep.step1Actionable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('clarify_step1_question'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primaryColor),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('clarify_step1_prompt'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: secondaryColor),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildChoiceCard(
                    icon: Icons.check_circle_rounded,
                    title: context.tr('clarify_yes_actionable'),
                    subtitle: context.tr('clarify_yes_actionable_sub'),
                    accentColor: const Color(0xFF10B981),
                    onTap: () => _goTo(ClarifyStep.step2TwoMinuteRule),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChoiceCard(
                    icon: Icons.cancel_rounded,
                    title: context.tr('clarify_no_actionable'),
                    subtitle: context.tr('clarify_no_actionable_sub'),
                    accentColor: const Color(0xFF64748B),
                    onTap: () => _goTo(ClarifyStep.step1bNoAction),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        );

      // -----------------------------------------------------------------------
      // STEP 1b: No action needed (Reference, Archive, Delete)
      // -----------------------------------------------------------------------
      case ClarifyStep.step1bNoAction:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('clarify_step1b_question'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primaryColor),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('clarify_step1b_prompt'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: secondaryColor),
            ),
            const SizedBox(height: 18),
            _buildOptionTile(
              icon: Icons.bookmark_outline_rounded,
              title: context.tr('clarify_choice_reference'),
              subtitle: context.tr('clarify_choice_reference_sub'),
              color: const Color(0xFF38BDF8),
              onTap: _handleReference,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildOptionTile(
              icon: Icons.archive_outlined,
              title: context.tr('clarify_choice_archive'),
              subtitle: context.tr('clarify_choice_archive_sub'),
              color: const Color(0xFF94A3B8),
              onTap: _handleArchive,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildOptionTile(
              icon: Icons.delete_outline_rounded,
              title: context.tr('clarify_choice_delete'),
              subtitle: context.tr('clarify_choice_delete_sub'),
              color: const Color(0xFFEF4444),
              onTap: _handleDelete,
              isDestructive: true,
              isDark: isDark,
            ),
          ],
        );

      // -----------------------------------------------------------------------
      // STEP 2: Does it take less than 2 minutes?
      // -----------------------------------------------------------------------
      case ClarifyStep.step2TwoMinuteRule:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('clarify_step2_question'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primaryColor),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('clarify_step2_prompt'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: secondaryColor),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildChoiceCard(
                    icon: Icons.flash_on_rounded,
                    title: context.tr('clarify_two_min_yes'),
                    subtitle: context.tr('clarify_two_min_yes_sub'),
                    accentColor: const Color(0xFFF59E0B),
                    onTap: _handleDoItNow,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChoiceCard(
                    icon: Icons.schedule_rounded,
                    title: context.tr('clarify_two_min_no'),
                    subtitle: context.tr('clarify_two_min_no_sub'),
                    accentColor: const Color(0xFF2E6FF2),
                    onTap: () => _goTo(ClarifyStep.step3Decision),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        );

      // -----------------------------------------------------------------------
      // STEP 3: When will you act on it?
      // -----------------------------------------------------------------------
      case ClarifyStep.step3Decision:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('clarify_step3_question'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primaryColor),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('clarify_step3_prompt'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: secondaryColor),
            ),
            const SizedBox(height: 18),
            _buildOptionTile(
              icon: Icons.check_circle_outline_rounded,
              title: context.tr('clarify_dest_task'),
              subtitle: context.tr('clarify_dest_task_sub'),
              color: const Color(0xFF2E6FF2),
              onTap: _handleNowOrSoon,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildOptionTile(
              icon: Icons.nightlight_round,
              title: context.tr('clarify_dest_someday'),
              subtitle: context.tr('clarify_dest_someday_sub'),
              color: const Color(0xFF8B5CF6),
              onTap: _handleSomeday,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildOptionTile(
              icon: Icons.hourglass_top_rounded,
              title: context.tr('clarify_dest_waiting'),
              subtitle: context.tr('clarify_dest_waiting_sub'),
              color: const Color(0xFFF59E0B),
              onTap: () => _goTo(ClarifyStep.step3WaitingForInput),
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildOptionTile(
              icon: Icons.calendar_month_rounded,
              title: context.tr('clarify_dest_event'),
              subtitle: context.tr('clarify_dest_event_sub'),
              color: const Color(0xFF10B981),
              onTap: _handleEvent,
              isDark: isDark,
            ),
          ],
        );

      // -----------------------------------------------------------------------
      // STEP 3 - Sub: Waiting For Name Input
      // -----------------------------------------------------------------------
      case ClarifyStep.step3WaitingForInput:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('clarify_waiting_prompt_title'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primaryColor),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('clarify_waiting_prompt_sub'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: secondaryColor),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F5),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _waitingForController,
                autofocus: true,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primaryColor),
                decoration: InputDecoration(
                  hintText: context.tr('clarify_waiting_input_hint'),
                  hintStyle: TextStyle(fontSize: 14, color: secondaryColor),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleConfirmWaitingFor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  context.tr('clarify_save_waiting_btn'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildChoiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.35),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? color.withValues(alpha: 0.4)
                : (isDark ? Colors.white10 : const Color(0xFFE2E8F5)),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDestructive ? color : AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
